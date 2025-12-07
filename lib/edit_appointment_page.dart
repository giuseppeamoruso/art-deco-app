import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'appointment_notification_service.dart';
import 'onesignal_push_service.dart';

class EditAppointmentPage extends StatefulWidget {
  final Map<String, dynamic> appointment;

  const EditAppointmentPage({
    super.key,
    required this.appointment,
  });

  @override
  State<EditAppointmentPage> createState() => _EditAppointmentPageState();
}

class _EditAppointmentPageState extends State<EditAppointmentPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = false;
  bool _hasChanges = false;

  // Dati originali
  late DateTime _originalDate;
  late String _originalTimeSlot;
  late Map<String, dynamic> _originalStylist;
  late List<Map<String, dynamic>> _originalServices;
  late Duration _originalDuration;
  late double _originalPrice;

  // Dati modificati
  late DateTime _selectedDate;
  String? _selectedTimeSlot;
  Map<String, dynamic>? _selectedStylist;
  List<Map<String, dynamic>> _selectedServices = [];
  Duration _totalDuration = Duration.zero;
  double _totalPrice = 0.0;

  // Liste per UI
  List<String> _availableTimeSlots = [];
  List<Map<String, dynamic>> _availableStylists = [];
  List<Map<String, dynamic>> _availableServices = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _initializeData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _initializeData() {
    // Inizializza dati originali
    _originalDate = DateTime.parse(widget.appointment['data']);
    _originalTimeSlot = widget.appointment['ora_inizio'].substring(0, 5);
    _originalStylist = widget.appointment['STYLIST'];
    _originalServices = List<Map<String, dynamic>>.from(
        widget.appointment['APPUNTAMENTI_SERVIZI']?.map((s) => s['SERVIZI']) ?? []
    );

    // Calcola durata e prezzo originali
    _calculateOriginalTotals();

    // Inizializza dati selezionati con quelli originali
    _selectedDate = _originalDate;
    _selectedTimeSlot = _originalTimeSlot;
    _selectedStylist = _originalStylist;
    _selectedServices = List.from(_originalServices);
    _totalDuration = _originalDuration;
    _totalPrice = _originalPrice;

    // Carica dati iniziali
    _loadAvailableServices();
  }

  void _calculateOriginalTotals() {
    _originalDuration = Duration.zero;
    _originalPrice = 0.0;

    for (var service in _originalServices) {
      // Calcola durata
      if (service['durata'] != null) {
        final parts = service['durata'].split(':');
        if (parts.length >= 2) {
          final hours = int.tryParse(parts[0]) ?? 0;
          final minutes = int.tryParse(parts[1]) ?? 0;
          _originalDuration += Duration(hours: hours, minutes: minutes);
        }
      }

      // Calcola prezzo
      _originalPrice += (service['prezzo'] ?? 0).toDouble();
    }
  }

  Future<void> _loadAvailableServices() async {
    setState(() => _isLoading = true);

    try {
      final supabase = Supabase.instance.client;
      final section = _getSectionFromStylist(_originalStylist);
      final sessoId = section == 'uomo' ? 1 : 2;

      final response = await supabase
          .from('SERVIZI')
          .select('*')
          .eq('sesso_id', sessoId)
          .isFilter('deleted_at', null)
          .order('descrizione');

      setState(() {
        _availableServices = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });

      // Carica slot orari per la data attuale
      _loadAvailableTimeSlots();

    } catch (e) {
      print('Errore caricamento servizi: $e');
      setState(() => _isLoading = false);
      _showErrorMessage('Errore nel caricamento dei servizi');
    }
  }

  String _getSectionFromStylist(Map<String, dynamic> stylist) {
    // Logica per determinare la sezione dallo stylist
    // Puoi implementare una query per ottenere questa info dal DB
    return 'donna'; // Placeholder - implementa la logica corretta
  }

  Future<void> _loadAvailableTimeSlots() async {
    try {
      final availableSlots = await _checkAvailability(_selectedDate);
      setState(() {
        _availableTimeSlots = availableSlots;

        // Se l'orario selezionato non è più disponibile, resettalo
        if (!_availableTimeSlots.contains(_selectedTimeSlot)) {
          _selectedTimeSlot = null;
          _selectedStylist = null;
        }
      });

      // Se c'è un orario selezionato, carica gli stylist disponibili
      if (_selectedTimeSlot != null) {
        _loadAvailableStylists();
      }

    } catch (e) {
      print('Errore caricamento slot: $e');
      _showErrorMessage('Errore nel caricamento degli orari');
    }
  }

  Future<List<String>> _checkAvailability(DateTime date) async {
    final supabase = Supabase.instance.client;
    final section = _getSectionFromStylist(_originalStylist);
    final sessoId = section == 'uomo' ? 1 : 2;
    final dateString = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

    try {
      // Ottieni stylist del sesso giusto
      final stylistSessoResponse = await supabase
          .from('STYLIST_SESSO_TAGLIO')
          .select('stylist_id')
          .eq('sesso_id', sessoId);

      List<int> stylistIds = stylistSessoResponse
          .map<int>((s) => s['stylist_id'] as int)
          .toList();

      if (stylistIds.isEmpty) return [];

      // Filtra stylist validi
      final validStylistsResponse = await supabase
          .from('STYLIST')
          .select('id')
          .inFilter('id', stylistIds)
          .isFilter('deleted_at', null);

      List<int> validStylistIds = validStylistsResponse
          .map<int>((s) => s['id'] as int)
          .toList();

      if (validStylistIds.isEmpty) return [];

      // Ottieni appuntamenti esistenti (escludendo quello corrente)
      final appointmentsResponse = await supabase
          .from('APPUNTAMENTI')
          .select('stylist_id, ora_inizio, ora_fine')
          .eq('data', dateString)
          .neq('id', widget.appointment['id']) // Escludi l'appuntamento corrente
          .inFilter('stylist_id', validStylistIds);

      return _calculateAvailabilityInBackground(validStylistIds, appointmentsResponse);

    } catch (e) {
      print('Errore controllo disponibilità: $e');
      return [];
    }
  }

  List<String> _calculateAvailabilityInBackground(
      List<int> stylistIds,
      List<dynamic> appointments
      ) {
    List<String> allSlots = _generateAllTimeSlots();
    List<String> availableSlots = [];

    for (String slot in allSlots) {
      if (_isSlotAvailableInMemory(slot, appointments, stylistIds)) {
        availableSlots.add(slot);
      }
    }

    return availableSlots;
  }

  bool _isSlotAvailableInMemory(
      String startTime,
      List<dynamic> appointments,
      List<int> allStylistIds
      ) {
    final startDateTime = DateTime.parse('2000-01-01 $startTime:00');
    final endDateTime = startDateTime.add(_totalDuration);
    final endTime = '${endDateTime.hour.toString().padLeft(2, '0')}:${endDateTime.minute.toString().padLeft(2, '0')}';

    Set<int> busyStylistIds = {};

    for (var appointment in appointments) {
      final appoStart = appointment['ora_inizio'] as String;
      final appoEnd = appointment['ora_fine'] as String;

      if (_timeOverlaps(startTime, endTime, appoStart.substring(0, 5), appoEnd.substring(0, 5))) {
        busyStylistIds.add(appointment['stylist_id'] as int);
      }
    }

    int availableStylistCount = allStylistIds.length - busyStylistIds.length;
    return availableStylistCount > 0;
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

  List<String> _generateAllTimeSlots() {
    List<String> slots = [];
    DateTime current = DateTime(2000, 1, 1, 8, 30); // 8:30
    final closing = DateTime(2000, 1, 1, 20, 0); // 20:00

    while (current.isBefore(closing)) {
      final serviceEndTime = current.add(_totalDuration);
      if (serviceEndTime.isAfter(closing)) break;

      final timeString = '${current.hour.toString().padLeft(2, '0')}:${current.minute.toString().padLeft(2, '0')}';
      slots.add(timeString);

      current = current.add(const Duration(minutes: 15));
    }

    return slots;
  }

  Future<void> _loadAvailableStylists() async {
    if (_selectedTimeSlot == null) return;

    try {
      final supabase = Supabase.instance.client;
      final section = _getSectionFromStylist(_originalStylist);
      final sessoId = section == 'uomo' ? 1 : 2;
      final dateString = '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';

      // Calcola orario fine
      final startDateTime = DateTime.parse('$dateString $_selectedTimeSlot:00');
      final endDateTime = startDateTime.add(_totalDuration);
      final endTime = '${endDateTime.hour.toString().padLeft(2, '0')}:${endDateTime.minute.toString().padLeft(2, '0')}';

      // Ottieni tutti gli stylist del sesso giusto
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

      // Ottieni appuntamenti che si sovrappongono (escludendo quello corrente)
      final appointmentsResponse = await supabase
          .from('APPUNTAMENTI')
          .select('stylist_id, ora_inizio, ora_fine')
          .eq('data', dateString)
          .neq('id', widget.appointment['id']);

      // Trova stylist occupati
      Set<int> busyStylistIds = {};

      for (var appointment in appointmentsResponse) {
        final appoStart = appointment['ora_inizio'] as String;
        final appoEnd = appointment['ora_fine'] as String;

        if (_timeOverlaps(_selectedTimeSlot!, endTime, appoStart, appoEnd)) {
          busyStylistIds.add(appointment['stylist_id'] as int);
        }
      }

      // Filtra stylist disponibili
      List<Map<String, dynamic>> availableStylists = allStylists
          .where((stylist) => !busyStylistIds.contains(stylist['id']))
          .toList();

      setState(() {
        _availableStylists = availableStylists;

        // Se lo stylist attuale non è disponibile, resettalo
        if (!_availableStylists.any((s) => s['id'] == _selectedStylist?['id'])) {
          _selectedStylist = null;
        }
      });

    } catch (e) {
      print('Errore caricamento stylist: $e');
      _showErrorMessage('Errore nel caricamento degli stylist');
    }
  }

  void _onDateChanged(DateTime date) {
    setState(() {
      _selectedDate = date;
      _selectedTimeSlot = null;
      _selectedStylist = null;
      _hasChanges = true;
    });
    _loadAvailableTimeSlots();
  }

  void _onTimeSlotChanged(String timeSlot) {
    setState(() {
      _selectedTimeSlot = timeSlot;
      _selectedStylist = null;
      _hasChanges = true;
    });
    _loadAvailableStylists();
  }

  void _onStylistChanged(Map<String, dynamic> stylist) {
    setState(() {
      _selectedStylist = stylist;
      _hasChanges = true;
    });
  }

  void _onServiceToggled(Map<String, dynamic> service, bool isSelected) {
    setState(() {
      if (isSelected) {
        _selectedServices.add(service);
      } else {
        _selectedServices.removeWhere((s) => s['id'] == service['id']);
      }
      _calculateTotals();
      _hasChanges = true;
    });

    // Ricarica disponibilità se la durata è cambiata
    _loadAvailableTimeSlots();
  }

  void _calculateTotals() {
    _totalDuration = Duration.zero;
    _totalPrice = 0.0;

    for (var service in _selectedServices) {
      // Calcola durata
      if (service['durata'] != null) {
        final parts = service['durata'].split(':');
        if (parts.length >= 2) {
          final hours = int.tryParse(parts[0]) ?? 0;
          final minutes = int.tryParse(parts[1]) ?? 0;
          _totalDuration += Duration(hours: hours, minutes: minutes);
        }
      }

      // Calcola prezzo
      _totalPrice += (service['prezzo'] ?? 0).toDouble();
    }
  }

  Future<void> _saveChanges() async {
    if (!_validateChanges()) return;

    setState(() => _isLoading = true);

    try {
      final supabase = Supabase.instance.client;
      print("ciao");
      // Calcola orario fine
      final startDateTime = DateTime.parse('${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')} $_selectedTimeSlot:00');
      final endDateTime = startDateTime.add(_totalDuration);
      final endTime = '${endDateTime.hour.toString().padLeft(2, '0')}:${endDateTime.minute.toString().padLeft(2, '0')}:00';

      // Aggiorna appuntamento
      await supabase
          .from('APPUNTAMENTI')
          .update({
        'data': '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}',
        'ora_inizio': '$_selectedTimeSlot:00',
        'ora_fine': endTime,
        'durata_totale': '${_totalDuration.inHours.toString().padLeft(2, '0')}:${(_totalDuration.inMinutes % 60).toString().padLeft(2, '0')}:00',
        'prezzo_totale': _totalPrice,
        'stylist_id': _selectedStylist!['id'],
        'updated_at': DateTime.now().toIso8601String(),
      })
          .eq('id', widget.appointment['id']);

      // Elimina servizi vecchi
      await supabase
          .from('APPUNTAMENTI_SERVIZI')
          .delete()
          .eq('appuntamento_id', widget.appointment['id']);

      // Inserisci nuovi servizi
      for (var service in _selectedServices) {
        await supabase
            .from('APPUNTAMENTI_SERVIZI')
            .insert({
          'appuntamento_id': widget.appointment['id'],
          'servizio_id': service['id'],
          'quantita': 1,
        });
      }

      print('✅ Appuntamento aggiornato con ID: ${widget.appointment['id']}');

      // 🔔 GESTIONE NOTIFICHE
      try {
        // Cancella la vecchia notifica locale
        await AppointmentNotificationService.cancelAppointmentReminder(
            widget.appointment['id']
        );
        print('🗑️ Vecchia notifica locale cancellata');

        // Ottieni dati utente (Firebase UID + nome)
        String? firebaseUid;
        String clientName = 'Cliente';

        try {
          final userRecord = await supabase
              .from('USERS')
              .select('uid, nome, cognome')
              .eq('id', widget.appointment['user_id'])
              .single();

          firebaseUid = userRecord['uid'];
          clientName = '${userRecord['nome']} ${userRecord['cognome']}';
          print('👤 Dati utente recuperati: $clientName (UID: $firebaseUid)');
        } catch (e) {
          print('⚠️ Errore recupero dati utente: $e');
        }

        // Programma la nuova notifica locale (reminder giorno prima)
        await AppointmentNotificationService.scheduleAppointmentReminder(
          appointmentId: widget.appointment['id'],
          clientName: clientName,
          stylistName: _selectedStylist!['descrizione'],
          appointmentDate: _selectedDate,
          appointmentTime: _selectedTimeSlot ?? widget.appointment['ora_inizio'].substring(0, 5),
          services: _selectedServices
              .map((s) => s['descrizione'] as String)
              .toList(),
        );
        print('🔔 Nuova notifica locale programmata');

        // 📨 NOTIFICA PUSH IMMEDIATA se data/ora sono cambiate
        final originalDate = DateTime.parse(widget.appointment['data']);
        final originalTime = widget.appointment['ora_inizio'].substring(0, 5);
        final newTime = _selectedTimeSlot ?? originalTime;

        if ((originalDate != _selectedDate || originalTime != _selectedTimeSlot) && firebaseUid != null) {
          print('📤 Invio notifica push di modifica...');

          // Invia notifica push tramite OneSignal
          final pushSent = await OneSignalPushService.sendAppointmentModificationNotification(
            firebaseUid: firebaseUid,
            clientName: clientName,
            oldDate: originalDate,
            newDate: _selectedDate,
            oldTime: originalTime,
            newTime: newTime,
            appointmentId: widget.appointment['id'],
          );

          if (pushSent) {
            print('✅ Notifica push modifica inviata con successo al cliente');
          } else {
            print('⚠️ Invio notifica push fallito (controllare log OneSignal)');
          }
        } else {
          if (firebaseUid == null) {
            print('⚠️ Firebase UID non trovato, notifica push non inviata');
          } else {
            print('ℹ️ Data/ora non cambiate, notifica push non necessaria');
          }
        }

      } catch (notifError) {
        print('⚠️ Errore gestione notifiche (non critico): $notifError');
      }

      setState(() => _isLoading = false);

      _showSuccessMessage('Appuntamento modificato con successo');
      Navigator.of(context).pop(true); // Torna indietro con successo

    } catch (e) {
      print('❌ Errore salvataggio: $e');
      setState(() => _isLoading = false);
      _showErrorMessage('Errore durante il salvataggio');
    }
  }

  bool _validateChanges() {
    if (_selectedServices.isEmpty) {
      _showErrorMessage('Seleziona almeno un servizio');
      return false;
    }

    if (_selectedTimeSlot == null) {
      _showErrorMessage('Seleziona un orario');
      return false;
    }

    if (_selectedStylist == null) {
      _showErrorMessage('Seleziona uno stylist');
      return false;
    }

    return true;
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

  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1a1a1a),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2d2d2d),
        elevation: 0,
        title: const Text(
          'Modifica Appuntamento',
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
        actions: [
          if (_hasChanges)
            TextButton(
              onPressed: _saveChanges,
              child: _isLoading
                  ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
                  : const Text(
                'SALVA',
                style: TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.blue,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.grey[400],
          tabs: const [
            Tab(text: 'Servizi'),
            Tab(text: 'Data/Ora'),
            Tab(text: 'Stylist'),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Riepilogo modifiche
            if (_hasChanges)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  border: Border(
                    bottom: BorderSide(color: Colors.orange.withOpacity(0.3)),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.edit, color: Colors.orange, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Hai delle modifiche non salvate',
                        style: TextStyle(
                          color: Colors.orange,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: _saveChanges,
                      child: const Text('SALVA ORA'),
                    ),
                  ],
                ),
              ),

            // Contenuto tabs
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildServicesTab(),
                  _buildDateTimeTab(),
                  _buildStylistTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServicesTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Riepilogo corrente
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF2d2d2d),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Servizi Selezionati',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                if (_selectedServices.isEmpty)
                  Text(
                    'Nessun servizio selezionato',
                    style: TextStyle(color: Colors.grey[400]),
                  )
                else
                  Column(
                    children: [
                      ...(_selectedServices.map((service) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                service['descrizione'],
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                            Text(
                              '€${service['prezzo']}',
                              style: const TextStyle(color: Colors.green),
                            ),
                          ],
                        ),
                      ))).toList(),
                      const Divider(color: Colors.grey),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Durata: ${_formatDuration(_totalDuration)}',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'Totale: €${_totalPrice.toStringAsFixed(2)}',
                            style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ],
                  ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Lista servizi disponibili
          const Text(
            'Servizi Disponibili',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),

          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _availableServices.length,
              itemBuilder: (context, index) {
                final service = _availableServices[index];
                final isSelected = _selectedServices.any((s) => s['id'] == service['id']);

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2d2d2d),
                    borderRadius: BorderRadius.circular(8),
                    border: isSelected
                        ? Border.all(color: Colors.blue, width: 2)
                        : null,
                  ),
                  child: CheckboxListTile(
                    value: isSelected,
                    onChanged: (value) => _onServiceToggled(service, value ?? false),
                    title: Text(
                      service['descrizione'],
                      style: const TextStyle(color: Colors.white),
                    ),
                    subtitle: Text(
                      '€${service['prezzo']} - ${service['durata']}',
                      style: TextStyle(color: Colors.grey[400]),
                    ),
                    activeColor: Colors.blue,
                    checkColor: Colors.white,
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildDateTimeTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Selezione data
          const Text(
            'Seleziona Data',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF2d2d2d),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_today, color: Colors.blue),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Data selezionata',
                        style: TextStyle(color: Colors.grey),
                      ),
                      Text(
                        _formatDate(_selectedDate),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _selectedDate,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                      builder: (context, child) {
                        return Theme(
                          data: Theme.of(context).copyWith(
                            colorScheme: const ColorScheme.dark(
                              primary: Colors.blue,
                              onPrimary: Colors.white,
                              surface: Color(0xFF2d2d2d),
                              onSurface: Colors.white,
                            ),
                          ),
                          child: child!,
                        );
                      },
                    );
                    if (date != null) {
                      _onDateChanged(date);
                    }
                  },
                  child: const Text('Cambia'),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Selezione orario
          const Text(
            'Orari Disponibili',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),

          if (_availableTimeSlots.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF2d2d2d),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Nessun orario disponibile per questa data',
                style: TextStyle(color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            )
          else
            GridView.builder(
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
                  onTap: () => _onTimeSlotChanged(timeSlot),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Colors.blue
                          : const Color(0xFF2d2d2d),
                      borderRadius: BorderRadius.circular(8),
                      border: isSelected
                          ? Border.all(color: Colors.blue, width: 2)
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

  Widget _buildStylistTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Stylist Disponibili',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),

          if (_selectedTimeSlot == null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF2d2d2d),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Icon(Icons.schedule, color: Colors.grey[400], size: 48),
                  const SizedBox(height: 12),
                  Text(
                    'Seleziona prima data e orario',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 16,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          else if (_availableStylists.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF2d2d2d),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Icon(Icons.person_off, color: Colors.grey[400], size: 48),
                  const SizedBox(height: 12),
                  const Text(
                    'Nessun stylist disponibile',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'per ${_formatDate(_selectedDate)} alle $_selectedTimeSlot',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _availableStylists.length,
              itemBuilder: (context, index) {
                final stylist = _availableStylists[index];
                final isSelected = _selectedStylist?['id'] == stylist['id'];

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Card(
                    color: isSelected
                        ? Colors.blue.withOpacity(0.1)
                        : const Color(0xFF2d2d2d),
                    elevation: isSelected ? 8 : 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: isSelected
                          ? const BorderSide(color: Colors.blue, width: 2)
                          : BorderSide.none,
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => _onStylistChanged(stylist),
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          children: [
                            // Avatar stylist
                            Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(30),
                                border: isSelected
                                    ? Border.all(color: Colors.blue, width: 2)
                                    : null,
                              ),
                              child: const Icon(
                                Icons.person,
                                color: Colors.blue,
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
                                    'Specialista',
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
                                      'Libero alle $_selectedTimeSlot',
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
                                  color: Colors.blue,
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
        ],
      ),
    );
  }
}