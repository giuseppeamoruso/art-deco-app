import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:supabase_flutter/supabase_flutter.dart';

class MyAppointmentsPage extends StatefulWidget {
  const MyAppointmentsPage({super.key});

  @override
  State<MyAppointmentsPage> createState() => _MyAppointmentsPageState();
}

class _MyAppointmentsPageState extends State<MyAppointmentsPage> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _appointments = [];
  final firebase_auth.User? user = firebase_auth.FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _loadAppointments();
  }

  Future<void> _loadAppointments() async {
    if (user == null) {
      _showErrorMessage('Utente non autenticato');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final supabase = Supabase.instance.client;

      // Recupera l'ID dell'utente dalla tabella USERS
      final userResponse = await supabase
          .from('USERS')
          .select('id')
          .eq('uid', user!.uid)
          .single();

      final userId = userResponse['id'] as int;

      // Query per ottenere appuntamenti con dettagli stylist e servizi
      final appointmentsResponse = await supabase
          .from('APPUNTAMENTI')
          .select('''
            id,
            data,
            ora_inizio,
            ora_fine,
            durata_totale,
            prezzo_totale,
            note,
            created_at,
            STYLIST!inner(descrizione),
            APPUNTAMENTI_SERVIZI!inner(
              SERVIZI!inner(descrizione, prezzo, durata)
            )
          ''')
          .eq('user_id', userId)
          .order('data', ascending: true)
          .order('ora_inizio', ascending: true);

      setState(() {
        _appointments = List<Map<String, dynamic>>.from(appointmentsResponse);
        _isLoading = false;
      });

      print('✅ Appuntamenti caricati: ${_appointments.length}');

    } catch (e) {
      print('❌ Errore caricamento appuntamenti: $e');
      setState(() => _isLoading = false);

      if (mounted) {
        _showErrorMessage('Errore nel caricamento degli appuntamenti');
      }
    }
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      const months = [
        '', 'Gen', 'Feb', 'Mar', 'Apr', 'Mag', 'Giu',
        'Lug', 'Ago', 'Set', 'Ott', 'Nov', 'Dic'
      ];
      const weekdays = [
        '', 'Lun', 'Mar', 'Mer', 'Gio', 'Ven', 'Sab', 'Dom'
      ];

      return '${weekdays[date.weekday]} ${date.day} ${months[date.month]}';
    } catch (e) {
      return dateString;
    }
  }

  String _formatTime(String timeString) {
    return timeString.substring(0, 5); // Rimuove i secondi
  }

  String _formatDuration(String durationString) {
    try {
      final parts = durationString.split(':');
      final hours = int.parse(parts[0]);
      final minutes = int.parse(parts[1]);

      if (hours > 0) {
        return '${hours}h ${minutes}m';
      } else {
        return '${minutes}m';
      }
    } catch (e) {
      return durationString;
    }
  }

  Color _getStatusColor(DateTime appointmentDate) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final appointment = DateTime(appointmentDate.year, appointmentDate.month, appointmentDate.day);

    if (appointment.isBefore(today)) {
      return Colors.grey; // Passato
    } else if (appointment.isAtSameMomentAs(today)) {
      return Colors.orange; // Oggi
    } else {
      return Colors.green; // Futuro
    }
  }

  String _getStatusText(DateTime appointmentDate) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final appointment = DateTime(appointmentDate.year, appointmentDate.month, appointmentDate.day);

    if (appointment.isBefore(today)) {
      return 'Completato';
    } else if (appointment.isAtSameMomentAs(today)) {
      return 'Oggi';
    } else {
      final difference = appointment.difference(today).inDays;
      if (difference == 1) {
        return 'Domani';
      } else {
        return 'Tra $difference giorni';
      }
    }
  }

  void _showAppointmentDetails(Map<String, dynamic> appointment) {
    final services = appointment['APPUNTAMENTI_SERVIZI'] as List;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: const BoxDecoration(
          color: Color(0xFF2d2d2d),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[400],
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header
            Container(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Icon(
                    Icons.event,
                    color: Colors.blue,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Dettagli Appuntamento',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Info base
                    _buildDetailRow('Stylist', appointment['STYLIST']['descrizione']),
                    _buildDetailRow('Data', _formatDate(appointment['data'])),
                    _buildDetailRow('Orario', '${_formatTime(appointment['ora_inizio'])} - ${_formatTime(appointment['ora_fine'])}'),
                    _buildDetailRow('Durata', _formatDuration(appointment['durata_totale'])),

                    const SizedBox(height: 24),

                    // Servizi
                    const Text(
                      'Servizi',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),

                    ...services.map((service) {
                      final serviceData = service['SERVIZI'];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1a1a1a),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.content_cut,
                              color: Colors.blue,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                serviceData['descrizione'],
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            Text(
                              serviceData['prezzo'].toString(),
                              style: const TextStyle(
                                color: Colors.blue,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),

                    const SizedBox(height: 24),

                    // Prezzo totale
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue.withOpacity(0.3)),
                      ),
                      child: Row(
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
                            '€${appointment['prezzo_totale'].toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: Colors.blue,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
              ),
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
        duration: const Duration(seconds: 3),
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
          'I Miei Appuntamenti',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadAppointments,
            tooltip: 'Ricarica',
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(
          child: CircularProgressIndicator(color: Colors.white),
        )
            : _appointments.isEmpty
            ? _buildEmptyState()
            : _buildAppointmentsList(),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.event_busy,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Nessun appuntamento',
            style: TextStyle(
              color: Colors.grey[300],
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Non hai ancora prenotato nessun appuntamento',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('Prenota Ora'),
          ),
        ],
      ),
    );
  }

  Widget _buildAppointmentsList() {
    // Raggruppa appuntamenti per stato (futuri, oggi, passati)
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final futureAppointments = <Map<String, dynamic>>[];
    final todayAppointments = <Map<String, dynamic>>[];
    final pastAppointments = <Map<String, dynamic>>[];

    for (final appointment in _appointments) {
      final appointmentDate = DateTime.parse(appointment['data']);
      final appointmentDay = DateTime(appointmentDate.year, appointmentDate.month, appointmentDate.day);

      if (appointmentDay.isAfter(today)) {
        futureAppointments.add(appointment);
      } else if (appointmentDay.isAtSameMomentAs(today)) {
        todayAppointments.add(appointment);
      } else {
        pastAppointments.add(appointment);
      }
    }

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Appuntamenti di oggi
        if (todayAppointments.isNotEmpty) ...[
          _buildSectionHeader('Oggi', Colors.orange, todayAppointments.length),
          ...todayAppointments.map((appointment) => _buildAppointmentCard(appointment)),
          const SizedBox(height: 24),
        ],

        // Appuntamenti futuri
        if (futureAppointments.isNotEmpty) ...[
          _buildSectionHeader('Prossimi', Colors.green, futureAppointments.length),
          ...futureAppointments.map((appointment) => _buildAppointmentCard(appointment)),
          const SizedBox(height: 24),
        ],

        // Appuntamenti passati
        if (pastAppointments.isNotEmpty) ...[
          _buildSectionHeader('Completati', Colors.grey, pastAppointments.length),
          ...pastAppointments.map((appointment) => _buildAppointmentCard(appointment)),
        ],
      ],
    );
  }

  Widget _buildSectionHeader(String title, Color color, int count) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              title == 'Oggi' ? Icons.today :
              title == 'Prossimi' ? Icons.upcoming :
              Icons.history,
              color: color,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '$title ($count)',
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppointmentCard(Map<String, dynamic> appointment) {
    final appointmentDate = DateTime.parse(appointment['data']);
    final statusColor = _getStatusColor(appointmentDate);
    final statusText = _getStatusText(appointmentDate);
    final services = appointment['APPUNTAMENTI_SERVIZI'] as List;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Card(
        color: const Color(0xFF2d2d2d),
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showAppointmentDetails(appointment),
          child: Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header con data e status
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _formatDate(appointment['data']),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${_formatTime(appointment['ora_inizio'])} - ${_formatTime(appointment['ora_fine'])}',
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        statusText,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Stylist
                Row(
                  children: [
                    Icon(
                      Icons.person,
                      color: Colors.grey[400],
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      appointment['STYLIST']['descrizione'],
                      style: TextStyle(
                        color: Colors.grey[300],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                // Servizi (solo il primo + conteggio)
                Row(
                  children: [
                    Icon(
                      Icons.content_cut,
                      color: Colors.grey[400],
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        services.length == 1
                            ? services[0]['SERVIZI']['descrizione']
                            : '${services[0]['SERVIZI']['descrizione']} +${services.length - 1} altro/i',
                        style: TextStyle(
                          color: Colors.grey[300],
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Footer con prezzo e durata
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '€${appointment['prezzo_totale'].toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: Colors.blue,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      _formatDuration(appointment['durata_totale']),
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}