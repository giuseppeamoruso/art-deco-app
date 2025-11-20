import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'stylist_selection_page_final.dart';

class DateTimeSelectionPage extends StatefulWidget {
  final String section;
  final List<Map<String, dynamic>> selectedServices;
  final Duration totalDuration;
  final double totalPrice;

  const DateTimeSelectionPage({
    super.key,
    required this.section,
    required this.selectedServices,
    required this.totalDuration,
    required this.totalPrice,
  });

  @override
  State<DateTimeSelectionPage> createState() => _DateTimeSelectionPageState();
}

class _DateTimeSelectionPageState extends State<DateTimeSelectionPage> {
  bool _isLoading = true;
  DateTime _selectedDate = DateTime.now();
  String? _selectedTimeSlot;
  List<String> _availableTimeSlots = [];

  @override
  void initState() {
    super.initState();
    _initializeSelectedDate();
    _loadAvailableTimeSlots();
  }

  void _initializeSelectedDate() {
    // Trova il primo mese con giorni disponibili
    final now = DateTime.now();

    for (int i = 0; i < 12; i++) {
      final monthToCheck = DateTime(now.year, now.month + i);
      final firstAvailableDay = _getFirstAvailableDayOfMonth(monthToCheck);

      if (firstAvailableDay != null) {
        _selectedDate = firstAvailableDay;
        print('✅ Data iniziale selezionata: ${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}');
        return;
      }
    }

    // Fallback se non trova niente (non dovrebbe mai succedere)
    _selectedDate = DateTime.now().add(const Duration(days: 1));
  }

  Future<void> _loadAvailableTimeSlots() async {
    setState(() => _isLoading = true);

    try {
      final availableSlots = await _checkAvailability(_selectedDate);

      setState(() {
        _availableTimeSlots = availableSlots;
        _selectedTimeSlot = null; // Reset selezione orario quando cambia data
        _isLoading = false;
      });

      print('✅ Slot disponibili per ${_formatDate(_selectedDate)}: ${_availableTimeSlots.length}');

    } catch (e) {
      print('❌ Errore caricamento slot: $e');
      setState(() => _isLoading = false);

      if (mounted) {
        _showErrorMessage('Errore nel caricamento degli orari disponibili');
      }
    }
  }

  // NUOVO: Controlla se c'è un'eccezione per una data specifica
  Future<Map<String, dynamic>?> _getEccezionePerData(DateTime data) async {
    final supabase = Supabase.instance.client;
    final dateString = '${data.year}-${data.month.toString().padLeft(2, '0')}-${data.day.toString().padLeft(2, '0')}';

    try {
      final response = await supabase
          .from('orari_eccezioni')
          .select()
          .eq('data', dateString)
          .maybeSingle();

      return response;
    } catch (e) {
      print('Errore recupero eccezioni: $e');
      return null;
    }
  }

  // NUOVO: Ottieni l'orario standard per un giorno della settimana
  Future<Map<String, dynamic>?> _getOrarioStandard(int giornoSettimana) async {
    final supabase = Supabase.instance.client;

    try {
      final response = await supabase
          .from('orari_settimanali')
          .select()
          .eq('giorno_settimana', giornoSettimana)
          .single();

      return response;
    } catch (e) {
      print('Errore recupero orario standard: $e');
      return null;
    }
  }

  // NUOVO: Genera lista orari basata su apertura/chiusura
  List<String> _generaListaOrari(String? apertura, String? chiusura) {
    if (apertura == null || chiusura == null) return [];

    List<String> orari = [];

    try {
      final apre = _parseTimeString(apertura);
      final chiude = _parseTimeString(chiusura);

      int minutiApertura = apre.hour * 60 + apre.minute;
      int minutiChiusura = chiude.hour * 60 + chiude.minute;

      // Genera slot ogni 15 minuti
      for (int minuti = minutiApertura; minuti < minutiChiusura; minuti += 15) {
        // Controlla se c'è tempo sufficiente per completare i servizi
        final slotStart = DateTime(2000, 1, 1, minuti ~/ 60, minuti % 60);
        final slotEnd = slotStart.add(widget.totalDuration);
        final closing = DateTime(2000, 1, 1, chiude.hour, chiude.minute);

        if (slotEnd.isAfter(closing)) break;

        int ore = minuti ~/ 60;
        int min = minuti % 60;
        orari.add('${ore.toString().padLeft(2, '0')}:${min.toString().padLeft(2, '0')}');
      }
    } catch (e) {
      print('Errore generazione orari: $e');
    }

    return orari;
  }

  TimeOfDay _parseTimeString(String time) {
    final parts = time.split(':');
    return TimeOfDay(
      hour: int.parse(parts[0]),
      minute: int.parse(parts[1]),
    );
  }

  Future<List<String>> _checkAvailability(DateTime date) async {
    final supabase = Supabase.instance.client;
    final sessoId = widget.section == 'uomo' ? 1 : 2;
    final dateString = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

    try {
      // 1. Query per stylist del sesso giusto
      final stylistSessoResponse = await supabase
          .from('STYLIST_SESSO_TAGLIO')
          .select('stylist_id')
          .eq('sesso_id', sessoId);

      List<int> stylistIds = stylistSessoResponse
          .map<int>((s) => s['stylist_id'] as int)
          .toList();

      if (stylistIds.isEmpty) return [];

      // 2. Filtra solo stylist non cancellati
      final validStylistsResponse = await supabase
          .from('STYLIST')
          .select('id')
          .inFilter('id', stylistIds)
          .isFilter('deleted_at', null);

      List<int> validStylistIds = validStylistsResponse
          .map<int>((s) => s['id'] as int)
          .toList();

      if (validStylistIds.isEmpty) return [];

      // 3. *** NUOVO: Controlla orari e eccezioni ***
      final eccezione = await _getEccezionePerData(date);

      if (eccezione != null) {
        if (eccezione['tipo'] == 'chiuso') {
          print('❌ Giorno chiuso per eccezione: $dateString');
          return []; // Nessun orario disponibile
        }

        // Genera orari basati sull'eccezione
        List<String> orariGiornata = [];

        if (eccezione['tipo'] == 'solo_mattina' || eccezione['tipo'] == 'orario_ridotto') {
          if (eccezione['orario_apertura_mattina'] != null) {
            orariGiornata.addAll(_generaListaOrari(
              eccezione['orario_apertura_mattina'],
              eccezione['orario_chiusura_mattina'],
            ));
          }
        }

        if (eccezione['tipo'] == 'solo_pomeriggio' || eccezione['tipo'] == 'orario_ridotto') {
          if (eccezione['orario_apertura_pomeriggio'] != null) {
            orariGiornata.addAll(_generaListaOrari(
              eccezione['orario_apertura_pomeriggio'],
              eccezione['orario_chiusura_pomeriggio'],
            ));
          }
        }

        print('✅ Orari da eccezione (${eccezione['tipo']}): ${orariGiornata.length} slot');

        // Continua con il controllo appuntamenti e assenze
        return await _filtraOrariDisponibili(
            orariGiornata,
            validStylistIds,
            dateString
        );
      }

      // Altrimenti usa l'orario standard
      final giornoSettimana = date.weekday;
      final orarioStandard = await _getOrarioStandard(giornoSettimana);

      if (orarioStandard == null || orarioStandard['aperto'] == false) {
        print('❌ Giorno chiuso: ${_getWeekdayAbbr(giornoSettimana)}');
        return [];
      }

      // Genera orari con i due turni
      List<String> orariGiornata = [];

      // Turno mattina
      if (orarioStandard['orario_apertura_mattina'] != null) {
        orariGiornata.addAll(_generaListaOrari(
          orarioStandard['orario_apertura_mattina'],
          orarioStandard['orario_chiusura_mattina'],
        ));
      }

      // Turno pomeriggio
      if (orarioStandard['orario_apertura_pomeriggio'] != null) {
        orariGiornata.addAll(_generaListaOrari(
          orarioStandard['orario_apertura_pomeriggio'],
          orarioStandard['orario_chiusura_pomeriggio'],
        ));
      }

      print('✅ Orari standard: ${orariGiornata.length} slot (${_getWeekdayAbbr(giornoSettimana)})');

      // Filtra orari basati su appuntamenti e assenze
      return await _filtraOrariDisponibili(
          orariGiornata,
          validStylistIds,
          dateString
      );

    } catch (e) {
      print('❌ Errore controllo disponibilità: $e');
      return [];
    }
  }

  // NUOVO: Filtra orari controllando appuntamenti e assenze
  Future<List<String>> _filtraOrariDisponibili(
      List<String> orariGiornata,
      List<int> stylistIds,
      String dateString,
      ) async {
    final supabase = Supabase.instance.client;

    // Query appuntamenti
    final appointmentsResponse = await supabase
        .from('APPUNTAMENTI')
        .select('stylist_id, ora_inizio, ora_fine')
        .eq('data', dateString)
        .inFilter('stylist_id', stylistIds);

    // Query assenze
    final assenzeResponse = await supabase
        .from('STYLIST_ASSENZE')
        .select('stylist_id, tipo, data_inizio, data_fine, ora_inizio, ora_fine')
        .eq('stato', 'approvato')
        .inFilter('stylist_id', stylistIds);

    print('🔍 Assenze trovate per data $dateString: ${assenzeResponse.length}');

    // Preprocessa le assenze
    Map<int, List<Map<String, dynamic>>> stylistAssenze = {};
    for (var assenza in assenzeResponse) {
      int stylistId = assenza['stylist_id'];
      if (!stylistAssenze.containsKey(stylistId)) {
        stylistAssenze[stylistId] = [];
      }
      stylistAssenze[stylistId]!.add(assenza);
    }

    // Filtra gli orari
    List<String> availableSlots = [];

    for (int i = 0; i < orariGiornata.length; i++) {
      String slot = orariGiornata[i];

      if (_isSlotAvailableWithAbsences(
        slot,
        appointmentsResponse,
        stylistIds,
        stylistAssenze,
        dateString,
      )) {
        availableSlots.add(slot);
      }

      // Yield control ogni 10 slot per non bloccare UI
      if (i % 10 == 0) {
        await Future.delayed(Duration.zero);
      }
    }

    return availableSlots;
  }

  bool _isSlotAvailableWithAbsences(
      String startTime,
      List<dynamic> appointments,
      List<int> allStylistIds,
      Map<int, List<Map<String, dynamic>>> stylistAssenze,
      String dateString
      ) {
    // Calcola orario fine basato sulla durata totale
    final startDateTime = DateTime.parse('2000-01-01 $startTime:00');
    final endDateTime = startDateTime.add(widget.totalDuration);
    final endTime = '${endDateTime.hour.toString().padLeft(2, '0')}:${endDateTime.minute.toString().padLeft(2, '0')}';

    // Set per tenere traccia di stylist NON disponibili
    Set<int> unavailableStylistIds = {};

    // 1. Controlla stylist occupati con appuntamenti
    for (var appointment in appointments) {
      final appoStart = appointment['ora_inizio'] as String;
      final appoEnd = appointment['ora_fine'] as String;

      if (_timeOverlaps(startTime, endTime, appoStart.substring(0, 5), appoEnd.substring(0, 5))) {
        unavailableStylistIds.add(appointment['stylist_id'] as int);
      }
    }

    // 2. Controlla stylist in assenza
    for (int stylistId in allStylistIds) {
      if (unavailableStylistIds.contains(stylistId)) {
        continue; // Già marcato come non disponibile
      }

      final assenzeStylist = stylistAssenze[stylistId] ?? [];

      for (var assenza in assenzeStylist) {
        if (_isStylistInAssenza(assenza, dateString, startTime, endTime)) {
          unavailableStylistIds.add(stylistId);
          break; // Una volta trovata un'assenza, non serve controllare altre
        }
      }
    }

    // 3. Controlla se almeno uno stylist è disponibile
    int availableStylistCount = allStylistIds.length - unavailableStylistIds.length;
    return availableStylistCount > 0;
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
        String assenzaStart = _formatTimeForComparison(oraInizio);
        String assenzaEnd = _formatTimeForComparison(oraFine);

        return _timeOverlaps(slotStartTime, slotEndTime, assenzaStart, assenzaEnd);
      }
    }

    // Per ferie, malattia, permesso_giorno: stylist non disponibile per l'intera giornata
    if (tipo == 'ferie' || tipo == 'malattia' || tipo == 'permesso_giorno') {
      return true;
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

  Future<void> _selectDate(DateTime date) async {
    if (date.isBefore(DateTime.now().subtract(const Duration(days: 1)))) {
      _showErrorMessage('Non puoi selezionare date passate');
      return;
    }

    // Controlla eccezioni
    final eccezione = await _getEccezionePerData(date);
    if (eccezione != null && eccezione['tipo'] == 'chiuso') {
      _showErrorMessage('Il salone è chiuso in questa data');
      return;
    }

    // Controlla orario standard
    final orarioStandard = await _getOrarioStandard(date.weekday);
    if (orarioStandard != null && orarioStandard['aperto'] == false) {
      _showErrorMessage('Il salone è chiuso il ${_getWeekdayAbbr(date.weekday)}');
      return;
    }

    setState(() {
      _selectedDate = date;
    });
    _loadAvailableTimeSlots();
  }

  void _selectTimeSlot(String timeSlot) {
    setState(() {
      _selectedTimeSlot = timeSlot;
    });
  }

  void _navigateToStylistSelection() {
    if (_selectedTimeSlot == null) {
      _showErrorMessage('Seleziona un orario per continuare');
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => StylistSelectionPageFinal(
          section: widget.section,
          selectedServices: widget.selectedServices,
          totalDuration: widget.totalDuration,
          totalPrice: widget.totalPrice,
          selectedDate: _selectedDate,
          selectedTimeSlot: _selectedTimeSlot!,
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
        title: const Text(
          'Seleziona Data e Ora',
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
        child: Column(
          children: [
            // Riepilogo servizi selezionati
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
                  Text(
                    'Riepilogo servizi',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${widget.selectedServices.length} servizio/i - Durata: ${_formatDuration(widget.totalDuration)} - €${widget.totalPrice.toStringAsFixed(2)}',
                    style: TextStyle(
                      color: Colors.grey[300],
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),

            // Calendario
            Expanded(
              child: _isLoading
                  ? const Center(
                child: CircularProgressIndicator(color: Colors.white),
              )
                  : SingleChildScrollView(
                child: Column(
                  children: [
                    // Selezione data (calendario semplice)
                    _buildDateSelector(),

                    const SizedBox(height: 20),

                    // Selezione orario
                    _buildTimeSlotSelector(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _selectedTimeSlot != null
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
              onPressed: _navigateToStylistSelection,
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
                'Scegli Stylist - ${_formatDate(_selectedDate)} alle $_selectedTimeSlot',
                style: const TextStyle(
                  fontSize: 14,
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

  Widget _buildDateSelector() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Seleziona la data',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          // Selettore mese/anno
          Container(
            height: 40,
            margin: const EdgeInsets.only(bottom: 12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: List.generate(12, (index) {
                  final monthDate = DateTime(DateTime.now().year, DateTime.now().month + index);
                  final isCurrentMonth = monthDate.month == _selectedDate.month &&
                      monthDate.year == _selectedDate.year;

                  // Controlla se il mese ha giorni disponibili
                  final hasAvailableDays = _getFirstAvailableDayOfMonth(monthDate) != null;

                  return Container(
                    margin: const EdgeInsets.only(right: 8),
                    child: InkWell(
                      onTap: hasAvailableDays ? () => _selectMonth(monthDate) : null,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        constraints: const BoxConstraints(
                          minWidth: 50,
                          maxWidth: 70,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        decoration: BoxDecoration(
                          color: isCurrentMonth
                              ? (widget.section == 'donna' ? Colors.pink : Colors.blue)
                              : hasAvailableDays
                              ? const Color(0xFF2d2d2d)
                              : Colors.grey.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _getMonthAbbrShort(monthDate.month),
                              style: TextStyle(
                                color: hasAvailableDays
                                    ? (isCurrentMonth ? Colors.white : Colors.grey[300])
                                    : Colors.grey,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 1),
                            Text(
                              monthDate.year.toString().substring(2),
                              style: TextStyle(
                                color: hasAvailableDays
                                    ? (isCurrentMonth ? Colors.white70 : Colors.grey[400])
                                    : Colors.grey,
                                fontSize: 8,
                              ),
                              maxLines: 1,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),

          // Giorni del mese selezionato
          SizedBox(
            height: 80,
            child: _buildDaysForMonth(_selectedDate),
          ),
        ],
      ),
    );
  }

  Widget _buildDaysForMonth(DateTime monthDate) {
    final firstDay = DateTime(monthDate.year, monthDate.month, 1);
    final lastDay = DateTime(monthDate.year, monthDate.month + 1, 0);
    final today = DateTime.now();

    List<DateTime> daysInMonth = [];
    for (int day = 1; day <= lastDay.day; day++) {
      final dayDate = DateTime(monthDate.year, monthDate.month, day);
      if ((dayDate.isAfter(today) || dayDate.isAtSameMomentAs(DateTime(today.year, today.month, today.day)))
          && dayDate.weekday != 1 && dayDate.weekday != 7) { // Escludi lunedì e domenica
        daysInMonth.add(dayDate);
      }
    }

    if (daysInMonth.isEmpty) {
      return Center(
        child: Text(
          'Nessun giorno disponibile in questo mese',
          style: TextStyle(
            color: Colors.grey[400],
            fontSize: 14,
          ),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: daysInMonth.map((date) {
          final isSelected = _selectedDate.day == date.day &&
              _selectedDate.month == date.month &&
              _selectedDate.year == date.year;
          final isToday = date.day == DateTime.now().day &&
              date.month == DateTime.now().month &&
              date.year == DateTime.now().year;

          return Container(
            margin: const EdgeInsets.only(right: 10),
            child: InkWell(
              onTap: () => _selectDate(date),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 65,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? (widget.section == 'donna' ? Colors.pink : Colors.blue)
                      : const Color(0xFF2d2d2d),
                  borderRadius: BorderRadius.circular(12),
                  border: isToday
                      ? Border.all(color: Colors.white, width: 1)
                      : null,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _getMonthAbbrShort(date.month),
                      style: TextStyle(
                        color: isSelected
                            ? Colors.white70
                            : Colors.grey[400],
                        fontSize: 9,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      date.day.toString(),
                      style: TextStyle(
                        color: isSelected
                            ? Colors.white
                            : Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _getWeekdayAbbr(date.weekday),
                      style: TextStyle(
                        color: isSelected
                            ? Colors.white70
                            : Colors.grey[300],
                        fontSize: 9,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (isToday) ...[
                      const SizedBox(height: 2),
                      Container(
                        width: 3,
                        height: 3,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  void _selectMonth(DateTime monthDate) {
    setState(() {
      final firstAvailableDay = _getFirstAvailableDayOfMonth(monthDate);
      if (firstAvailableDay != null) {
        _selectedDate = firstAvailableDay;
        _loadAvailableTimeSlots();
      }
    });
  }

  DateTime? _getFirstAvailableDayOfMonth(DateTime monthDate) {
    final today = DateTime.now();
    final lastDay = DateTime(monthDate.year, monthDate.month + 1, 0);

    for (int day = 1; day <= lastDay.day; day++) {
      final dayDate = DateTime(monthDate.year, monthDate.month, day);

      // Solo date future
      if (dayDate.isBefore(DateTime(today.year, today.month, today.day))) {
        continue;
      }

      // Salta lunedì (1) e domenica (7) - giorni fissi chiusi
      if (dayDate.weekday == 1 || dayDate.weekday == 7) {
        continue;
      }

      return dayDate;
    }
    return null;
  }

  String _getMonthName(int month) {
    const months = [
      '', 'Gennaio', 'Febbraio', 'Marzo', 'Aprile', 'Maggio', 'Giugno',
      'Luglio', 'Agosto', 'Settembre', 'Ottobre', 'Novembre', 'Dicembre'
    ];
    return months[month];
  }

  String _getMonthAbbr(int month) {
    const months = [
      '', 'GEN', 'FEB', 'MAR', 'APR', 'MAG', 'GIU',
      'LUG', 'AGO', 'SET', 'OTT', 'NOV', 'DIC'
    ];
    return months[month];
  }

  String _getMonthAbbrShort(int month) {
    const months = [
      '', 'GEN', 'FEB', 'MAR', 'APR', 'MAG', 'GIU',
      'LUG', 'AGO', 'SET', 'OTT', 'NOV', 'DIC'
    ];
    return months[month];
  }

  String _getWeekdayAbbr(int weekday) {
    const weekdays = [
      '', 'LUN', 'MAR', 'MER', 'GIO', 'VEN', 'SAB', 'DOM'
    ];
    return weekdays[weekday];
  }

  Widget _buildTimeSlotSelector() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Orari disponibili - ${_formatDate(_selectedDate)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          _availableTimeSlots.isEmpty
              ? Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF2d2d2d),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: Text(
                'Nessun orario disponibile per questa data',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          )
              : GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              childAspectRatio: 2,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: _availableTimeSlots.length,
            itemBuilder: (context, index) {
              final timeSlot = _availableTimeSlots[index];
              final isSelected = _selectedTimeSlot == timeSlot;

              return InkWell(
                onTap: () => _selectTimeSlot(timeSlot),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  decoration: BoxDecoration(
                    color: isSelected
                        ? (widget.section == 'donna' ? Colors.pink : Colors.blue)
                        : const Color(0xFF2d2d2d),
                    borderRadius: BorderRadius.circular(8),
                    border: isSelected
                        ? Border.all(
                      color: widget.section == 'donna' ? Colors.pink : Colors.blue,
                      width: 2,
                    )
                        : null,
                  ),
                  child: Center(
                    child: Text(
                      timeSlot,
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.grey[300],
                        fontSize: 14,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}