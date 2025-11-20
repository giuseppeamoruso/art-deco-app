import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:permission_handler/permission_handler.dart';

class AppointmentNotificationService {
  static final FlutterLocalNotificationsPlugin _notifications = 
      FlutterLocalNotificationsPlugin();
  
  static bool _isInitialized = false;

  /// Inizializza il servizio notifiche
  static Future<void> initialize() async {
    if (_isInitialized) {
      print('⚠️ Notifiche già inizializzate');
      return;
    }

    print('🔔 Inizializzazione notifiche...');

    // Inizializza timezone (Italia)
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Europe/Rome'));

    // Richiedi permessi
    await _requestPermissions();

    // Configura notifiche
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

    await _notifications.initialize(
      settings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        print('📱 Notifica toccata: ${response.payload}');
        // Qui puoi navigare ai dettagli appuntamento se vuoi
      },
    );

    // Crea canale Android
    await _createAndroidChannel();

    _isInitialized = true;
    print('✅ Notifiche inizializzate');
  }

  /// Richiedi permessi
  static Future<void> _requestPermissions() async {
    // Android 13+
    if (await Permission.notification.isDenied) {
      await Permission.notification.request();
    }

    // iOS
    await _notifications
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
  }

  /// Crea canale Android
  static Future<void> _createAndroidChannel() async {
    const channel = AndroidNotificationChannel(
      'appointments',
      'Promemoria Appuntamenti',
      description: 'Notifiche per ricordare gli appuntamenti prenotati',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );

    await _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  /// 🎯 Programma notifica per appuntamento
  /// Invia notifica il giorno prima alle 18:00
  static Future<void> scheduleAppointmentReminder({
    required int appointmentId,
    required String clientName,
    required String stylistName,
    required DateTime appointmentDate,
    required String appointmentTime,
    required List<String> services,
  }) async {
    if (!_isInitialized) {
      print('❌ Notifiche non inizializzate');
      return;
    }

    // Calcola quando inviare la notifica (giorno prima alle 18:00)
    final notificationDate = DateTime(
      appointmentDate.year,
      appointmentDate.month,
      appointmentDate.day - 1, // Giorno prima
      18, // Ore 18:00
      0,
    );

    // Controlla se è nel futuro
    if (notificationDate.isBefore(DateTime.now())) {
      print('⚠️ Notifica non programmata: data nel passato');
      return;
    }

    // Crea il messaggio
    final servicesText = services.join(', ');
    final dateText = _formatDate(appointmentDate);
    
    final title = '📅 Promemoria Appuntamento';
    final body = 'Ciao $clientName! Domani hai appuntamento alle $appointmentTime con $stylistName per: $servicesText';

    try {
      await _notifications.zonedSchedule(
        appointmentId, // ID univoco per appuntamento
        title,
        body,
        tz.TZDateTime.from(notificationDate, tz.local),
        NotificationDetails(
          android: AndroidNotificationDetails(
            'appointments',
            'Promemoria Appuntamenti',
            channelDescription: 'Notifiche per ricordare gli appuntamenti prenotati',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
            playSound: true,
            enableVibration: true,
            styleInformation: BigTextStyleInformation(body),
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
            subtitle: 'Appuntamento domani alle $appointmentTime',
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: appointmentId.toString(),
      );

      print('✅ Notifica programmata per $clientName');
      print('   📅 Data notifica: ${notificationDate.toString()}');
      print('   📅 Appuntamento: $dateText alle $appointmentTime');
      
    } catch (e) {
      print('❌ Errore programmazione notifica: $e');
    }
  }

  /// Cancella notifica per appuntamento
  static Future<void> cancelAppointmentReminder(int appointmentId) async {
    await _notifications.cancel(appointmentId);
    print('🗑️ Notifica cancellata per appuntamento #$appointmentId');
  }

  /// Test: Notifica immediata
  static Future<void> testNotification() async {
    if (!_isInitialized) {
      await initialize();
    }

    await _notifications.show(
      999,
      '🧪 Test Notifica',
      'Questa è una notifica di test. Se la vedi, tutto funziona! ✅',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'appointments',
          'Promemoria Appuntamenti',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );

    print('🧪 Notifica test inviata!');
  }

  /// Test: Notifica tra 10 secondi
  static Future<void> testScheduledNotification() async {
    if (!_isInitialized) {
      await initialize();
    }

    final scheduledTime = tz.TZDateTime.now(tz.local).add(const Duration(seconds: 10));

    await _notifications.zonedSchedule(
      998,
      '🧪 Test Programmato',
      'Notifica programmata ricevuta dopo 10 secondi! ⏰',
      scheduledTime,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'appointments',
          'Promemoria Appuntamenti',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );

    print('🧪 Notifica test programmata per: ${scheduledTime.toString()}');
  }

  /// Mostra tutte le notifiche programmate
  static Future<void> showPendingNotifications() async {
    final pending = await _notifications.pendingNotificationRequests();
    
    print('📋 Notifiche programmate: ${pending.length}');
    for (var notification in pending) {
      print('   ID: ${notification.id}, Titolo: ${notification.title}');
    }
  }

  /// Cancella tutte le notifiche
  static Future<void> cancelAll() async {
    await _notifications.cancelAll();
    print('🗑️ Tutte le notifiche cancellate');
  }

  /// Invia notifica immediata generica
  static Future<void> sendImmediateNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    if (!_isInitialized) {
      print('❌ Notifiche non inizializzate');
      return;
    }

    try {
      await _notifications.show(
        id,
        title,
        body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'appointments',
            'Promemoria Appuntamenti',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
            playSound: true,
            enableVibration: true,
            styleInformation: BigTextStyleInformation(body),
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
      );

      print('📨 Notifica immediata inviata: $title');
    } catch (e) {
      print('❌ Errore invio notifica immediata: $e');
    }
  }

  /// Notifica immediata quando un appuntamento viene modificato dall'admin
  static Future<void> sendModificationNotification({
    required String clientName,
    required DateTime oldDate,
    required DateTime newDate,
    required String oldTime,
    required String newTime,
  }) async {
    if (!_isInitialized) {
      print('❌ Notifiche non inizializzate');
      return;
    }

    final title = '📝 Appuntamento Modificato';
    final body = 'Ciao $clientName! Il tuo appuntamento è stato spostato da ${_formatDate(oldDate)} alle $oldTime a ${_formatDate(newDate)} alle $newTime';

    try {
      await _notifications.show(
        99999, // ID speciale per notifiche di modifica
        title,
        body,
        NotificationDetails( // ✅ RIMOSSO const
          android: AndroidNotificationDetails(
            'appointments',
            'Promemoria Appuntamenti',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
            playSound: true,
            enableVibration: true,
            styleInformation: BigTextStyleInformation(body), // ✅ OK ora
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
            subtitle: 'Modifica appuntamento',
          ),
        ),
      );

      print('📨 Notifica modifica inviata');
    } catch (e) {
      print('❌ Errore invio notifica modifica: $e');
    }
  }

  /// Formatta data in italiano
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