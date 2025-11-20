import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';

// ✅ HANDLER GLOBALE per notifiche in background
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('📨 Background message ricevuto: ${message.notification?.title}');

  // Mostra notifica locale anche in background
  final notifications = FlutterLocalNotificationsPlugin();

  const androidDetails = AndroidNotificationDetails(
    'appointments',
    'Promemoria Appuntamenti',
    importance: Importance.high,
    priority: Priority.high,
  );

  const iosDetails = DarwinNotificationDetails(
    presentAlert: true,
    presentBadge: true,
    presentSound: true,
  );

  const details = NotificationDetails(
    android: androidDetails,
    iOS: iosDetails,
  );

  await notifications.show(
    message.hashCode,
    message.notification?.title ?? 'Notifica',
    message.notification?.body ?? '',
    details,
  );
}

class FCMNotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications =
  FlutterLocalNotificationsPlugin();

  static bool _isInitialized = false;

  /// Inizializza FCM
  static Future<void> initialize() async {
    if (_isInitialized) return;

    print('🔔 Inizializzazione FCM...');

    // Richiedi permessi
    await _requestPermissions();

    // Configura notifiche locali
    await _setupLocalNotifications();

    // Registra background handler
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // Handler per notifiche in foreground
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('📨 Foreground message: ${message.notification?.title}');
      _showLocalNotification(message);
    });

    // Handler per tap su notifica (app era chiusa/background)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('📱 App aperta da notifica: ${message.notification?.title}');
    });

    // Ottieni e salva token FCM
    await _registerFCMToken();

    // Listener per refresh token
    _messaging.onTokenRefresh.listen(_saveFCMToken);

    _isInitialized = true;
    print('✅ FCM inizializzato');
  }

  /// Richiedi permessi
  static Future<void> _requestPermissions() async {
    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    print('📱 Permessi FCM: ${settings.authorizationStatus}');
  }

  /// Configura notifiche locali
  static Future<void> _setupLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(settings);
  }

  /// Registra token FCM
  static Future<void> _registerFCMToken() async {
    try {
      String? token = await _messaging.getToken();
      if (token != null) {
        await _saveFCMToken(token);
      }
    } catch (e) {
      print('❌ Errore registrazione FCM token: $e');
    }
  }

  /// Salva token FCM nel database
  static Future<void> _saveFCMToken(String token) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('⚠️ Nessun utente loggato per salvare token');
        return;
      }

      final supabase = Supabase.instance.client;

      // Recupera user_id numerico
      final userRecord = await supabase
          .from('USERS')
          .select('id')
          .eq('uid', user.uid)
          .maybeSingle();

      if (userRecord == null) return;

      final userId = userRecord['id'].toString();

      // Verifica se token esiste già
      final existingToken = await supabase
          .from('USER_TOKENS')
          .select('id')
          .eq('fcm_token', token)
          .maybeSingle();

      if (existingToken != null) {
        // Aggiorna esistente
        await supabase
            .from('USER_TOKENS')
            .update({
          'user_id': userId,
          'active': true,
          'updated_at': DateTime.now().toIso8601String(),
        })
            .eq('fcm_token', token);
      } else {
        // Crea nuovo
        await supabase.from('USER_TOKENS').insert({
          'user_id': userId,
          'fcm_token': token,
          'platform': 'mobile',
          'active': true,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        });
      }

      print('✅ Token FCM salvato: ${token.substring(0, 20)}...');
    } catch (e) {
      print('❌ Errore salvataggio token: $e');
    }
  }

  /// Mostra notifica locale da FCM
  static Future<void> _showLocalNotification(RemoteMessage message) async {
    const androidDetails = AndroidNotificationDetails(
      'appointments',
      'Promemoria Appuntamenti',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      message.hashCode,
      message.notification?.title ?? 'Notifica',
      message.notification?.body ?? '',
      details,
    );
  }

  /// Ottieni token corrente
  static Future<String?> getToken() async {
    return await _messaging.getToken();
  }
}