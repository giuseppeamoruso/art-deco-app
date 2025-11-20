import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class StripePaymentPage extends StatefulWidget {
  final int appointmentId;
  final double totalPrice;
  final String description;
  final Function(String paymentIntentId) onPaymentSuccess;
  final VoidCallback onPaymentFailure;

  const StripePaymentPage({
    super.key,
    required this.appointmentId,
    required this.totalPrice,
    required this.description,
    required this.onPaymentSuccess,
    required this.onPaymentFailure,
  });

  @override
  State<StripePaymentPage> createState() => _StripePaymentPageState();
}

class _StripePaymentPageState extends State<StripePaymentPage> {
  bool _isLoading = false;
  String _debugInfo = '';
  bool _showDebug = false;

  // 🔑 Le tue chiavi Stripe (sostituisci con le tue)

  static const String _stripePublishableKey = 'pk_test_51Rvb1rDBoR58Myyr474otYnZOugsk2nfa8ZMzLVY6hMZACFnwXjIhXalachexAvyT1V01CsXw47BSCQECko5jOFv00WO0rAkkW';
  static const String _stripeSecretKey = 'sk_test_51Rvb1rDBoR58Myyr5r12IgVWSQDKCv2cun51VrCRdQiyNLaRu1ws71pYNjTOweBSIEaIMuzgIhxssCNxxA81ex9K00bxHc21zg';

  @override
  void initState() {
    super.initState();
    Stripe.publishableKey = _stripePublishableKey;
    _addDebugInfo('✅ Stripe inizializzato per appuntamento ${widget.appointmentId}');
  }

  void _addDebugInfo(String info) {
    setState(() {
      _debugInfo += '${DateTime.now().toString().substring(11, 19)}: $info\n';
    });
    print('🔍 DEBUG: $info');
  }

  Future<void> _processPayment() async {
    setState(() => _isLoading = true);
    _addDebugInfo('🚀 Inizio processamento pagamento');

    try {
      // 1. Crea Payment Intent
      final paymentIntentData = await _createPaymentIntent();

      if (paymentIntentData == null) {
        _addDebugInfo('❌ Errore creazione Payment Intent');
        widget.onPaymentFailure();
        _showErrorDialog('Errore nella creazione del pagamento');
        return;
      }

      _addDebugInfo('✅ Payment Intent creato: ${paymentIntentData['id']}');

      // 2. Inizializza Payment Sheet
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: paymentIntentData['client_secret'],
          merchantDisplayName: 'ArtDecò Parrucchieri',
          style: ThemeMode.light,
          appearance: const PaymentSheetAppearance(
            primaryButton: PaymentSheetPrimaryButtonAppearance(
              colors: PaymentSheetPrimaryButtonTheme(
                light: PaymentSheetPrimaryButtonThemeColors(
                  background: Color(0xFF6772E5),
                  text: Colors.white,
                ),
              ),
            ),
          ),
        ),
      );

      _addDebugInfo('📱 Payment Sheet inizializzato');

      // 3. Mostra Payment Sheet
      await Stripe.instance.presentPaymentSheet();

      _addDebugInfo('🎉 Pagamento completato con successo!');

      // 4. Chiama callback di successo
      await widget.onPaymentSuccess(paymentIntentData['id']);

      if (mounted) {
        Navigator.of(context).pop(true); // Ritorna successo
      }

    } on StripeException catch (e) {
      _addDebugInfo('❌ Stripe Exception: ${e.error.localizedMessage}');

      if (e.error.code != FailureCode.Canceled) {
        widget.onPaymentFailure();
        _showErrorDialog('Errore Stripe: ${e.error.localizedMessage}');
      } else {
        _addDebugInfo('🚫 Pagamento annullato dall\'utente');
        Navigator.of(context).pop(false); // Ritorna annullato
      }
    } catch (e) {
      _addDebugInfo('💥 Errore generico: $e');
      widget.onPaymentFailure();
      _showErrorDialog('Errore: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<Map<String, dynamic>?> _createPaymentIntent() async {
    try {
      _addDebugInfo('🌐 Chiamata API Stripe per Payment Intent');

      final response = await http.post(
        Uri.parse('https://api.stripe.com/v1/payment_intents'),
        headers: {
          'Authorization': 'Bearer $_stripeSecretKey',
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'amount': (widget.totalPrice * 100).round().toString(),
          'currency': 'eur',
          'description': widget.description,
          'metadata[appointment_id]': widget.appointmentId.toString(),
          'automatic_payment_methods[enabled]': 'true',
        },
      );

      _addDebugInfo('📊 Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data;
      } else {
        _addDebugInfo('❌ Errore API: ${response.body}');
        return null;
      }
    } catch (e) {
      _addDebugInfo('💥 Eccezione API: $e');
      return null;
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2d2d2d),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red[100],
                borderRadius: BorderRadius.circular(50),
              ),
              child: const Icon(Icons.error, color: Colors.red, size: 24),
            ),
            const SizedBox(width: 12),
            const Text('Errore Pagamento', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: Text(message, style: const TextStyle(color: Colors.white70)),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop(false);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Chiudi'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1a1a1a),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2d2d2d),
        elevation: 0,
        title: const Text(
          'Pagamento Sicuro',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(false),
        ),
        actions: [
          if (_showDebug)
            IconButton(
              icon: const Icon(Icons.bug_report, color: Colors.white),
              onPressed: () => setState(() => _showDebug = !_showDebug),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Debug area
            if (_showDebug) ...[
              Container(
                width: double.infinity,
                height: 120,
                margin: const EdgeInsets.all(8),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    _debugInfo.isEmpty ? 'Debug log...' : _debugInfo,
                    style: const TextStyle(
                      color: Colors.green,
                      fontSize: 11,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ),
            ],

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    // Header Stripe
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF6772E5), Color(0xFF5469D4)],
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.payment,
                              size: 48,
                              color: Color(0xFF6772E5),
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Pagamento Sicuro',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Powered by Stripe • SSL Certificato',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Dettagli pagamento
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2d2d2d),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Dettagli Pagamento',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Appuntamento',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                '#${widget.appointmentId}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Descrizione',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 14,
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  widget.description,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  textAlign: TextAlign.right,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          Container(
                            height: 1,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(height: 16),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'TOTALE',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '€${widget.totalPrice.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  color: Color(0xFF6772E5),
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Sicurezza info
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.security,
                            color: Colors.green[400],
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Pagamento Sicuro al 100%',
                                  style: TextStyle(
                                    color: Colors.green[300],
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'I tuoi dati sono protetti con crittografia SSL',
                                  style: TextStyle(
                                    color: Colors.grey[300],
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Pulsante Paga
                    SizedBox(
                      width: double.infinity,
                      height: 60,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _processPayment,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6772E5),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 4,
                        ),
                        child: _isLoading
                            ? const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                            SizedBox(width: 12),
                            Text(
                              'Elaborando...',
                              style: TextStyle(fontSize: 16),
                            ),
                          ],
                        )
                            : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.payment, size: 24),
                            const SizedBox(width: 12),
                            Text(
                              'Paga €${widget.totalPrice.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Info commissioni
                    Text(
                      'Commissioni Stripe: 2.9% + €0.30',
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 12,
                      ),
                    ),

                    // Debug toggle (solo in development)
                    if (!_showDebug) ...[
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: () => setState(() => _showDebug = true),
                        child: Text(
                          'Debug Mode',
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}