import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 🚀 Servizio completo per notifiche push OneSignal - ART DECÒ
/// L'invio avviene tramite Supabase Edge Function (chiave REST mai esposta nel client)
class OneSignalPushService {
  // App ID OneSignal (pubblico, non è un segreto)
  static const String appId = 'f6f03c5c-bb2d-4eb2-91b3-d5192747a10f';
  // ⚠️ La REST API Key è ora un secret Supabase — NON va più qui

  /// 📱 Inizializza OneSignal
  static Future<void> initialize() async {
    print('🔔 Inizializzazione OneSignal...');

    // Inizializza OneSignal
    OneSignal.initialize(appId);

    // Richiedi permessi notifiche
    await OneSignal.Notifications.requestPermission(true);

    // Listener per notifiche ricevute in foreground
    OneSignal.Notifications.addForegroundWillDisplayListener((event) {
      print('📨 Notifica ricevuta in foreground: ${event.notification.title}');
      // La notifica viene mostrata automaticamente
    });

    // Listener per tap su notifica
    OneSignal.Notifications.addClickListener((event) {
      print('📱 Notifica cliccata: ${event.notification.title}');

      // Gestisci azione basata su additionalData
      final data = event.notification.additionalData;
      if (data != null) {
        if (data.containsKey('appointment_id')) {
          // Naviga ai dettagli appuntamento
          _handleAppointmentNotificationClick(data['appointment_id']);
        }
      }
    });

    print('✅ OneSignal inizializzato');
  }

  /// 🔐 Registra utente con External ID (Firebase UID)
  static Future<void> loginUser(String firebaseUid) async {
    try {
      await OneSignal.login(firebaseUid);
      print('✅ OneSignal login completato: $firebaseUid');

      // Ottieni Player ID e salvalo nel database
      final playerId = OneSignal.User.pushSubscription.id;
      if (playerId != null) {
        print('📱 Player ID: $playerId');
        await _savePlayerId(firebaseUid, playerId);
      }
    } catch (e) {
      print('❌ Errore login OneSignal: $e');
    }
  }

  /// 🚪 Logout utente
  static Future<void> logoutUser() async {
    try {
      await OneSignal.logout();
      print('✅ Utente logout da OneSignal');
    } catch (e) {
      print('❌ Errore logout OneSignal: $e');
    }
  }

  /// 💾 Salva Player ID nel database
  static Future<void> _savePlayerId(String firebaseUid, String playerId) async {
    try {
      final supabase = Supabase.instance.client;

      // Trova l'utente nel database
      final userRecord = await supabase
          .from('USERS')
          .select('id')
          .eq('uid', firebaseUid)
          .maybeSingle();

      if (userRecord != null) {
        final userId = userRecord['id'].toString();
        // upsert su 'fcm_token': se lo stesso token era di un altro utente
        // (es. stesso device, account diverso) lo aggiorna all'utente attuale.
        // Risolve: duplicate key value violates unique constraint "user_tokens_fcm_token_key"
        await supabase.from('user_tokens').upsert(
          {
            'user_id': userId,
            'fcm_token': playerId,
            'platform': 'onesignal',
            'active': true,
            'updated_at': DateTime.now().toIso8601String(),
          },
          onConflict: 'fcm_token',
        );
        print('✅ Player ID salvato nel database (user: $userId)');
      }
    } catch (e) {
      print('❌ Errore salvataggio Player ID: $e');
    }
  }

  /// 📨 Invia notifica push a un utente specifico
  /// La REST API key OneSignal è gestita lato server (Supabase Edge Function)
  static Future<bool> sendPushToUser({
    required String firebaseUid,
    required String title,
    required String message,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      print('📤 Invio notifica a utente: $firebaseUid');

      final supabase = Supabase.instance.client;

      // Recupera player IDs (subscription IDs) dal DB
      List<String> playerIds = [];
      try {
        final userRecord = await supabase
            .from('USERS')
            .select('id')
            .eq('uid', firebaseUid)
            .maybeSingle();
        if (userRecord != null) {
          final tokens = await supabase
              .from('user_tokens')
              .select('fcm_token')
              .eq('user_id', userRecord['id'].toString())
              .eq('active', true);
          playerIds = (tokens as List)
              .map<String>((t) => t['fcm_token'] as String)
              .toList();
          print('📱 Player IDs trovati nel DB: $playerIds');
        }
      } catch (e) {
        print('⚠️ Impossibile recuperare player IDs dal DB: $e');
      }

      // Chiama la Supabase Edge Function (chiave REST mai esposta nel client)
      final response = await supabase.functions.invoke(
        'send-push-notification',
        body: {
          'firebaseUid': firebaseUid,
          'title': title,
          'message': message,
          'additionalData': additionalData ?? {},
          'playerIds': playerIds,
        },
      );

      final data = response.data as Map<String, dynamic>?;
      final success = data?['success'] == true;

      if (success) {
        print('✅ Notifica inviata con successo');
        print('   📊 Response: $data');
        return true;
      } else {
        final status = data?['status'];
        final body = data?['body'];
        // 400 "No Subscriptions" = utente senza device attivi, non critico
        if (status == 400) {
          final errors = body?['errors']?.toString() ?? '';
          if (errors.contains('No Subscriptions') || errors.contains('subscription')) {
            print('⚠️ Utente senza subscription attiva');
            return false;
          }
        }
        print('❌ Notifica non inviata (status: $status): $body');
        return false;
      }
    } catch (e) {
      print('❌ Errore invio notifica: $e');
      return false;
    }
  }

  /// 🔔 NOTIFICA DI MODIFICA APPUNTAMENTO
  /// Invia quando l'admin modifica un appuntamento esistente
  static Future<bool> sendAppointmentModificationNotification({
    required String firebaseUid,
    required String clientName,
    required DateTime oldDate,
    required DateTime newDate,
    required String oldTime,
    required String newTime,
    required int appointmentId,
  }) async {
    final title = '📝 Appuntamento Modificato';
    final message = 'Ciao $clientName! Il tuo appuntamento è stato spostato da '
        '${_formatDate(oldDate)} alle $oldTime a ${_formatDate(newDate)} alle $newTime';

    return await sendPushToUser(
      firebaseUid: firebaseUid,
      title: title,
      message: message,
      additionalData: {
        'type': 'appointment_modified',
        'appointment_id': appointmentId,
        'new_date': newDate.toIso8601String(),
        'new_time': newTime,
      },
    );
  }

  /// ⏰ NOTIFICA REMINDER APPUNTAMENTO
  /// Invia il giorno prima alle 18:00 come promemoria
  static Future<bool> sendAppointmentReminderNotification({
    required String firebaseUid,
    required String clientName,
    required String stylistName,
    required DateTime appointmentDate,
    required String appointmentTime,
    required List<String> services,
    required int appointmentId,
  }) async {
    final servicesText = services.join(', ');
    final title = '📅 Promemoria Appuntamento';
    final message = 'Ciao $clientName! Domani hai appuntamento alle $appointmentTime '
        'con $stylistName per: $servicesText';

    return await sendPushToUser(
      firebaseUid: firebaseUid,
      title: title,
      message: message,
      additionalData: {
        'type': 'appointment_reminder',
        'appointment_id': appointmentId,
        'date': appointmentDate.toIso8601String(),
        'time': appointmentTime,
      },
    );
  }

  /// 🎯 Ottieni Firebase UID da un ID appuntamento
  static Future<String?> getFirebaseUidFromAppointment(int appointmentId) async {
    try {
      final supabase = Supabase.instance.client;

      // Query per ottenere l'UID dell'utente dall'appuntamento
      final response = await supabase
          .from('APPUNTAMENTI')
          .select('user_id, USERS!inner(uid)')
          .eq('id', appointmentId)
          .single();

      return response['USERS']['uid'] as String?;
    } catch (e) {
      print('❌ Errore recupero Firebase UID: $e');
      return null;
    }
  }

  /// 📊 Ottieni Player ID corrente
  static String? getPlayerId() {
    return OneSignal.User.pushSubscription.id;
  }

  /// 🧪 Test notifica immediata
  static Future<void> sendTestNotification() async {
    final firebaseUid = FirebaseAuth.instance.currentUser?.uid;
    if (firebaseUid == null) {
      print('❌ Nessun utente loggato');
      return;
    }

    await sendPushToUser(
      firebaseUid: firebaseUid,
      title: '🧪 Test Notifica',
      message: 'Questa è una notifica di test da OneSignal! ✅',
      additionalData: {'test': true},
    );
  }

  /// 📱 Gestisci click su notifica (puoi personalizzare)
  static void _handleAppointmentNotificationClick(dynamic appointmentId) {
    print('🔔 Navigando ai dettagli appuntamento: $appointmentId');
    // TODO: Implementa navigazione ai dettagli
    // Navigator.push(context, MaterialPageRoute(builder: (context) => AppointmentDetailsPage(id: appointmentId)));
  }

  /// 📅 Formatta data in italiano
  static String _formatDate(DateTime date) {
    const months = [
      '', 'Gennaio', 'Febbraio', 'Marzo', 'Aprile', 'Maggio', 'Giugno',
      'Luglio', 'Agosto', 'Settembre', 'Ottobre', 'Novembre', 'Dicembre'
    ];
    const weekdays = [
      '', 'Lunedì', 'Martedì', 'Mercoledì', 'Giovedì', 'Venerdì', 'Sabato', 'Domenica'
    ];

    return '${weekdays[date.weekday]} ${date.day} ${months[date.month]} ${date.year}';
  }
}