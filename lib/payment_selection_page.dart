import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'appointment_notification_service.dart';
import 'stripe_payment_page.dart';
import 'home_page.dart';

class PaymentSelectionPage extends StatefulWidget {
  final String section;
  final List<Map<String, dynamic>> selectedServices;
  final Duration totalDuration;
  final double totalPrice;
  final DateTime selectedDate;
  final String selectedTimeSlot;
  final Map<String, dynamic> selectedStylist;

  const PaymentSelectionPage({
    super.key,
    required this.section,
    required this.selectedServices,
    required this.totalDuration,
    required this.totalPrice,
    required this.selectedDate,
    required this.selectedTimeSlot,
    required this.selectedStylist,
  });

  @override
  State<PaymentSelectionPage> createState() => _PaymentSelectionPageState();
}

class _PaymentSelectionPageState extends State<PaymentSelectionPage> {
  bool _isBooking = false;

  Future<int> _createAppointment() async {
    final supabase = Supabase.instance.client;
    final user = firebase_auth.FirebaseAuth.instance.currentUser;

    if (user == null) {
      throw Exception('Utente non autenticato');
    }

    // Recupera l'ID dell'utente dalla tabella USERS
    final userResponse = await supabase
        .from('USERS')
        .select('id')
        .eq('uid', user.uid)
        .single();

    final userId = userResponse['id'] as int;

    // Calcola ora_fine
    final startDateTime = DateTime.parse(
        '${widget.selectedDate.year}-${widget.selectedDate.month.toString().padLeft(2, '0')}-${widget.selectedDate.day.toString().padLeft(2, '0')} ${widget.selectedTimeSlot}:00'
    );
    final endDateTime = startDateTime.add(widget.totalDuration);

    final dateString = '${widget.selectedDate.year}-${widget.selectedDate.month.toString().padLeft(2, '0')}-${widget.selectedDate.day.toString().padLeft(2, '0')}';
    final endTimeString = '${endDateTime.hour.toString().padLeft(2, '0')}:${endDateTime.minute.toString().padLeft(2, '0')}';
    final durationString = '${widget.totalDuration.inHours.toString().padLeft(2, '0')}:${widget.totalDuration.inMinutes.remainder(60).toString().padLeft(2, '0')}:00';

    // 1. Crea l'appuntamento
    final appointmentResponse = await supabase
        .from('APPUNTAMENTI')
        .insert({
      'stylist_id': widget.selectedStylist['id'],
      'user_id': userId,
      'data': dateString,
      'ora_inizio': '${widget.selectedTimeSlot}:00',
      'ora_fine': '$endTimeString:00',
      'durata_totale': durationString,
      'prezzo_totale': widget.totalPrice,
      'note': 'Prenotazione tramite app',
    })
        .select()
        .single();

    final appointmentId = appointmentResponse['id'] as int;
    print('✅ Appuntamento creato con ID: $appointmentId');

    try {
      // Ottieni i dati dell'utente
      final user = firebase_auth.FirebaseAuth.instance.currentUser;
      final userRecord = await supabase
          .from('USERS')
          .select('nome, cognome')
          .eq('uid', user!.uid)
          .single();

      // Programma la notifica
      await AppointmentNotificationService.scheduleAppointmentReminder(
        appointmentId: appointmentId,
        clientName: '${userRecord['nome']} ${userRecord['cognome']}',
        stylistName: widget.selectedStylist['descrizione'],
        appointmentDate: widget.selectedDate,
        appointmentTime: widget.selectedTimeSlot,
        services: widget.selectedServices
            .map((s) => s['descrizione'] as String)
            .toList(),
      );

      print('🔔 Notifica promemoria programmata');
    } catch (e) {
      print('⚠️ Errore programmazione notifica (non critico): $e');
    }

    // 2. Collega i servizi all'appuntamento
    List<Map<String, dynamic>> servicesData = widget.selectedServices.map((service) => {
      'appuntamento_id': appointmentId,
      'servizio_id': service['id'],
      'quantita': 1,
    }).toList();

    await supabase
        .from('APPUNTAMENTI_SERVIZI')
        .insert(servicesData);

    print('✅ ${servicesData.length} servizi collegati all appuntamento');

        return appointmentId;
    }

  Future<void> _createPaymentRecord(int appointmentId, String method, String status, String? stripePaymentIntentId) async {
    final supabase = Supabase.instance.client;

    await supabase
        .from('PAGAMENTI')
        .insert({
      'appuntamento_id': appointmentId,
      'metodo_pagamento': method,
      'stato': status,
      'importo': widget.totalPrice,
      'stripe_payment_intent_id': stripePaymentIntentId,
    });

    print('✅ Record pagamento creato: $method - $status');
  }

  Future<void> _selectPaymentInLoco() async {
    setState(() => _isBooking = true);

    try {
      // Crea appuntamento
      final appointmentId = await _createAppointment();

      // Crea record pagamento "in loco"
      await _createPaymentRecord(appointmentId, 'in_loco', 'in_attesa', null);

      if (mounted) {
        _showSuccessDialog(
          'Prenotazione completata!',
          'Il tuo appuntamento è stato prenotato.\nPagamento in loco al momento del servizio.',
        );
      }

    } catch (e) {
      print('❌ Errore durante la prenotazione: $e');
      if (mounted) {
        _showErrorMessage('Errore durante la prenotazione: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isBooking = false);
      }
    }
  }

  Future<void> _selectPaymentStripe() async {
    setState(() => _isBooking = true);

    try {
      // Crea appuntamento
      final appointmentId = await _createAppointment();

      // Naviga a Stripe con l'ID appuntamento
      if (mounted) {
        setState(() => _isBooking = false);

        final result = await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => StripePaymentPage(
              appointmentId: appointmentId,
              totalPrice: widget.totalPrice,
              description: 'Appuntamento ${_formatDate(widget.selectedDate)} alle ${widget.selectedTimeSlot}',
              onPaymentSuccess: (paymentIntentId) async {
                // Aggiorna record pagamento
                await _createPaymentRecord(appointmentId, 'stripe', 'completato', paymentIntentId);
              },
              onPaymentFailure: () async {
                // Elimina appuntamento se pagamento fallisce
                await _cancelAppointment(appointmentId);
              },
            ),
          ),
        );

        if (result == true) {
          // Pagamento completato con successo
          _showSuccessDialog(
            'Pagamento completato!',
            'Il tuo appuntamento è stato prenotato e pagato.\nRiceverai conferma via email.',
          );
        }
      }

    } catch (e) {
      print('❌ Errore durante la prenotazione: $e');
      if (mounted) {
        setState(() => _isBooking = false);
        _showErrorMessage('Errore durante la prenotazione: $e');
      }
    }
  }

  Future<void> _cancelAppointment(int appointmentId) async {
    try {
      final supabase = Supabase.instance.client;

      // Elimina servizi collegati
      await supabase
          .from('APPUNTAMENTI_SERVIZI')
          .delete()
          .eq('appuntamento_id', appointmentId);

      // Elimina appuntamento
      await supabase
          .from('APPUNTAMENTI')
          .delete()
          .eq('id', appointmentId);

      print('✅ Appuntamento $appointmentId cancellato');
    } catch (e) {
      print('❌ Errore cancellazione appuntamento: $e');
    }
  }

  String _formatDate(DateTime date) {
    const months = [
      '', 'Gennaio', 'Febbraio', 'Marzo', 'Aprile', 'Maggio', 'Giugno',
      'Luglio', 'Agosto', 'Settembre', 'Ottobre', 'Novembre', 'Dicembre'
    ];
    const weekdays = [
      '', 'Lunedì', 'Martedì', 'Mercoledì', 'Giovedì', 'Venerdì', 'Sabato', 'Domenica'
    ];

    return '${weekdays[date.weekday]}, ${date.day} ${months[date.month]}';
  }

  void _showSuccessDialog(String title, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.green[100],
            borderRadius: BorderRadius.circular(50),
          ),
          child: const Icon(Icons.check_circle, color: Colors.green, size: 48),
        ),
        title: Text(title, textAlign: TextAlign.center),
        content: Text(message, textAlign: TextAlign.center),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const HomePage()),
                      (route) => false,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Torna alla Home'),
            ),
          ),
        ],
      ),
    );
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
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
          'Scegli Metodo di Pagamento',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Riepilogo appuntamento
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF2d2d2d),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.calendar_today,
                            color: Colors.blue,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Riepilogo Appuntamento',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    _buildSummaryRow('Data', _formatDate(widget.selectedDate)),
                    _buildSummaryRow('Orario', '${widget.selectedTimeSlot} - ${_getEndTime()}'),
                    _buildSummaryRow('Stylist', widget.selectedStylist['descrizione']),
                    _buildSummaryRow('Servizi', '${widget.selectedServices.length} servizio/i'),

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
                            color: Colors.blue,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Titolo selezione pagamento
              const Text(
                'Come preferisci pagare?',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Scegli il metodo di pagamento più comodo per te',
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 16,
                ),
              ),

              const SizedBox(height: 24),

              // Opzione Paga in Loco
              _buildPaymentOption(
                title: 'Paga in Loco',
                subtitle: 'Pagamento diretto al salone',
                description: 'Paga comodamente quando arrivi per l\'appuntamento. Accettiamo contanti e carte.',
                icon: Icons.store,
                color: Colors.green,
                onTap: _isBooking ? null : _selectPaymentInLoco,
              ),

              const SizedBox(height: 16),

              // Opzione Paga Ora con Stripe
              _buildPaymentOption(
                title: 'Paga Ora Online',
                subtitle: 'Pagamento sicuro con Stripe',
                description: 'Paga subito in modo sicuro con carta di credito/debito. Prenotazione garantita.',
                icon: Icons.payment,
                color: Colors.blue,
                onTap: _isBooking ? null : _selectPaymentStripe,
                badge: 'SICURO',
              ),

              const SizedBox(height: 32),

              // Info aggiuntive
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.orange.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.orange,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Informazioni importanti',
                            style: TextStyle(
                              color: Colors.orange,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '• Pagamento online: prenotazione immediata e garantita\n• Pagamento in loco: soggetto a disponibilità cassa\n• Cancellazione gratuita fino a 24h prima',
                            style: TextStyle(
                              color: Colors.grey[300],
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              if (_isBooking) ...[
                const SizedBox(height: 32),
                const Center(
                  child: CircularProgressIndicator(
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(height: 16),
                const Center(
                  child: Text(
                    'Creazione appuntamento in corso...',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 14,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentOption({
    required String title,
    required String subtitle,
    required String description,
    required IconData icon,
    required Color color,
    required VoidCallback? onTap,
    String? badge,
  }) {
    return Card(
      color: const Color(0xFF2d2d2d),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      icon,
                      color: color,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (badge != null) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: color.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  badge,
                                  style: TextStyle(
                                    color: color,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios,
                    color: Colors.grey[400],
                    size: 16,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                description,
                style: TextStyle(
                  color: Colors.grey[300],
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getEndTime() {
    final startDateTime = DateTime.parse(
        '2000-01-01 ${widget.selectedTimeSlot}:00'
    );
    final endDateTime = startDateTime.add(widget.totalDuration);
    return '${endDateTime.hour.toString().padLeft(2, '0')}:${endDateTime.minute.toString().padLeft(2, '0')}';
  }
}