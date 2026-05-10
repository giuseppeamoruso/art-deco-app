import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class OneSignalService {
  static const String appId = 'f6f03c5c-bb2d-4eb2-91b3-d5192747a10f';

  static Future<void> initialize() async {
    print('🔔 Inizializzazione OneSignal...');

    // Inizializza OneSignal
    OneSignal.initialize(appId);

    // Richiedi permessi notifiche
    await OneSignal.Notifications.requestPermission(true);

    // Listener per notifiche ricevute in foreground
    OneSignal.Notifications.addForegroundWillDisplayListener((event) {
      print('📨 Notifica ricevuta: ${event.notification.title}');
    });

    // Listener per tap su notifica
    OneSignal.Notifications.addClickListener((event) {
      print('📱 Notifica cliccata: ${event.notification.title}');
    });

    print('✅ OneSignal inizializzato');
  }

  /// Registra utente con External ID (Firebase UID)
  static Future<void> loginUser(String firebaseUid) async {
    try {
      await OneSignal.login(firebaseUid);
      print('✅ Utente registrato su OneSignal: $firebaseUid');

      // Ottieni Player ID (opzionale, per salvarlo nel database)
      final playerId = OneSignal.User.pushSubscription.id;
      if (playerId != null) {
        print('📱 Player ID: $playerId');
        await _savePlayerId(firebaseUid, playerId);
      }
    } catch (e) {
      print('❌ Errore login OneSignal: $e');
    }
  }

  /// Logout utente
  static Future<void> logoutUser() async {
    try {
      await OneSignal.logout();
      print('✅ Utente logout da OneSignal');
    } catch (e) {
      print('❌ Errore logout OneSignal: $e');
    }
  }

  /// Salva Player ID nel database (opzionale)
  static Future<void> _savePlayerId(String firebaseUid, String playerId) async {
    try {
      final supabase = Supabase.instance.client;

      final userRecord = await supabase
          .from('USERS')
          .select('id')
          .eq('uid', firebaseUid)
          .maybeSingle();

      if (userRecord != null) {
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

  /// Ottieni Player ID corrente
  static String? getPlayerId() {
    return OneSignal.User.pushSubscription.id;
  }

  /// Invia notifica di test (per debug)
  static Future<void> sendTestNotification() async {
    final playerId = OneSignal.User.pushSubscription.id;
    print('🧪 Player ID per test: $playerId');
    print('Usa questo ID per inviare una notifica di test dalla dashboard OneSignal');
  }
}