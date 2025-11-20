import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'appointment_notification_service.dart';

class NotificationPollingService {
  static Timer? _pollingTimer;
  static bool _isPolling = false;

  /// Avvia il polling delle notifiche (ogni 30 secondi)
  static void startPolling() {
    if (_isPolling) {
      print('⚠️ Polling già attivo');
      return;
    }

    print('🔄 Avvio polling notifiche...');
    _isPolling = true;

    // Prima verifica immediata
    _checkNotifications();

    // Poi ogni 30 secondi
    _pollingTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _checkNotifications();
    });
  }

  /// Ferma il polling
  static void stopPolling() {
    print('🛑 Stop polling notifiche');
    _pollingTimer?.cancel();
    _pollingTimer = null;
    _isPolling = false;
  }

  /// Controlla se ci sono notifiche in coda
  static Future<void> _checkNotifications() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('👤 Nessun utente loggato, skip polling');
        return;
      }

      final supabase = Supabase.instance.client;

      // Recupera l'ID numerico dell'utente
      final userRecord = await supabase
          .from('USERS')
          .select('id')
          .eq('uid', user.uid)
          .maybeSingle();

      if (userRecord == null) {
        print('⚠️ Utente non trovato in Supabase');
        return;
      }

      final userId = userRecord['id'] as int;

      // Recupera notifiche non inviate
      final notifications = await supabase
          .from('notification_queue')
          .select()
          .eq('user_id', userId)
          .eq('sent', false)
          .order('created_at', ascending: true);

      if (notifications.isEmpty) {
        print('✅ Nessuna notifica in coda');
        return;
      }

      print('📬 Trovate ${notifications.length} notifiche da inviare');

      // Invia ogni notifica
      for (var notification in notifications) {
        await _sendLocalNotification(notification);

        // Marca come inviata
        await supabase
            .from('notification_queue')
            .update({
          'sent': true,
          'read': true,
        })
            .eq('id', notification['id']);

        print('✅ Notifica ${notification['id']} inviata e marcata come letta');
      }

    } catch (e) {
      print('❌ Errore polling notifiche: $e');
    }
  }

  /// Invia notifica locale
  static Future<void> _sendLocalNotification(Map<String, dynamic> notification) async {
    try {
      final title = notification['title'] as String;
      final body = notification['body'] as String;
      final notificationId = notification['id'] as int;

      await AppointmentNotificationService.sendImmediateNotification(
        id: notificationId,
        title: title,
        body: body,
      );

      print('📨 Notifica locale inviata: $title');
    } catch (e) {
      print('❌ Errore invio notifica locale: $e');
    }
  }

  /// Forza controllo immediato (utile per debug)
  static Future<void> checkNow() async {
    print('🔍 Controllo forzato notifiche...');
    await _checkNotifications();
  }
}