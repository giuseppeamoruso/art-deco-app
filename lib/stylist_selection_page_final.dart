import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'booking_confirmation_page.dart';

class StylistSelectionPageFinal extends StatefulWidget {
  final String section;
  final List<Map<String, dynamic>> selectedServices;
  final Duration totalDuration;
  final double totalPrice;
  final DateTime selectedDate;
  final String selectedTimeSlot;

  const StylistSelectionPageFinal({
    super.key,
    required this.section,
    required this.selectedServices,
    required this.totalDuration,
    required this.totalPrice,
    required this.selectedDate,
    required this.selectedTimeSlot,
  });

  @override
  State<StylistSelectionPageFinal> createState() => _StylistSelectionPageFinalState();
}

class _StylistSelectionPageFinalState extends State<StylistSelectionPageFinal> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _availableStylists = [];
  Map<String, dynamic>? _selectedStylist;

  @override
  void initState() {
    super.initState();
    _loadAvailableStylists();
  }

  Future<void> _loadAvailableStylists() async {
    setState(() => _isLoading = true);

    try {
      final supabase = Supabase.instance.client;
      final sessoId = widget.section == 'uomo' ? 1 : 2;
      final dateString = '${widget.selectedDate.year}-${widget.selectedDate.month.toString().padLeft(2, '0')}-${widget.selectedDate.day.toString().padLeft(2, '0')}';

      // Calcola orario fine
      final startDateTime = DateTime.parse('$dateString ${widget.selectedTimeSlot}:00');
      final endDateTime = startDateTime.add(widget.totalDuration);
      final endTime = '${endDateTime.hour.toString().padLeft(2, '0')}:${endDateTime.minute.toString().padLeft(2, '0')}';

      // 1. Query per ottenere tutti gli stylist del sesso giusto
      final allStylistsResponse = await supabase
          .from('STYLIST')
          .select('''
            id,
            descrizione,
            STYLIST_SESSO_TAGLIO!inner(sesso_id)
          ''')
          .eq('STYLIST_SESSO_TAGLIO.sesso_id', sessoId)
          .isFilter('deleted_at', null);

      List<Map<String, dynamic>> allStylists = List<Map<String, dynamic>>.from(allStylistsResponse);
      List<int> allStylistIds = allStylists.map((s) => s['id'] as int).toList();

      // 2. Query per ottenere appuntamenti esistenti che si sovrappongono
      final appointmentsResponse = await supabase
          .from('APPUNTAMENTI')
          .select('stylist_id, ora_inizio, ora_fine')
          .eq('data', dateString);

      // 3. *** NUOVA QUERY PER ASSENZE ***
      final assenzeResponse = await supabase
          .from('STYLIST_ASSENZE')
          .select('stylist_id, tipo, data_inizio, data_fine, ora_inizio, ora_fine')
          .eq('stato', 'approvato')
          .inFilter('stylist_id', allStylistIds);

      print('🔍 Controllo stylist per data $dateString slot ${widget.selectedTimeSlot}');

      // 4. Trova stylist NON disponibili (occupati con appuntamenti)
      Set<int> busyStylistIds = {};

      for (var appointment in appointmentsResponse) {
        final appoStart = appointment['ora_inizio'] as String;
        final appoEnd = appointment['ora_fine'] as String;

        if (_timeOverlaps(widget.selectedTimeSlot, endTime, appoStart, appoEnd)) {
          busyStylistIds.add(appointment['stylist_id'] as int);
          print('   - Stylist ${appointment['stylist_id']} occupato con appuntamento');
        }
      }

      // 5. *** NUOVO: Trova stylist in assenza ***
      for (var assenza in assenzeResponse) {
        int stylistId = assenza['stylist_id'];

        if (_isStylistInAssenza(assenza, dateString, widget.selectedTimeSlot, endTime)) {
          busyStylistIds.add(stylistId);
          print('   - Stylist $stylistId in assenza: ${assenza['tipo']}');
        }
      }

      // 6. Filtra solo gli stylist disponibili
      List<Map<String, dynamic>> availableStylists = allStylists
          .where((stylist) => !busyStylistIds.contains(stylist['id']))
          .toList();

      setState(() {
        _availableStylists = availableStylists;
        _isLoading = false;
      });

      print('✅ Stylist disponibili per ${widget.selectedTimeSlot}: ${_availableStylists.length}/${allStylists.length}');

    } catch (e) {
      print('❌ Errore caricamento stylist disponibili: $e');
      setState(() => _isLoading = false);

      if (mounted) {
        _showErrorMessage('Errore nel caricamento degli stylist disponibili');
      }
    }
  }

  bool _isStylistInAssenza(
      Map<String, dynamic> assenza,
      String dateString,
      String slotStartTime,
      String slotEndTime
      ) {
    final tipo = assenza['tipo'] as String;
    final dataInizio = assenza['data_inizio'] as String?;
    final dataFine = assenza['data_fine'] as String?;

    // Controlla se la data è nel range dell'assenza
    bool isDateInRange = false;

    if (dataFine == null) {
      // Assenza di un solo giorno
      isDateInRange = dataInizio == dateString;
    } else {
      // Assenza con range di date
      isDateInRange = dateString.compareTo(dataInizio!) >= 0 &&
          dateString.compareTo(dataFine) <= 0;
    }

    if (!isDateInRange) {
      return false; // La data non è nel range dell'assenza
    }

    // Se è permesso ore, controlla anche gli orari
    if (tipo == 'permesso_ore') {
      final oraInizio = assenza['ora_inizio'] as String?;
      final oraFine = assenza['ora_fine'] as String?;

      if (oraInizio != null && oraFine != null) {
        // Converti in formato HH:MM per il confronto
        String assenzaStart = _formatTimeForComparison(oraInizio);
        String assenzaEnd = _formatTimeForComparison(oraFine);

        // Controlla sovrapposizione oraria
        return _timeOverlaps(slotStartTime, slotEndTime, assenzaStart, assenzaEnd);
      }
    }

    // Per ferie, malattia, permesso_giorno: stylist non disponibile per l'intera giornata
    if (tipo == 'ferie' || tipo == 'malattia' || tipo == 'permesso_giorno') {
      return true; // Stylist non disponibile per tutto il giorno
    }

    return false;
  }

  String _formatTimeForComparison(String timeStr) {
    // Gestisce formati come "HH:MM:SS" o "HH:MM:SS.microseconds"
    try {
      String cleanTime = timeStr.split('.').first;
      if (cleanTime.length > 8) {
        cleanTime = cleanTime.substring(0, 8);
      }
      return cleanTime.substring(0, 5); // Ritorna solo HH:MM
    } catch (e) {
      return timeStr;
    }
  }

  bool _timeOverlaps(String start1, String end1, String start2, String end2) {
    final s1 = _parseTime(start1);
    final e1 = _parseTime(end1);
    final s2 = _parseTime(start2);
    final e2 = _parseTime(end2);

    return s1.isBefore(e2) && s2.isBefore(e1);
  }

  DateTime _parseTime(String time) {
    final parts = time.split(':');
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);
    return DateTime(2000, 1, 1, hour, minute);
  }

  void _selectStylist(Map<String, dynamic> stylist) {
    setState(() {
      _selectedStylist = stylist;
    });
  }

  String _formatDate(DateTime date) {
    const months = [
      '', 'Gen', 'Feb', 'Mar', 'Apr', 'Mag', 'Giu',
      'Lug', 'Ago', 'Set', 'Ott', 'Nov', 'Dic'
    ];
    const weekdays = [
      '', 'Lun', 'Mar', 'Mer', 'Gio', 'Ven', 'Sab', 'Dom'
    ];

    return '${weekdays[date.weekday]} ${date.day} ${months[date.month]}';
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }

  void _navigateToConfirmation() {
    if (_selectedStylist == null) {
      _showErrorMessage('Seleziona uno stylist per continuare');
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => BookingConfirmationPage(
          section: widget.section,
          selectedServices: widget.selectedServices,
          totalDuration: widget.totalDuration,
          totalPrice: widget.totalPrice,
          selectedDate: widget.selectedDate,
          selectedTimeSlot: widget.selectedTimeSlot,
          selectedStylist: _selectedStylist!,
        ),
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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Scegli il tuo Stylist',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              '${_formatDate(widget.selectedDate)} alle ${widget.selectedTimeSlot}',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
              ),
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Riepilogo prenotazione
            Container(
              width: double.infinity,
              margin: const EdgeInsets.all(20),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF2d2d2d),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Riepilogo prenotazione',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Servizi: ${widget.selectedServices.length}',
                    style: TextStyle(
                      color: Colors.grey[300],
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    'Durata: ${_formatDuration(widget.totalDuration)}',
                    style: TextStyle(
                      color: Colors.grey[300],
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    'Prezzo: €${widget.totalPrice.toStringAsFixed(2)}',
                    style: TextStyle(
                      color: widget.section == 'donna' ? Colors.pink : Colors.blue,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            // Lista stylist disponibili
            Expanded(
              child: _isLoading
                  ? const Center(
                child: CircularProgressIndicator(color: Colors.white),
              )
                  : _availableStylists.isEmpty
                  ? _buildEmptyState()
                  : _buildStylistsList(),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _selectedStylist != null
          ? Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF2d2d2d),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              spreadRadius: 2,
              blurRadius: 8,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _navigateToConfirmation,
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.section == 'donna'
                    ? Colors.pink
                    : Colors.blue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 3,
              ),
              child: Text(
                'Conferma con ${_selectedStylist!['descrizione']}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      )
          : null,
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.person_off,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          const Text(
            'Nessun stylist disponibile',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'per ${_formatDate(widget.selectedDate)} alle ${widget.selectedTimeSlot}',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF1a1a1a),
            ),
            child: const Text('Scegli un altro orario'),
          ),
        ],
      ),
    );
  }

  Widget _buildStylistsList() {
    return Column(
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Icon(
                Icons.group,
                color: widget.section == 'donna' ? Colors.pink : Colors.blue,
                size: 24,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Stylist disponibili',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${_availableStylists.length} professional/i libero/i',
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Lista stylist
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: _availableStylists.length,
            itemBuilder: (context, index) {
              final stylist = _availableStylists[index];
              final isSelected = _selectedStylist?['id'] == stylist['id'];

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                child: Card(
                  color: isSelected
                      ? (widget.section == 'donna' ? Colors.pink.withOpacity(0.1) : Colors.blue.withOpacity(0.1))
                      : const Color(0xFF2d2d2d),
                  elevation: isSelected ? 8 : 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: isSelected
                        ? BorderSide(
                      color: widget.section == 'donna' ? Colors.pink : Colors.blue,
                      width: 2,
                    )
                        : BorderSide.none,
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => _selectStylist(stylist),
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          // Avatar stylist
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: widget.section == 'donna'
                                  ? Colors.pink.withOpacity(0.2)
                                  : Colors.blue.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(30),
                              border: isSelected
                                  ? Border.all(
                                color: widget.section == 'donna' ? Colors.pink : Colors.blue,
                                width: 2,
                              )
                                  : null,
                            ),
                            child: Icon(
                              Icons.person,
                              color: widget.section == 'donna' ? Colors.pink : Colors.blue,
                              size: 30,
                            ),
                          ),

                          const SizedBox(width: 16),

                          // Informazioni stylist
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  stylist['descrizione'] ?? 'Stylist',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Specialista ${widget.section}',
                                  style: TextStyle(
                                    color: Colors.grey[400],
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'Libero alle ${widget.selectedTimeSlot}',
                                    style: const TextStyle(
                                      color: Colors.green,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Icona selezione
                          if (isSelected)
                            Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: widget.section == 'donna' ? Colors.pink : Colors.blue,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}