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
// 🆕 Import per gestire i deep link
import 'package:app_links/app_links.dart';
import 'dart:async';
bool paymentCompletedGlobally = false;
// ✅ Configurazione Supabase
const String supabaseUrl = 'https://fykszvedjcgurryynhha.supabase.co';
const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZ5a3N6dmVkamNndXJyeXluaGhhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTYxODc1ODksImV4cCI6MjA3MTc2MzU4OX0.H_HOV90GkbdZ_0Ue5ml781Qm1q8N6eukcDgXHAqE0VY';

// 🆕 Chiave globale per navigare da qualsiasi punto dell'app
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

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
        await OneSignalPushService.loginUser(user.uid);
        print('👤 Utente registrato su OneSignal: ${user.uid}');
      } else {
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
      // 🆕 Aggiungiamo navigatorKey per poter navigare dai deep link
      navigatorKey: navigatorKey,
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
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

// 🆕 Cambiato da StatelessWidget a StatefulWidget per gestire i deep link
class _AuthWrapperState extends State<AuthWrapper> {
  // 🆕 Subscription al listener dei deep link
  StreamSubscription? _linkSubscription;

  @override
  void initState() {
    super.initState();
    // 🆕 Avvia il listener dei deep link appena l'app è pronta
    _initDeepLinks();
  }

  @override
  void dispose() {
    // 🆕 Cancella il listener quando il widget viene distrutto
    _linkSubscription?.cancel();
    super.dispose();
  }

  // 🆕 Funzione che configura il listener per i deep link
  Future<void> _initDeepLinks() async {
    final appLinks = AppLinks();

    // Caso 1: app era CHIUSA e viene aperta dal deep link
    // (es. utente clicca sul link dopo che l'app era in background da tanto)
    try {
      final initialLink = await appLinks.getInitialLink();
      if (initialLink != null) {
        print('🔗 Deep link iniziale ricevuto: $initialLink');
        _handleDeepLink(initialLink);
      }
    } catch (e) {
      print('❌ Errore lettura deep link iniziale: $e');
    }

    // Caso 2: app era APERTA (in background) e riceve il deep link
    _linkSubscription = appLinks.uriLinkStream.listen(
          (uri) {
        print('🔗 Deep link ricevuto mentre app era aperta: $uri');
        _handleDeepLink(uri);
      },
      onError: (err) {
        print('❌ Errore deep link stream: $err');
      },
    );
  }

  // 🆕 Funzione che decide cosa fare in base al link ricevuto
  void _handleDeepLink(Uri uri) {
    print('🔗 Gestione deep link: ${uri.toString()}');
    print('   Schema: ${uri.scheme}');    // "artdeco"
    print('   Host: ${uri.host}');        // "payment"
    print('   Path: ${uri.path}');        // "/success" o "/error"
    print('   Parametri: ${uri.queryParameters}'); // {"order_id": "...", "payment_id": "..."}

    // Controlla che sia un nostro deep link di pagamento
    if (uri.scheme == 'artdeco' && uri.host == 'payment') {
      final orderId = uri.queryParameters['order_id'];
      // 🔧 FIX: estrae anche payment_id dal deep link
      final paymentId = uri.queryParameters['payment_id'];

      if (uri.path == '/success') {
        // ✅ PAGAMENTO RIUSCITO
        print('✅ Pagamento completato! Order ID: $orderId | Payment ID: $paymentId');
        _onPaymentSuccess(orderId, paymentId);

      } else if (uri.path == '/error') {
        // ❌ PAGAMENTO FALLITO
        print('❌ Pagamento fallito. Order ID: $orderId');
        _onPaymentError(orderId);
      }
    }
  }

  // 🔧 FIX: salva il record in PAGAMENTI se non esiste già.
  // Chiamato dal deep link quando il polling non ha fatto in tempo a farlo.
  // Ritenta fino a 5 volte con attesa crescente per gestire reti instabili.
  Future<void> _savePaymentRecordFromDeepLink(String orderId, String? paymentId) async {
    // Il formato di orderId è: APP_{appointmentId}_{timestamp}
    final parts = orderId.split('_');
    if (parts.length < 2) {
      print('⚠️ orderId non parsabile: $orderId');
      return;
    }
    final appointmentId = int.tryParse(parts[1]);
    if (appointmentId == null) {
      print('⚠️ appointmentId non valido in orderId: $orderId');
      return;
    }

    const maxAttempts = 5;
    const delays = [2, 4, 8, 16, 30]; // secondi tra un tentativo e l'altro

    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        print('💾 Tentativo $attempt/$maxAttempts salvataggio PAGAMENTI (appuntamento $appointmentId)...');

        final supabase = Supabase.instance.client;

        // Controlla se esiste già un record (il polling potrebbe averlo già creato)
        final existing = await supabase
            .from('PAGAMENTI')
            .select('id, stato')
            .eq('appuntamento_id', appointmentId)
            .maybeSingle();

        if (existing != null) {
          // Record già presente: aggiorna solo stato e payment_id
          final Map<String, dynamic> updates = {'stato': 'completato'};
          if (paymentId != null && paymentId.isNotEmpty) {
            updates['unicredit_payment_id'] = paymentId;
          }
          await supabase
              .from('PAGAMENTI')
              .update(updates)
              .eq('appuntamento_id', appointmentId);
          print('✅ PAGAMENTI aggiornato via deep link (tentativo $attempt) per appuntamento $appointmentId');
        } else {
          // Nessun record: recupera il prezzo dall'appuntamento e crea il record
          final appointment = await supabase
              .from('APPUNTAMENTI')
              .select('prezzo_totale')
              .eq('id', appointmentId)
              .maybeSingle();

          final importo = (appointment?['prezzo_totale'] as num?)?.toDouble() ?? 0.0;

          await supabase.from('PAGAMENTI').insert({
            'appuntamento_id': appointmentId,
            'metodo_pagamento': 'unicredit',
            'stato': 'completato',
            'importo': importo,
            if (paymentId != null && paymentId.isNotEmpty)
              'unicredit_payment_id': paymentId,
          });
          print('✅ Nuovo record PAGAMENTI creato via deep link (tentativo $attempt) per appuntamento $appointmentId (€$importo)');
        }

        return; // Successo: esci dal loop
      } catch (e) {
        print('❌ Tentativo $attempt/$maxAttempts fallito: $e');
        if (attempt < maxAttempts) {
          final waitSec = delays[attempt - 1];
          print('⏳ Riprovo tra ${waitSec}s...');
          await Future.delayed(Duration(seconds: waitSec));
        } else {
          print('❌ Tutti i tentativi esauriti per appuntamento $appointmentId. Il record non è stato salvato.');
        }
      }
    }
  }

  // 🆕 Cosa fare quando il pagamento va a buon fine
  void _onPaymentSuccess(String? orderId, String? paymentId) {
    paymentCompletedGlobally = true;

    // 🔧 FIX: salva su PAGAMENTI dal deep link (nel caso il polling non ci sia arrivato)
    if (orderId != null) {
      _savePaymentRecordFromDeepLink(orderId, paymentId);
    }

    // Mostra un dialog di successo sopra qualunque schermata sia aperta
    final context = navigatorKey.currentContext;
    if (context == null) return;

    showDialog(
      context: context,
      barrierDismissible: false, // L'utente deve premere il bottone
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2d2d2d),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icona successo
            Container(
              width: 70,
              height: 70,
              decoration: const BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check, color: Colors.white, size: 40),
            ),
            const SizedBox(height: 20),
            const Text(
              'Pagamento Completato!',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              'Il tuo appuntamento è stato prenotato e pagato con successo.',
              style: TextStyle(color: Colors.grey[400], fontSize: 14),
              textAlign: TextAlign.center,
            ),
            if (orderId != null) ...[
              const SizedBox(height: 8),
              Text(
                'Ordine: #$orderId',
                style: TextStyle(color: Colors.grey[500], fontSize: 12),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop(); // Chiude il dialog
              // Torna alla home page
              navigatorKey.currentState?.pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const HomePage()),
                    (route) => false,
              );
            },
            child: const Text(
              'Vai alla Home',
              style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  // 🆕 Cosa fare quando il pagamento fallisce
  void _onPaymentError(String? orderId) {
    final context = navigatorKey.currentContext;
    if (context == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2d2d2d),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icona errore
            Container(
              width: 70,
              height: 70,
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, color: Colors.white, size: 40),
            ),
            const SizedBox(height: 20),
            const Text(
              'Pagamento Non Riuscito',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              'Il pagamento non è andato a buon fine. Nessun addebito è stato effettuato.',
              style: TextStyle(color: Colors.grey[400], fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
            },
            child: const Text(
              'Riprova',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              navigatorKey.currentState?.pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const HomePage()),
                    (route) => false,
              );
            },
            child: Text(
              'Vai alla Home',
              style: TextStyle(color: Colors.grey[400]),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<firebase_auth.User?>(
      stream: firebase_auth.FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFF1a1a1a),
            body: Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
          );
        }

        if (snapshot.hasData) {
          final user = snapshot.data!;
          print('👤 Utente loggato: ${user.email}');
          NotificationPollingService.startPolling();

          return FutureBuilder<String>(
            future: _getUserRole(user.uid),
            builder: (context, roleSnapshot) {
              if (roleSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  backgroundColor: Color(0xFF1a1a1a),
                  body: Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                );
              }

              final role = roleSnapshot.data ?? 'user';
              print('👤 Ruolo utente: $role');

              if (role == 'admin') {
                return const AdminDashboardPage();
              } else {
                return const HomePage();
              }
            },
          );
        }

        print('👤 Nessun utente loggato');
        return const LoginPage();
      },
    );
  }

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