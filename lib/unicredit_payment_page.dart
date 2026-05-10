import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'main.dart';

class UniCreditPaymentPage extends StatefulWidget {
  final int appointmentId;
  final double totalPrice;
  final String description;
  final Function(String paymentId) onPaymentSuccess;
  final Function() onPaymentFailure;

  const UniCreditPaymentPage({
    super.key,
    required this.appointmentId,
    required this.totalPrice,
    required this.description,
    required this.onPaymentSuccess,
    required this.onPaymentFailure,
  });

  @override
  State<UniCreditPaymentPage> createState() => _UniCreditPaymentPageState();
}

class _UniCreditPaymentPageState extends State<UniCreditPaymentPage>
    with WidgetsBindingObserver {
  bool _isInitializing = false;
  String? _errorMessage;
  String? _orderId;
  String? _paymentId;
  bool _paymentConfirmed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializePayment();
  }

  // 🔧 FIX: quando l'app torna in foreground dal browser, controlla subito
  // lo stato del pagamento senza aspettare il prossimo tick del polling (5s).
  // Questo cattura i casi in cui il deep link è stato perso durante il restart.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (!_paymentConfirmed && !paymentCompletedGlobally && _orderId != null) {
        print('📱 App ripresa dal browser - controllo immediato stato pagamento');
        Future.delayed(const Duration(milliseconds: 800), () {
          _checkPaymentStatus();
        });
      }
    }
  }

  Future<void> _initializePayment() async {
    setState(() {
      _isInitializing = true;
      _errorMessage = null;
    });

    try {
      // Recupera email dell'utente da Supabase
      final user = firebase_auth.FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('Utente non autenticato');
      }

      final supabase = Supabase.instance.client;
      final userRecord = await supabase
          .from('USERS')
          .select('email')
          .eq('uid', user.uid)
          .single();

      final userEmail = userRecord['email'] as String? ?? 'noemail@artdeco.com';

      // Genera order_id univoco
      final orderId = 'APP_${widget.appointmentId}_${DateTime.now().millisecondsSinceEpoch}';

      // Chiama il tuo backend PHP per inizializzare il pagamento
      final response = await http.post(
        Uri.parse('https://art-deco-app-production.up.railway.app/init_payment.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'amount': (widget.totalPrice * 100).toInt(), // Converti in centesimi
          'email': userEmail,
          'order_id': orderId,
          'description': widget.description,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['success'] == true) {
          final paymentId = data['payment_id'] as String;
          final redirectUrl = data['redirect_url'] as String;
          _orderId = data['order_id'] as String;
          _paymentId = paymentId;
          print('✅ Pagamento inizializzato: $paymentId');
          print('🔗 Redirect URL: $redirectUrl');

          // Apri il browser per il pagamento
          await _openPaymentBrowser(redirectUrl);

        } else {
          setState(() {
            _errorMessage = data['error_message'] ?? 'Errore sconosciuto';
          });
        }
      } else {
        setState(() {
          _errorMessage = 'Errore di connessione al server (${response.statusCode})';
        });
      }

    } catch (e) {
      setState(() {
        _errorMessage = 'Errore: $e';
      });
    } finally {
      setState(() {
        _isInitializing = false;
      });
    }
  }

  Future<void> _openPaymentBrowser(String url) async {
    try {
      final uri = Uri.parse(url);

      if (await canLaunchUrl(uri)) {
        // Apri il browser con l'URL di pagamento UniCredit
        final launched = await launchUrl(
          uri,
          mode: LaunchMode.externalApplication, // Apre nel browser esterno
        );

        if (launched) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Completa il pagamento nel browser. Tornerai automaticamente all\'app.'),
                duration: Duration(seconds: 5),
                backgroundColor: Colors.blue,
              ),
            );
          }
          // Piano B: polling ogni 5 secondi nel caso il deep link non funzioni
          _startPaymentStatusPolling();
        }
      } else {
        throw 'Impossibile aprire il browser';
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Errore apertura browser: $e';
      });
    }
  }

  Timer? _pollingTimer;
  int _pollingAttempts = 0;
  final int _maxPollingAttempts = 60; // 5 minuti (ogni 5 secondi)

  void _startPaymentStatusPolling() {
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      _pollingAttempts++;

      if (_pollingAttempts >= _maxPollingAttempts) {
        timer.cancel();
        if (mounted) {
          _showTimeoutDialog();
        }
        return;
      }

      // Verifica lo stato del pagamento
      await _checkPaymentStatus();
    });
  }

  Future<void> _checkPaymentStatus() async {
    if (_paymentConfirmed || paymentCompletedGlobally) return;
    if (_orderId == null) return;

    try {
      final response = await http.get(
        Uri.parse('https://art-deco-app-production.up.railway.app/verify_payment.php?order_id=$_orderId&payment_id=$_paymentId'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['success'] == true && data['payment_status'] == 'completed') {
          // Pagamento completato!
          _pollingTimer?.cancel();
          _paymentConfirmed = true; // ✅ FIX: segna pagamento come confermato
          final paymentId = data['payment_id'] as String;
          await widget.onPaymentSuccess(paymentId);

          if (mounted) {
            Navigator.of(context).pop(true); // Torna indietro con successo
          }

        } else if (data['success'] == true && data['payment_status'] == 'failed') {
          // ✅ FIX: cancella SOLO se il pagamento non è già stato confermato
          if (_paymentConfirmed) return;
          _pollingTimer?.cancel();
          await widget.onPaymentFailure();
          if (mounted) {
            _showErrorDialog('Pagamento fallito', data['error_description'] ?? 'Il pagamento non è andato a buon fine.');
          }
        }
        // Se status è "pending", continua il polling
      }
    } catch (e) {
      print('⚠️ Errore verifica stato pagamento: $e');
      // ✅ FIX: in caso di errore di rete, continua il polling senza cancellare
    }
  }

  void _showTimeoutDialog() {
    // ✅ FIX: il timeout mostra solo un avviso, non cancella l'appuntamento
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2d2d2d),
        title: const Text(
          'Tempo scaduto',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Non è stato possibile verificare lo stato del pagamento.\n\nSe hai completato il pagamento, controlla la sezione "I miei appuntamenti".',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop(false);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2d2d2d),
        title: Text(
          title,
          style: const TextStyle(color: Colors.white),
        ),
        content: Text(
          message,
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop(false);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollingTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1a1a1a),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2d2d2d),
        title: const Text('Pagamento UniCredit'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (_isInitializing) return;

            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                backgroundColor: const Color(0xFF2d2d2d),
                title: const Text(
                  'Annullare il pagamento?',
                  style: TextStyle(color: Colors.white),
                ),
                content: const Text(
                  'Sei sicuro di voler annullare? L\'appuntamento verrà cancellato.',
                  style: TextStyle(color: Colors.white70),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('No'),
                  ),
                  TextButton(
                    onPressed: () {
                      // ✅ FIX: non cancellare se il pagamento è già confermato
                      if (_paymentConfirmed) {
                        Navigator.of(context).pop();
                        Navigator.of(context).pop(false);
                        return;
                      }
                      _pollingTimer?.cancel();
                      widget.onPaymentFailure();
                      Navigator.of(context).pop();
                      Navigator.of(context).pop(false);
                    },
                    child: const Text(
                      'Sì, annulla',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isInitializing) ...[
                const CircularProgressIndicator(
                  color: Colors.blue,
                ),
                const SizedBox(height: 24),
                const Text(
                  'Inizializzazione pagamento...',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                  ),
                  textAlign: TextAlign.center,
                ),
              ] else if (_errorMessage != null) ...[
                const Icon(
                  Icons.error_outline,
                  color: Colors.red,
                  size: 64,
                ),
                const SizedBox(height: 24),
                const Text(
                  'Errore',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  _errorMessage!,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: _initializePayment,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                  ),
                  child: const Text(
                    'Riprova',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ] else if (_pollingTimer != null && _pollingTimer!.isActive) ...[
                const Icon(
                  Icons.schedule,
                  color: Colors.blue,
                  size: 64,
                ),
                const SizedBox(height: 24),
                const Text(
                  'In attesa del pagamento...',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Completa il pagamento nel browser e torna all\'app.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                const CircularProgressIndicator(
                  color: Colors.blue,
                ),
                const SizedBox(height: 16),
                Text(
                  'Verifica in corso... (${_pollingAttempts}/$_maxPollingAttempts)',
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 14,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}