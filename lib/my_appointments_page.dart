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

  // 🆕 Variabili per gestione storico e filtri
  bool _showingAllPastAppointments = false;
  DateTime? _filterStartDate;
  DateTime? _filterEndDate;

  @override
  void initState() {
    super.initState();
    _loadAppointments();
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // 🔥 CARICAMENTO OTTIMIZZATO: FUTURI + ULTIMI 3 PASSATI
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

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
      final today = DateTime.now().toIso8601String().split('T')[0]; // YYYY-MM-DD

      print('📅 Data odierna: $today');

      // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
      // 🟢 QUERY APPUNTAMENTI FUTURI + OGGI
      // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

      final futureAppointmentsResponse = await supabase
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
          .gte('data', today) // Data >= oggi
          .order('data', ascending: true)
          .order('ora_inizio', ascending: true);

      print('✅ Appuntamenti futuri caricati: ${futureAppointmentsResponse.length}');

      // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
      // ⚫ QUERY ULTIMI 3 APPUNTAMENTI PASSATI
      // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

      final pastAppointmentsResponse = await supabase
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
          .lt('data', today) // Data < oggi
          .order('data', ascending: false) // Dal più recente
          .order('ora_inizio', ascending: false)
          .limit(3); // Solo ultimi 3

      print('✅ Ultimi 3 appuntamenti passati caricati: ${pastAppointmentsResponse.length}');

      // Combina i risultati
      final allAppointments = [
        ...List<Map<String, dynamic>>.from(futureAppointmentsResponse),
        ...List<Map<String, dynamic>>.from(pastAppointmentsResponse),
      ];

      setState(() {
        _appointments = allAppointments;
        _showingAllPastAppointments = false;
        _filterStartDate = null;
        _filterEndDate = null;
        _isLoading = false;
      });

      print('✅ Totale appuntamenti caricati: ${_appointments.length}');

    } catch (e) {
      print('❌ Errore caricamento appuntamenti: $e');
      setState(() => _isLoading = false);

      if (mounted) {
        _showErrorMessage('Errore nel caricamento degli appuntamenti');
      }
    }
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // 📜 CARICAMENTO STORICO COMPLETO (con filtro opzionale)
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Future<void> _loadAllPastAppointments({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    if (user == null) return;

    setState(() => _isLoading = true);

    try {
      final supabase = Supabase.instance.client;

      final userResponse = await supabase
          .from('USERS')
          .select('id')
          .eq('uid', user!.uid)
          .single();

      final userId = userResponse['id'] as int;
      final today = DateTime.now().toIso8601String().split('T')[0];

      print('📜 Caricamento storico completo...');
      if (startDate != null && endDate != null) {
        print('🔍 Con filtro: ${startDate.toIso8601String().split('T')[0]} - ${endDate.toIso8601String().split('T')[0]}');
      }

      // Query base per appuntamenti passati
      var query = supabase
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
          .lt('data', today);

      // Applica filtro date se fornito
      if (startDate != null) {
        final startDateStr = startDate.toIso8601String().split('T')[0];
        query = query.gte('data', startDateStr);
      }

      if (endDate != null) {
        final endDateStr = endDate.toIso8601String().split('T')[0];
        query = query.lte('data', endDateStr);
      }

      final pastResponse = await query
          .order('data', ascending: false)
          .order('ora_inizio', ascending: false);

      print('✅ Storico caricato: ${pastResponse.length} appuntamenti');

      // Carica anche appuntamenti futuri
      final futureResponse = await supabase
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
          .gte('data', today)
          .order('data', ascending: true)
          .order('ora_inizio', ascending: true);

      setState(() {
        _appointments = [
          ...List<Map<String, dynamic>>.from(futureResponse),
          ...List<Map<String, dynamic>>.from(pastResponse),
        ];
        _showingAllPastAppointments = true;
        _filterStartDate = startDate;
        _filterEndDate = endDate;
        _isLoading = false;
      });

    } catch (e) {
      print('❌ Errore caricamento storico: $e');
      setState(() => _isLoading = false);

      if (mounted) {
        _showErrorMessage('Errore nel caricamento dello storico');
      }
    }
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // 🗓️ DIALOG SELEZIONE RANGE DATE
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Future<void> _showDateRangeFilter() async {
    final DateTimeRange? dateRange = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020), // Anno di inizio attività
      lastDate: DateTime.now(),
      initialDateRange: _filterStartDate != null && _filterEndDate != null
          ? DateTimeRange(start: _filterStartDate!, end: _filterEndDate!)
          : null,
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Colors.blue,
              onPrimary: Colors.white,
              surface: Color(0xFF2d2d2d),
              onSurface: Colors.white,
            ),
            dialogBackgroundColor: const Color(0xFF2d2d2d),
          ),
          child: child!,
        );
      },
    );

    if (dateRange != null) {
      await _loadAllPastAppointments(
        startDate: dateRange.start,
        endDate: dateRange.end,
      );
    }
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // 🎨 HELPER FORMATTING
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  String _formatDate(String dateString, {bool showYear = false}) {
    try {
      final date = DateTime.parse(dateString);
      const months = [
        '', 'Gen', 'Feb', 'Mar', 'Apr', 'Mag', 'Giu',
        'Lug', 'Ago', 'Set', 'Ott', 'Nov', 'Dic'
      ];
      const weekdays = [
        '', 'Lun', 'Mar', 'Mer', 'Gio', 'Ven', 'Sab', 'Dom'
      ];

      // Se showYear è true O se l'anno è diverso dall'anno corrente
      final currentYear = DateTime.now().year;
      final shouldShowYear = showYear || date.year != currentYear;

      if (shouldShowYear) {
        return '${weekdays[date.weekday]} ${date.day} ${months[date.month]} ${date.year}';
      } else {
        return '${weekdays[date.weekday]} ${date.day} ${months[date.month]}';
      }
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

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // 📋 MODAL DETTAGLI APPUNTAMENTO
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

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
              child: const Row(
                children: [
                  Icon(
                    Icons.event,
                    color: Colors.blue,
                    size: 24,
                  ),
                  SizedBox(width: 12),
                  Text(
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

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // 🎨 BUILD WIDGET PRINCIPALE
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

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

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // 📭 EMPTY STATE
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

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

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // 📋 LISTA APPUNTAMENTI
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

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
          // 🆕 HEADER CON CONTROLLI
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildSectionHeader('Completati', Colors.grey, pastAppointments.length),

              // 🆕 BOTTONI GESTIONE STORICO
              if (!_showingAllPastAppointments)
              // Bottone "Vedi tutto"
                TextButton.icon(
                  onPressed: () => _loadAllPastAppointments(),
                  icon: const Icon(Icons.history, size: 16),
                  label: const Text('Vedi tutto'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.blue,
                  ),
                )
              else
              // Bottoni quando storico è aperto
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Bottone filtro
                    IconButton(
                      onPressed: _showDateRangeFilter,
                      icon: Icon(
                        Icons.filter_alt,
                        color: _filterStartDate != null ? Colors.blue : Colors.grey,
                        size: 20,
                      ),
                      tooltip: 'Filtra per date',
                    ),

                    // Bottone reset filtro
                    if (_filterStartDate != null)
                      IconButton(
                        onPressed: () {
                          setState(() {
                            _filterStartDate = null;
                            _filterEndDate = null;
                          });
                          _loadAllPastAppointments();
                        },
                        icon: const Icon(Icons.clear, color: Colors.red, size: 20),
                        tooltip: 'Rimuovi filtro',
                      ),

                    // Bottone chiudi storico
                    TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _showingAllPastAppointments = false;
                          _filterStartDate = null;
                          _filterEndDate = null;
                        });
                        _loadAppointments(); // Ricarica solo ultimi 3
                      },
                      icon: const Icon(Icons.close, size: 16),
                      label: const Text('Chiudi'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.grey,
                      ),
                    ),
                  ],
                ),
            ],
          ),

          // 🆕 INFO FILTRO ATTIVO
          if (_filterStartDate != null && _filterEndDate != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12, top: 4),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.blue.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Colors.blue, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Filtro attivo: ${_formatDate(_filterStartDate!.toIso8601String())} - ${_formatDate(_filterEndDate!.toIso8601String())}',
                        style: const TextStyle(
                          color: Colors.blue,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Lista appuntamenti passati
          ...pastAppointments.map((appointment) => _buildAppointmentCard(appointment)),
        ],
      ],
    );
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // 🏷️ SECTION HEADER
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

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

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // 📇 APPOINTMENT CARD
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Widget _buildAppointmentCard(Map<String, dynamic> appointment) {
    final appointmentDate = DateTime.parse(appointment['data']);
    final statusColor = _getStatusColor(appointmentDate);
    final statusText = _getStatusText(appointmentDate);
    final services = appointment['APPUNTAMENTI_SERVIZI'] as List;
    final isPast = appointmentDate.isBefore(DateTime.now());
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
                          _formatDate(appointment['data'], showYear: isPast),
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