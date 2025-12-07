import 'package:art_deco/theme_manager.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'appointment_notification_service.dart';
import 'firebase_options.dart';
import 'login_page.dart';
import 'home_page.dart';
import 'admin_dashboard_page.dart';
import 'notification_polling_service.dart';
import 'onesignal_push_service.dart';
import 'package:intl/date_symbol_data_local.dart';


// ✅ Configurazione Supabase
const String supabaseUrl = 'https://fykszvedjcgurryynhha.supabase.co';
const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZ5a3N6dmVkamNndXJyeXluaGhhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTYxODc1ODksImV4cCI6MjA3MTc2MzU4OX0.H_HOV90GkbdZ_0Ue5ml781Qm1q8N6eukcDgXHAqE0VY';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  print('🚀 Inizializzazione app...');

  try {
    // 1. Inizializza Firebase
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('✅ Firebase inizializzato');

    // 2. Inizializza Supabase
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );
    print('✅ Supabase inizializzato');

    // 3. Inizializza Notifiche Locali
    await AppointmentNotificationService.initialize();
    print('✅ Notifiche locali inizializzate');

    // 4. ✅ Inizializza OneSignal Push Notifications
    await OneSignalPushService.initialize();
    print('✅ OneSignal Push inizializzato');
    await initializeDateFormatting('it_IT', null);
    print('✅ Formattazione date inizializzata');

    // 5. ✅ Listener per login/logout automatico su OneSignal
    firebase_auth.FirebaseAuth.instance.authStateChanges().listen((firebase_auth.User? user) async {
      if (user != null) {
        // Utente loggato → Registra su OneSignal
        await OneSignalPushService.loginUser(user.uid);
        print('👤 Utente registrato su OneSignal: ${user.uid}');
      } else {
        // Utente sloggato → Logout da OneSignal
        await OneSignalPushService.logoutUser();
        print('🚪 Utente sloggato da OneSignal');
      }
    });

  } catch (e) {
    print('❌ Errore inizializzazione: $e');
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final currentTheme = ThemeManager.getCurrentTheme();
    return MaterialApp(
      title: 'Art Decò',
      theme: ThemeManager.getTheme(currentTheme),

      // 🔥 AGGIUNGI QUESTO
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('it', 'IT'),
        Locale('en', 'US'),
      ],

      home: const AuthWrapper(),
      debugShowCheckedModeBanner: false,
    );

  }
}

// ✅ WRAPPER PER MANTENERE L'UTENTE LOGGATO
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<firebase_auth.User?>(
      stream: firebase_auth.FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Mostra loading mentre controlla
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFF1a1a1a),
            body: Center(
              child: CircularProgressIndicator(
                color: Colors.white,
              ),
            ),
          );
        }

        // Se l'utente è loggato
        if (snapshot.hasData) {
          final user = snapshot.data!;
          print('👤 Utente loggato: ${user.email}');
          NotificationPollingService.startPolling();

          // Controlla se è admin o user
          return FutureBuilder<String>(
            future: _getUserRole(user.uid),
            builder: (context, roleSnapshot) {
              if (roleSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  backgroundColor: Color(0xFF1a1a1a),
                  body: Center(
                    child: CircularProgressIndicator(
                      color: Colors.white,
                    ),
                  ),
                );
              }

              final role = roleSnapshot.data ?? 'user';
              print('👤 Ruolo utente: $role');

              // Naviga in base al ruolo
              if (role == 'admin') {
                return const AdminDashboardPage();
              } else {
                return const HomePage();
              }
            },
          );
        }

        // Altrimenti mostra login
        print('👤 Nessun utente loggato');
        return const LoginPage();
      },
    );
  }

  // Recupera il ruolo dell'utente da Supabase
  Future<String> _getUserRole(String uid) async {
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('USERS')
          .select('role')
          .eq('uid', uid)
          .maybeSingle();

      if (response != null) {
        return response['role']?.toString().toLowerCase() ?? 'user';
      }
      return 'user';
    } catch (e) {
      print('❌ Errore recupero ruolo: $e');
      return 'user';
    }
  }
}