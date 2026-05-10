import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

/// 🚀 Servizio completo per notifiche push OneSignal - ART DECÒ
/// Tutte le chiavi sono già configurate e pronte all'uso
class OneSignalPushService {
  // ✅ CHIAVI ONESIGNAL - ART DECÒ
  static const String appId = 'f6f03c5c-bb2d-4eb2-91b3-d5192747a10f';
  static const String restApiKey = 'os_v2_app_63ydyxf3fvhlfent2umsor5bb5nbfln3beuujl4hiwxrgdmaqz23fmwhsprr6bnegtmp7thdqz7urib7w6xhuoqubivcre6z3vyjlyi';

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
      print('✅ Utente registrato su OneSignal: $firebaseUid');

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
        // Salva o aggiorna il Player ID
        await supabase.from('user_tokens').upsert({
          'user_id': userRecord['id'].toString(),
          'fcm_token': playerId,
          'platform': 'onesignal',
          'active': true,
          'updated_at': DateTime.now().toIso8601String(),
        });
        print('✅ Player ID salvato nel database');
      }
    } catch (e) {
      print('❌ Errore salvataggio Player ID: $e');
    }
  }

  /// 📨 Invia notifica push a un utente specifico (tramite Firebase UID)
  static Future<bool> sendPushToUser({
    required String firebaseUid,
    required String title,
    required String message,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      print('📤 Invio notifica a utente: $firebaseUid');

      final url = Uri.parse('https://onesignal.com/api/v1/notifications');

      final body = {
        'app_id': appId,
        'include_external_user_ids': [firebaseUid], // Usa External ID (Firebase UID)
        'headings': {'en': title},
        'contents': {'en': message},
        'android_channel_id': '06ca23a0-f14c-45d8-a5b8-69b0d8823024',
        'priority': 10,
        'data': additionalData ?? {},
      };

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Basic $restApiKey',
        },
        body: json.encode(body),
      );

      if (response.statusCode == 200) {
        print('✅ Notifica inviata con successo');
        print('   📊 Response: ${response.body}');
        return true;
      } else {
        print('❌ Errore invio notifica: ${response.statusCode}');
        print('   📄 Body: ${response.body}');
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