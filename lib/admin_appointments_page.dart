import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter/services.dart';

import 'onesignal_push_service.dart';

class AdminAppointmentsPage extends StatefulWidget {
  const AdminAppointmentsPage({super.key});

  @override
  State<AdminAppointmentsPage> createState() => _AdminAppointmentsPageState();
}

class _AdminAppointmentsPageState extends State<AdminAppointmentsPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  DateTime _selectedDate = DateTime.now();
  DateTime _customSelectedDate = DateTime.now();
  List<Map<String, dynamic>> _appointments = [];
  List<Map<String, dynamic>> _filteredAppointments = [];
  List<Map<String, dynamic>> _stylists = [];

  int? _selectedStylistId;
  String _searchQuery = '';
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadStylists();
    _loadAppointments();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadStylists() async {
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('STYLIST')
          .select('id, descrizione')
          .isFilter('deleted_at', null)
          .order('descrizione');

      setState(() {
        _stylists = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      print('Errore caricamento stylist: $e');
      _showErrorMessage('Errore nel caricamento degli stylist');
    }
  }

  Future<void> _loadAppointments() async {
    setState(() => _isLoading = true);

    try {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('APPUNTAMENTI')
          .select('''
            id,
            data,
            ora_inizio,
            ora_fine,
            durata_totale,
            prezzo_totale,
            note,
            stylist_id,
            user_id,
            STYLIST!inner(id, descrizione),
            USERS!inner(id, nome, cognome, telefono, email),
            APPUNTAMENTI_SERVIZI(
              SERVIZI(descrizione, prezzo)
            ),
            PAGAMENTI(metodo_pagamento, stato)
          ''')
          .order('data', ascending: true)
          .order('ora_inizio', ascending: true);

      setState(() {
        _appointments = List<Map<String, dynamic>>.from(response);
        _applyFilters();
        _isLoading = false;
      });

      print('Appuntamenti caricati: ${_appointments.length}');
    } catch (e) {
      print('Errore caricamento appuntamenti: $e');
      setState(() => _isLoading = false);
      _showErrorMessage('Errore nel caricamento degli appuntamenti');
    }
  }

  void _applyFilters() {
    List<Map<String, dynamic>> filtered = List.from(_appointments);

    final currentTabIndex = _tabController.index;
    if (currentTabIndex == 0) {
      final todayString = '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';
      filtered = filtered.where((app) => app['data'] == todayString).toList();
    } else if (currentTabIndex == 1) {
      final customDateString = '${_customSelectedDate.year}-${_customSelectedDate.month.toString().padLeft(2, '0')}-${_customSelectedDate.day.toString().padLeft(2, '0')}';
      filtered = filtered.where((app) => app['data'] == customDateString).toList();
    }

    if (_selectedStylistId != null) {
      filtered = filtered.where((app) => app['stylist_id'] == _selectedStylistId).toList();
    }

    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((app) {
        final clientName = '${app['USERS']['nome']} ${app['USERS']['cognome']}'.toLowerCase();
        final stylistName = app['STYLIST']['descrizione'].toString().toLowerCase();
        final query = _searchQuery.toLowerCase();

        return clientName.contains(query) ||
            stylistName.contains(query) ||
            (app['USERS']['telefono']?.toString().contains(query) ?? false);
      }).toList();
    }

    setState(() {
      _filteredAppointments = filtered;
    });
  }

  void _onDateChanged(DateTime date) {
    setState(() {
      _selectedDate = date;
    });
    _applyFilters();
  }

  void _onCustomDateChanged(DateTime date) {
    setState(() {
      _customSelectedDate = date;
    });
    _applyFilters();
  }

  Future<void> _showPdfOptionsDialog() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2d2d2d),
        title: const Text('Genera PDF', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildPdfOption('PDF Giornaliero', 'Appuntamenti della data selezionata', Icons.today, () => _generatePdf('daily')),
            const SizedBox(height: 12),
            _buildPdfOption('PDF Settimanale', 'Dal lunedì alla domenica', Icons.view_week, () => _generatePdf('weekly')),
            const SizedBox(height: 12),
            _buildPdfOption('PDF Mensile', 'Tutto il mese corrente', Icons.calendar_month, () => _generatePdf('monthly')),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annulla', style: TextStyle(color: Colors.white70)),
          ),
        ],
      ),
    );
  }

  Widget _buildPdfOption(String title, String subtitle, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: () {
        Navigator.of(context).pop();
        onTap();
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF1a1a1a),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[600]!),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.blue, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  Text(subtitle, style: TextStyle(color: Colors.grey[400], fontSize: 12)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: Colors.grey[400], size: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _generatePdf(String period) async {
    try {
      _showLoadingDialog('Generazione PDF in corso...');

      List<Map<String, dynamic>> pdfAppointments;
      String title;
      final currentDate = _tabController.index == 0 ? _selectedDate : _customSelectedDate;

      switch (period) {
        case 'daily':
          pdfAppointments = await _getAppointmentsForDate(currentDate);
          title = 'Appuntamenti ${_formatDate(currentDate.toString().split(' ')[0])}';
          break;
        case 'weekly':
          final monday = _getMonday(currentDate);
          final sunday = monday.add(const Duration(days: 6));
          pdfAppointments = await _getAppointmentsForRange(monday, sunday);
          title = 'Appuntamenti Settimanali ${_formatDate(monday.toString().split(' ')[0])} - ${_formatDate(sunday.toString().split(' ')[0])}';
          break;
        case 'monthly':
          final firstDay = DateTime(currentDate.year, currentDate.month, 1);
          final lastDay = DateTime(currentDate.year, currentDate.month + 1, 0);
          pdfAppointments = await _getAppointmentsForRange(firstDay, lastDay);
          title = 'Appuntamenti ${_getMonthName(currentDate.month)} ${currentDate.year}';
          break;
        default:
          pdfAppointments = _filteredAppointments;
          title = 'Appuntamenti';
      }

      pdfAppointments.sort((a, b) {
        int dateCompare = a['data'].compareTo(b['data']);
        if (dateCompare != 0) return dateCompare;
        int timeCompare = a['ora_inizio'].compareTo(b['ora_inizio']);
        if (timeCompare != 0) return timeCompare;
        return a['STYLIST']['descrizione'].compareTo(b['STYLIST']['descrizione']);
      });

      final pdf = await _createPdf(title, pdfAppointments);
      Navigator.of(context).pop();

      await Printing.layoutPdf(
        onLayout: (format) async => pdf.save(),
        name: '${title.replaceAll(' ', '_')}.pdf',
      );
    } catch (e) {
      Navigator.of(context).pop();
      print('Errore generazione PDF: $e');
      _showErrorMessage('Errore durante la generazione del PDF');
    }
  }

  Future<List<Map<String, dynamic>>> _getAppointmentsForDate(DateTime date) async {
    final dateString = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    List<Map<String, dynamic>> filtered = List.from(_appointments);
    filtered = filtered.where((app) => app['data'] == dateString).toList();

    if (_selectedStylistId != null) {
      filtered = filtered.where((app) => app['stylist_id'] == _selectedStylistId).toList();
    }

    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((app) {
        final clientName = '${app['USERS']['nome']} ${app['USERS']['cognome']}'.toLowerCase();
        final stylistName = app['STYLIST']['descrizione'].toString().toLowerCase();
        final query = _searchQuery.toLowerCase();
        return clientName.contains(query) || stylistName.contains(query) || (app['USERS']['telefono']?.toString().contains(query) ?? false);
      }).toList();
    }

    return filtered;
  }

  Future<List<Map<String, dynamic>>> _getAppointmentsForRange(DateTime start, DateTime end) async {
    List<Map<String, dynamic>> filtered = List.from(_appointments);
    filtered = filtered.where((app) {
      final appDate = DateTime.parse(app['data']);
      return appDate.isAfter(start.subtract(const Duration(days: 1))) && appDate.isBefore(end.add(const Duration(days: 1)));
    }).toList();

    if (_selectedStylistId != null) {
      filtered = filtered.where((app) => app['stylist_id'] == _selectedStylistId).toList();
    }

    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((app) {
        final clientName = '${app['USERS']['nome']} ${app['USERS']['cognome']}'.toLowerCase();
        final stylistName = app['STYLIST']['descrizione'].toString().toLowerCase();
        final query = _searchQuery.toLowerCase();
        return clientName.contains(query) || stylistName.contains(query) || (app['USERS']['telefono']?.toString().contains(query) ?? false);
      }).toList();
    }

    return filtered;
  }

  DateTime _getMonday(DateTime date) {
    return date.subtract(Duration(days: date.weekday - 1));
  }

  String _getMonthName(int month) {
    const months = ['', 'Gennaio', 'Febbraio', 'Marzo', 'Aprile', 'Maggio', 'Giugno', 'Luglio', 'Agosto', 'Settembre', 'Ottobre', 'Novembre', 'Dicembre'];
    return months[month];
  }

  Future<pw.Document> _createPdf(String title, List<Map<String, dynamic>> appointments) async {
    final pdf = pw.Document();
    Map<String, List<Map<String, dynamic>>> appointmentsByStylelist = {};

    if (_selectedStylistId == null) {
      for (var app in appointments) {
        final stylistName = app['STYLIST']['descrizione'];
        if (!appointmentsByStylelist.containsKey(stylistName)) {
          appointmentsByStylelist[stylistName] = [];
        }
        appointmentsByStylelist[stylistName]!.add(app);
      }
    } else {
      final selectedStylist = _stylists.firstWhere((s) => s['id'] == _selectedStylistId);
      appointmentsByStylelist[selectedStylist['descrizione']] = appointments;
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => _buildPdfHeader(title),
        footer: (context) => _buildPdfFooter(context),
        build: (context) => [
          for (String stylistName in appointmentsByStylelist.keys.toList()..sort())
            _buildStylistSection(stylistName, appointmentsByStylelist[stylistName]!),
        ],
      ),
    );

    return pdf;
  }

  pw.Widget _buildPdfHeader(String title) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 20),
      decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide())),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text("ART DECO' PARRUCCHIERI", style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          pw.Text(title, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.normal)),
          pw.SizedBox(height: 4),
          pw.Text('Generato il ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year} alle ${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}', style: const pw.TextStyle(fontSize: 10)),
        ],
      ),
    );
  }

  pw.Widget _buildPdfFooter(pw.Context context) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 20),
      decoration: const pw.BoxDecoration(border: pw.Border(top: pw.BorderSide())),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('Art Deco Parrucchieri - Via Pasubio 41, 70121 Bari', style: const pw.TextStyle(fontSize: 10)),
          pw.Text('Pagina ${context.pageNumber} di ${context.pagesCount}', style: const pw.TextStyle(fontSize: 10)),
        ],
      ),
    );
  }

  pw.Widget _buildStylistSection(String stylistName, List<Map<String, dynamic>> appointments) {
    if (appointments.isEmpty) return pw.SizedBox();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(8),
          decoration: pw.BoxDecoration(color: PdfColors.grey300, borderRadius: pw.BorderRadius.circular(4)),
          child: pw.Text(stylistName.toUpperCase(), style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
        ),
        pw.SizedBox(height: 12),
        ...appointments.fold<Map<String, List<Map<String, dynamic>>>>({}, (map, app) {
          final date = app['data'];
          if (!map.containsKey(date)) map[date] = [];
          map[date]!.add(app);
          return map;
        }).entries.map((entry) => _buildDateSection(entry.key, entry.value)).toList(),
        pw.SizedBox(height: 20),
      ],
    );
  }

  pw.Widget _buildDateSection(String date, List<Map<String, dynamic>> appointments) {
    appointments.sort((a, b) => a['ora_inizio'].compareTo(b['ora_inizio']));

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(_formatDate(date), style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 8),
        pw.Table(
          border: pw.TableBorder.all(),
          columnWidths: {
            0: const pw.FixedColumnWidth(60),
            1: const pw.FixedColumnWidth(120),
            2: const pw.FixedColumnWidth(80),
            3: const pw.FixedColumnWidth(150),
            4: const pw.FixedColumnWidth(50),
            5: const pw.FixedColumnWidth(80),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey200),
              children: [
                _buildTableCell('Ora', bold: true),
                _buildTableCell('Cliente', bold: true),
                _buildTableCell('Telefono', bold: true),
                _buildTableCell('Servizi', bold: true),
                _buildTableCell('Prezzo', bold: true),
                _buildTableCell('Pagamento', bold: true),
              ],
            ),
            ...appointments.map((app) => pw.TableRow(
              children: [
                _buildTableCell('${app['ora_inizio'].substring(0, 5)} - ${app['ora_fine'].substring(0, 5)}'),
                _buildTableCell('${app['USERS']['nome']} ${app['USERS']['cognome']}'),
                _buildTableCell(app['USERS']['telefono'] ?? 'N/D'),
                _buildTableCell(_getServicesText(app['APPUNTAMENTI_SERVIZI'])),
                _buildTableCell('Euro ${(app['prezzo_totale'] ?? 0).toStringAsFixed(2)}'),
                _buildTableCell(_getPaymentStatusText(app['PAGAMENTI'])),
              ],
            )).toList(),
          ],
        ),
        pw.SizedBox(height: 16),
      ],
    );
  }

  pw.Widget _buildTableCell(String text, {bool bold = false}) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(4),
      child: pw.Text(text, style: pw.TextStyle(fontSize: 9, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
    );
  }

  String _getServicesText(List<dynamic>? services) {
    if (services == null || services.isEmpty) return 'N/D';
    List<String> serviceNames = [];
    for (var service in services) {
      if (service['SERVIZI'] != null) {
        serviceNames.add(service['SERVIZI']['descrizione']);
      }
    }
    return serviceNames.join(', ');
  }

  String _getPaymentStatusText(List<dynamic>? payments) {
    if (payments == null || payments.isEmpty) return 'Da pagare';
    final payment = payments.first;
    final method = payment['metodo_pagamento'];
    final status = payment['stato'];

    if (method == 'stripe' && status == 'completato') {
      return 'Pagato Online';
    } else if (method == 'in_loco' && status == 'completato') {
      return 'Pagato in Loco';
    } else if (method == 'in_loco' && status == 'in_attesa') {
      return 'Da pagare';
    }
    return 'Da pagare';
  }

  void _showLoadingDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2d2d2d),
        content: Row(
          children: [
            const CircularProgressIndicator(color: Colors.blue),
            const SizedBox(width: 20),
            Expanded(child: Text(message, style: const TextStyle(color: Colors.white))),
          ],
        ),
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _loadCompatibleStylists(Map<String, dynamic> appointment) async {
    try {
      final supabase = Supabase.instance.client;
      final servicesResponse = await supabase
          .from('APPUNTAMENTI_SERVIZI')
          .select('SERVIZI(id, sesso_id)')
          .eq('appuntamento_id', appointment['id']);

      if (servicesResponse.isEmpty) return [];

      final sessoId = servicesResponse.first['SERVIZI']['sesso_id'];
      final stylistsResponse = await supabase
          .from('STYLIST')
          .select('id, descrizione, STYLIST_SESSO_TAGLIO!inner(sesso_id)')
          .eq('STYLIST_SESSO_TAGLIO.sesso_id', sessoId)
          .isFilter('deleted_at', null)
          .order('descrizione');

      return List<Map<String, dynamic>>.from(stylistsResponse);
    } catch (e) {
      print('Errore caricamento stylist compatibili: $e');
      return [];
    }
  }

  Future<List<String>> _loadAvailableTimeSlotsForStylist(DateTime date, int stylistId, Duration serviceDuration, {int? excludeAppointmentId}) async {
    try {
      final supabase = Supabase.instance.client;
      final dateString = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

      var query = supabase
          .from('APPUNTAMENTI')
          .select('ora_inizio, ora_fine')
          .eq('data', dateString)
          .eq('stylist_id', stylistId);

      if (excludeAppointmentId != null) {
        query = query.neq('id', excludeAppointmentId);
      }

      final appointmentsResponse = await query;
      List<String> allSlots = _generateAllTimeSlots();
      List<String> availableSlots = [];

      for (String slot in allSlots) {
        if (_isSlotAvailableForStylist(slot, serviceDuration, appointmentsResponse)) {
          availableSlots.add(slot);
        }
      }

      return availableSlots;
    } catch (e) {
      print('Errore caricamento slot per stylist: $e');
      return [];
    }
  }

  bool _isSlotAvailableForStylist(String startTime, Duration serviceDuration, List<dynamic> existingAppointments) {
    final startDateTime = DateTime.parse('2000-01-01 $startTime:00');
    final endDateTime = startDateTime.add(serviceDuration);
    final endTime = '${endDateTime.hour.toString().padLeft(2, '0')}:${endDateTime.minute.toString().padLeft(2, '0')}';

    for (var appointment in existingAppointments) {
      final appoStart = appointment['ora_inizio'] as String;
      final appoEnd = appointment['ora_fine'] as String;

      if (_timeOverlaps(startTime, endTime, appoStart.substring(0, 5), appoEnd.substring(0, 5))) {
        return false;
      }
    }
    return true;
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
    DateTime current = DateTime(2000, 1, 1, 8, 30);
    final closing = DateTime(2000, 1, 1, 20, 0);

    while (current.isBefore(closing)) {
      final timeString = '${current.hour.toString().padLeft(2, '0')}:${current.minute.toString().padLeft(2, '0')}';
      slots.add(timeString);
      current = current.add(const Duration(minutes: 15));
    }
    return slots;
  }

  void _showEditAppointmentDialog(Map<String, dynamic> appointment) {
    final _editTimeController = TextEditingController(text: appointment['ora_inizio'].substring(0, 5));
    final _editNoteController = TextEditingController(text: appointment['note'] ?? '');
    int? _editSelectedStylistId = appointment['stylist_id'];
    DateTime _editSelectedDate = DateTime.parse(appointment['data']);

    bool _isLoadingStylists = true;
    bool _isLoadingTimeSlots = false;
    List<Map<String, dynamic>> _compatibleStylists = [];
    List<String> _availableTimeSlots = [];

    showDialog(
        context: context,
        builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
      Future<void> loadTimeSlotsForCurrentStylist() async {
        if (_editSelectedStylistId != null) {
          setDialogState(() => _isLoadingTimeSlots = true);

          final slots = await _loadAvailableTimeSlotsForStylist(
            _editSelectedDate,
            _editSelectedStylistId!,
            Duration(
              hours: int.parse(appointment['durata_totale'].split(':')[0]),
              minutes: int.parse(appointment['durata_totale'].split(':')[1]),
            ),
            excludeAppointmentId: appointment['id'],
          );

          if (context.mounted) {
            setDialogState(() {
              _availableTimeSlots = slots;
              _isLoadingTimeSlots = false;
              if (!_availableTimeSlots.contains(_editTimeController.text)) {
                _editTimeController.clear();
              }
            });
          }
        }
      }

      if (_isLoadingStylists) {
        _loadCompatibleStylists(appointment).then((stylists) {
          if (context.mounted) {
            setDialogState(() {
              _compatibleStylists = stylists;
              _isLoadingStylists = false;
            });
            loadTimeSlotsForCurrentStylist();
          }
        });
      }

      return AlertDialog(
          backgroundColor: const Color(0xFF2d2d2d),
    title: const Text('Modifica Appuntamento', style: TextStyle(color: Colors.white)),
    content: SizedBox(
    width: double.maxFinite,
    height: 600,
    child: SingleChildScrollView(
    child: Column(
    mainAxisSize: MainAxisSize.min,
    children: [
    Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: const Color(0xFF1a1a1a), borderRadius: BorderRadius.circular(8)),
    child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
    Text('Cliente: ${appointment['USERS']['nome']} ${appointment['USERS']['cognome']}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
    Text('Telefono: ${appointment['USERS']['telefono'] ?? 'N/D'}', style: TextStyle(color: Colors.grey[400], fontSize: 12)),
    Text('Durata servizio: ${appointment['durata_totale']}', style: TextStyle(color: Colors.grey[400], fontSize: 12)),
    ],
    ),
    ),
    const SizedBox(height: 16),
    InkWell(
    onTap: () async {
    final date = await showDatePicker(
    context: context,
    initialDate: _editSelectedDate,
    firstDate: DateTime.now(),
    lastDate: DateTime.now().add(const Duration(days: 365)),
    builder: (context, child) {
    return Theme(
    data: Theme.of(context).copyWith(
    colorScheme: const ColorScheme.dark(primary: Colors.blue, onPrimary: Colors.white, surface: Color(0xFF2d2d2d), onSurface: Colors.white),
    ),
    child: child!,
    );
    },
    );
    if (date != null) {
    setDialogState(() {
    _editSelectedDate = date;
    });
    await loadTimeSlotsForCurrentStylist();
    }
    },
    child: Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(border: Border.all(color: Colors.grey[600]!), borderRadius: BorderRadius.circular(8)),
    child: Row(
    children: [
    Icon(Icons.calendar_today, color: Colors.grey[400], size: 20),
    const SizedBox(width: 8),
    Text('Data: ${_editSelectedDate.day}/${_editSelectedDate.month}/${_editSelectedDate.year}', style: const TextStyle(color: Colors.white)),
    ],
    ),
    ),
    ),
      const SizedBox(height: 16),
      if (_isLoadingStylists)
        const CircularProgressIndicator(color: Colors.blue)
      else
        DropdownButtonFormField<int>(
          value: _compatibleStylists.any((s) => s['id'] == _editSelectedStylistId) ? _editSelectedStylistId : null,
          decoration: InputDecoration(
            labelText: 'Stylist (solo compatibili)',
            labelStyle: TextStyle(color: Colors.grey[400]),
            prefixIcon: Icon(Icons.person, color: Colors.grey[400]),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey[600]!)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey[600]!)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.blue)),
            filled: true,
            fillColor: const Color(0xFF1a1a1a),
          ),
          dropdownColor: const Color(0xFF2d2d2d),
          style: const TextStyle(color: Colors.white),
          items: _compatibleStylists.map((stylist) => DropdownMenuItem<int>(
            value: stylist['id'],
            child: Text(stylist['descrizione'], style: const TextStyle(color: Colors.white)),
          )).toList(),
          onChanged: (value) async {
            setDialogState(() {
              _editSelectedStylistId = value;
            });
            await loadTimeSlotsForCurrentStylist();
          },
        ),
      const SizedBox(height: 16),
      if (_isLoadingTimeSlots)
        const CircularProgressIndicator(color: Colors.blue)
      else if (_editSelectedStylistId != null && _availableTimeSlots.isNotEmpty) ...[
        Text('Orari disponibili per ${_compatibleStylists.firstWhere((s) => s['id'] == _editSelectedStylistId, orElse: () => {'descrizione': 'Stylist'})['descrizione']}:', style: TextStyle(color: Colors.grey[300], fontSize: 14)),
        const SizedBox(height: 8),
        SizedBox(
          height: 120,
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, childAspectRatio: 2, crossAxisSpacing: 4, mainAxisSpacing: 4),
            itemCount: _availableTimeSlots.length,
            itemBuilder: (context, index) {
              final slot = _availableTimeSlots[index];
              final isSelected = _editTimeController.text == slot;
              return InkWell(
                onTap: () {
                  setDialogState(() {
                    _editTimeController.text = slot;
                  });
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.blue : const Color(0xFF1a1a1a),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: isSelected ? Colors.blue : Colors.grey[600]!),
                  ),
                  child: Center(
                    child: Text(slot, style: TextStyle(color: isSelected ? Colors.white : Colors.grey[300], fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                  ),
                ),
              );
            },
          ),
        ),
      ] else if (_editSelectedStylistId != null)
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.orange.withOpacity(0.2), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.orange.withOpacity(0.5))),
          child: const Text('Nessun orario disponibile per questo stylist nella data selezionata', style: TextStyle(color: Colors.orange), textAlign: TextAlign.center),
        ),
      const SizedBox(height: 16),
      TextFormField(
        controller: _editNoteController,
        style: const TextStyle(color: Colors.white),
        maxLines: 3,
        decoration: InputDecoration(
          labelText: 'Note (opzionale)',
          labelStyle: TextStyle(color: Colors.grey[400]),
          prefixIcon: Icon(Icons.note, color: Colors.grey[400]),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey[600]!)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey[600]!)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.blue)),
          filled: true,
          fillColor: const Color(0xFF1a1a1a),
        ),
      ),
    ],
    ),
    ),
    ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Annulla', style: TextStyle(color: Colors.white70))),
          ElevatedButton(
            onPressed: _editSelectedStylistId != null && _editTimeController.text.isNotEmpty ? () {
              Navigator.of(context).pop();
              _updateAppointment(appointment['id'], _editSelectedDate, _editTimeController.text, _editSelectedStylistId!, _editNoteController.text, appointment);
            } : null,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
            child: const Text('Salva Modifiche'),
          ),
        ],
      );
        },
        ),
    );
  }

  Future<void> _updateAppointment(
      int appointmentId,
      DateTime newDate,
      String newTime,
      int newStylistId,
      String newNote,
      Map<String, dynamic> originalAppointment
      ) async {
    try {
      final supabase = Supabase.instance.client;

      if (!RegExp(r'^([01]?[0-9]|2[0-3]):[0-5][0-9]$').hasMatch(newTime)) {
        _showErrorMessage('Formato orario non valido. Usa HH:MM');
        return;
      }

      final startDateTime = DateTime.parse('${newDate.year}-${newDate.month.toString().padLeft(2, '0')}-${newDate.day.toString().padLeft(2, '0')} $newTime:00');
      final originalDuration = Duration(
        hours: int.parse(originalAppointment['durata_totale'].split(':')[0]),
        minutes: int.parse(originalAppointment['durata_totale'].split(':')[1]),
      );
      final endDateTime = startDateTime.add(originalDuration);

      final dateString = '${newDate.year}-${newDate.month.toString().padLeft(2, '0')}-${newDate.day.toString().padLeft(2, '0')}';
      final endTimeString = '${endDateTime.hour.toString().padLeft(2, '0')}:${endDateTime.minute.toString().padLeft(2, '0')}:00';

      final conflictCheck = await supabase
          .from('APPUNTAMENTI')
          .select('id')
          .eq('data', dateString)
          .eq('stylist_id', newStylistId)
          .neq('id', appointmentId)
          .gte('ora_fine', '$newTime:00')
          .lte('ora_inizio', endTimeString);

      if (conflictCheck.isNotEmpty) {
        _showErrorMessage('Lo stylist non è disponibile in questo orario');
        return;
      }

      await supabase.from('APPUNTAMENTI').update({
        'data': dateString,
        'ora_inizio': '$newTime:00',
        'ora_fine': endTimeString,
        'stylist_id': newStylistId,
        'note': newNote.trim().isEmpty ? null : newNote.trim(),
      }).eq('id', appointmentId);

      print('✅ Appuntamento modificato con ID: $appointmentId');

      // 📨 NOTIFICA PUSH ONESIGNAL
      try {
        // Recupera dati utente (Firebase UID + nome)
        String? firebaseUid;
        String clientName = 'Cliente';

        try {
          final userRecord = await supabase
              .from('USERS')
              .select('uid, nome, cognome')
              .eq('id', originalAppointment['user_id'])
              .single();

          firebaseUid = userRecord['uid'];
          clientName = '${userRecord['nome']} ${userRecord['cognome']}';
          print('👤 Dati utente recuperati: $clientName (UID: $firebaseUid)');
        } catch (e) {
          print('⚠️ Errore recupero dati utente: $e');
        }

        // Controlla se data/ora sono cambiate
        final originalDate = DateTime.parse(originalAppointment['data']);
        final originalTime = originalAppointment['ora_inizio'].substring(0, 5);

        if ((originalDate != newDate || originalTime != newTime) && firebaseUid != null) {
          print('📤 Invio notifica push di modifica...');

          // Invia notifica push tramite OneSignal
          final pushSent = await OneSignalPushService.sendAppointmentModificationNotification(
            firebaseUid: firebaseUid,
            clientName: clientName,
            oldDate: originalDate,
            newDate: newDate,
            oldTime: originalTime,
            newTime: newTime,
            appointmentId: appointmentId,
          );

          if (pushSent) {
            print('✅ Notifica push inviata con successo al cliente');
            try {
              final dateString = '${newDate.year}-${newDate.month.toString().padLeft(2, '0')}-${newDate.day.toString().padLeft(2, '0')}';

              // 🔍 DEBUG: Stampa tutti i valori PRIMA dell'insert
              print('🔍 DEBUG NOTIFICA:');
              print('   - user_id: ${originalAppointment['user_id']} (tipo: ${originalAppointment['user_id'].runtimeType})');
              print('   - appointment_id: $appointmentId (tipo: ${appointmentId.runtimeType})');
              print('   - dateString: $dateString');
              print('   - newTime: $newTime');

              // 🔍 DEBUG: Controlla l'utente attualmente loggato
              final currentUser = firebase_auth.FirebaseAuth.instance.currentUser;
              print('   - Admin Firebase UID: ${currentUser?.uid}');

              // 🔍 DEBUG: Controlla il ruolo dell'admin
              try {
                final adminCheck = await supabase
                    .from('USERS')
                    .select('role, id')
                    .eq('uid', currentUser!.uid)
                    .single();
                print('   - Admin role: ${adminCheck['role']}');
                print('   - Admin user_id: ${adminCheck['id']}');
              } catch (e) {
                print('   ⚠️ Errore controllo admin: $e');
              }

              // 🔍 DEBUG: Verifica che l'utente destinatario esista
              try {
                final targetUser = await supabase
                    .from('USERS')
                    .select('id, uid, role')
                    .eq('id', originalAppointment['user_id'])
                    .single();
                print('   - Target user_id: ${targetUser['id']}');
                print('   - Target Firebase UID: ${targetUser['uid']}');
                print('   - Target role: ${targetUser['role']}');
              } catch (e) {
                print('   ⚠️ Errore controllo target user: $e');
              }

              print('🔍 Tentativo insert notifica...');

              await supabase.from('user_notifications').insert({
                'user_id': originalAppointment['user_id'],
                'title': '📝 Appuntamento Modificato',
                'message': 'Il tuo appuntamento è stato spostato a ${_formatDate(dateString)} alle $newTime',
                'type': 'appointment_modified',
                'appointment_id': appointmentId,
                'read': false,
              });

              print('✅ Notifica salvata nel database');
            } catch (e) {
              print('⚠️ Errore salvataggio notifica DB: $e');
            }
            _showSuccessMessage('Appuntamento modificato e notifica inviata');
          } else {
            print('⚠️ Invio notifica push fallito');
            _showSuccessMessage('Appuntamento modificato (notifica non inviata)');
          }
        } else {
          if (firebaseUid == null) {
            print('⚠️ Firebase UID non trovato');
          } else {
            print('ℹ️ Data/ora non cambiate, notifica non necessaria');
          }
          _showSuccessMessage('Appuntamento modificato con successo');
        }

      } catch (notifError) {
        print('⚠️ Errore gestione notifiche: $notifError');
        _showSuccessMessage('Appuntamento modificato (errore notifica)');
      }

      _loadAppointments();

    } catch (e) {
      print('❌ Errore modifica appuntamento: $e');
      _showErrorMessage('Errore durante la modifica');
    }
  }

  void _showDeleteConfirmation(Map<String, dynamic> appointment) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2d2d2d),
        title: const Text('Conferma Eliminazione', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Sei sicuro di voler eliminare questo appuntamento?', style: TextStyle(color: Colors.grey[300])),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFF1a1a1a), borderRadius: BorderRadius.circular(8)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${appointment['USERS']['nome']} ${appointment['USERS']['cognome']}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  Text('${_formatDate(appointment['data'])} alle ${appointment['ora_inizio'].substring(0, 5)}', style: TextStyle(color: Colors.grey[400], fontSize: 12)),
                  Text('Stylist: ${appointment['STYLIST']['descrizione']}', style: TextStyle(color: Colors.grey[400], fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Annulla', style: TextStyle(color: Colors.white70))),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _deleteAppointment(appointment['id']);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAppointment(int appointmentId) async {
    try {
      final supabase = Supabase.instance.client;
      await supabase.from('APPUNTAMENTI_SERVIZI').delete().eq('appuntamento_id', appointmentId);
      await supabase.from('APPUNTAMENTI').delete().eq('id', appointmentId);
      _showSuccessMessage('Appuntamento eliminato con successo');
      _loadAppointments();
    } catch (e) {
      print('Errore eliminazione appuntamento: $e');
      _showErrorMessage('Errore durante l\'eliminazione');
    }
  }

  String _formatDate(String dateString) {
    final date = DateTime.parse(dateString);
    const months = ['', 'Gen', 'Feb', 'Mar', 'Apr', 'Mag', 'Giu', 'Lug', 'Ago', 'Set', 'Ott', 'Nov', 'Dic'];
    const weekdays = ['', 'Lun', 'Mar', 'Mer', 'Gio', 'Ven', 'Sab', 'Dom'];
    return '${weekdays[date.weekday]} ${date.day} ${months[date.month]} ${date.year}';
  }

  String _formatDuration(String? duration) {
    if (duration == null || duration.isEmpty) return 'N/D';
    final parts = duration.split(':');
    if (parts.length >= 2) {
      final hours = int.tryParse(parts[0]) ?? 0;
      final minutes = int.tryParse(parts[1]) ?? 0;
      if (hours > 0) {
        return '${hours}h ${minutes}m';
      } else {
        return '${minutes}m';
      }
    }
    return duration;
  }

  String _getPaymentStatus(List<dynamic>? payments) {
    if (payments == null || payments.isEmpty) return 'Da pagare';
    final payment = payments.first;
    final method = payment['metodo_pagamento'];
    final status = payment['stato'];

    if (method == 'stripe' && status == 'completato') {
      return 'Pagato';
    } else if (method == 'in_loco' && status == 'completato') {
      return 'Pagato';
    } else if (method == 'in_loco' && status == 'in_attesa') {
      return 'Da pagare';
    }
    return 'Da pagare';
  }

  Color _getPaymentStatusColor(List<dynamic>? payments) {
    if (payments == null || payments.isEmpty) return Colors.orange;
    final payment = payments.first;
    final method = payment['metodo_pagamento'];
    final status = payment['stato'];

    if ((method == 'stripe' || method == 'in_loco') && status == 'completato') {
      return Colors.green;
    } else if (method == 'in_loco' && status == 'in_attesa') {
      return Colors.orange;
    }
    return Colors.orange;
  }

  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.green, duration: const Duration(seconds: 3)));
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.red, duration: const Duration(seconds: 3)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1a1a1a),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2d2d2d),
        elevation: 0,
        title: const Text('Gestione Appuntamenti', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.of(context).pop()),
        actions: [
          IconButton(onPressed: _loadAppointments, icon: const Icon(Icons.refresh, color: Colors.white), tooltip: 'Aggiorna'),
          IconButton(onPressed: _showPdfOptionsDialog, icon: const Icon(Icons.picture_as_pdf, color: Colors.white), tooltip: 'Genera PDF'),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.red,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.grey[400],
          onTap: (index) => _applyFilters(),
          tabs: const [
            Tab(icon: Icon(Icons.today), text: 'Oggi'),
            Tab(icon: Icon(Icons.date_range), text: 'Per Data'),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildFiltersSection(),
            Expanded(child: _isLoading ? const Center(child: CircularProgressIndicator(color: Colors.red)) : _buildAppointmentsList()),
          ],
        ),
      ),
    );
  }

  Widget _buildFiltersSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2d2d2d),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), spreadRadius: 1, blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.calendar_today, color: Colors.grey[400], size: 20),
              const SizedBox(width: 8),
              Text(_tabController.index == 0 ? 'Data (oggi): ' : 'Data selezionata: ', style: TextStyle(color: Colors.grey[400], fontSize: 14)),
              Expanded(
                child: TextButton(
                  onPressed: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _tabController.index == 0 ? _selectedDate : _customSelectedDate,
                      firstDate: DateTime.now().subtract(const Duration(days: 365)),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                      builder: (context, child) {
                        return Theme(
                          data: Theme.of(context).copyWith(
                            colorScheme: const ColorScheme.dark(primary: Colors.red, onPrimary: Colors.white, surface: Color(0xFF2d2d2d), onSurface: Colors.white),
                          ),
                          child: child!,
                        );
                      },
                    );
                    if (date != null) {
                      if (_tabController.index == 0) {
                        _onDateChanged(date);
                      } else {
                        _onCustomDateChanged(date);
                      }
                    }
                  },
                  child: Text(
                    _tabController.index == 0
                        ? _formatDate('${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}')
                        : _formatDate('${_customSelectedDate.year}-${_customSelectedDate.month.toString().padLeft(2, '0')}-${_customSelectedDate.day.toString().padLeft(2, '0')}'),
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Column(
            children: [
              TextField(
                controller: _searchController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Cerca cliente...',
                  hintStyle: TextStyle(color: Colors.grey[400]),
                  prefixIcon: Icon(Icons.search, color: Colors.grey[400]),
                  suffixIcon: _searchQuery.isNotEmpty ? IconButton(icon: Icon(Icons.clear, color: Colors.grey[400]), onPressed: () {
                    setState(() {
                      _searchQuery = '';
                      _searchController.clear();
                    });
                    _applyFilters();
                  }) : null,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey[600]!)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey[600]!)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.red)),
                  filled: true,
                  fillColor: const Color(0xFF1a1a1a),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                  _applyFilters();
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      value: _selectedStylistId,
                      decoration: InputDecoration(
                        labelText: 'Stylist',
                        labelStyle: TextStyle(color: Colors.grey[400]),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey[600]!)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey[600]!)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.red)),
                        filled: true,
                        fillColor: const Color(0xFF1a1a1a),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      dropdownColor: const Color(0xFF2d2d2d),
                      style: const TextStyle(color: Colors.white),
                      items: [
                        const DropdownMenuItem<int>(value: null, child: Text('Tutti gli stylist', style: TextStyle(color: Colors.white))),
                        ..._stylists.map((stylist) => DropdownMenuItem<int>(value: stylist['id'], child: Text(stylist['descrizione'], style: const TextStyle(color: Colors.white)))).toList(),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _selectedStylistId = value;
                        });
                        _applyFilters();
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _selectedStylistId = null;
                        _searchQuery = '';
                        _searchController.clear();
                      });
                      _applyFilters();
                    },
                    icon: const Icon(Icons.clear, color: Colors.red),
                    tooltip: 'Reset filtri',
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${_filteredAppointments.length} appuntamento/i', style: TextStyle(color: Colors.grey[400], fontSize: 12)),
              if (_filteredAppointments.isNotEmpty)
                Text('Totale: €${_filteredAppointments.fold<double>(0, (sum, app) => sum + (app['prezzo_totale'] ?? 0)).toStringAsFixed(2)}', style: const TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAppointmentsList() {
    if (_filteredAppointments.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_busy, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(_appointments.isEmpty ? 'Nessun appuntamento trovato' : 'Nessun appuntamento con i filtri selezionati', style: TextStyle(color: Colors.grey[400], fontSize: 16), textAlign: TextAlign.center),
            if (_appointments.isNotEmpty) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  setState(() {
                    _selectedStylistId = null;
                    _searchQuery = '';
                    _searchController.clear();
                  });
                  _applyFilters();
                },
                child: const Text('Rimuovi filtri'),
              ),
            ],
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredAppointments.length,
      itemBuilder: (context, index) {
        final appointment = _filteredAppointments[index];
        return _buildAppointmentCard(appointment);
      },
    );
  }

  Widget _buildAppointmentCard(Map<String, dynamic> appointment) {
    final isToday = appointment['data'] == '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Card(
        color: const Color(0xFF2d2d2d),
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: isToday ? const BorderSide(color: Colors.green, width: 1) : BorderSide.none),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _showAppointmentDetails(appointment),
          child: Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(color: Colors.blue.withOpacity(0.2), borderRadius: BorderRadius.circular(24)),
                      child: const Icon(Icons.person, color: Colors.blue, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${appointment['USERS']['nome']} ${appointment['USERS']['cognome']}', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 2),
                          Text(appointment['USERS']['telefono'] ?? 'Tel. non disponibile', style: TextStyle(color: Colors.grey[400], fontSize: 13), overflow: TextOverflow.ellipsis),                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: isToday ? Colors.green.withOpacity(0.2) : Colors.orange.withOpacity(0.2), borderRadius: BorderRadius.circular(6)),
                          child: Text('${appointment['ora_inizio'].substring(0, 5)} - ${appointment['ora_fine'].substring(0, 5)}', style: TextStyle(color: isToday ? Colors.green : Colors.orange, fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(height: 4),
                        Text('€${(appointment['prezzo_totale'] ?? 0).toStringAsFixed(2)}', style: const TextStyle(color: Colors.green, fontSize: 14, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(height: 1, color: Colors.grey[600]),
                const SizedBox(height: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Icon(Icons.content_cut, color: Colors.grey[400], size: 16),
                              const SizedBox(width: 6),
                              Flexible(child: Text(appointment['STYLIST']['descrizione'], style: TextStyle(color: Colors.grey[300], fontSize: 13), overflow: TextOverflow.ellipsis)),
                            ],
                          ),
                        ),
                        Row(
                          children: [
                            Icon(Icons.access_time, color: Colors.grey[400], size: 16),
                            const SizedBox(width: 6),
                            Text(_formatDuration(appointment['durata_totale']), style: TextStyle(color: Colors.grey[300], fontSize: 13)),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Icon(Icons.payment, color: _getPaymentStatusColor(appointment['PAGAMENTI']), size: 16),
                              const SizedBox(width: 6),
                              Text(_getPaymentStatus(appointment['PAGAMENTI']), style: TextStyle(color: _getPaymentStatusColor(appointment['PAGAMENTI']), fontSize: 13, fontWeight: FontWeight.w500)),
                            ],
                          ),
                        ),
                        if (_tabController.index != 0)
                          Row(
                            children: [
                              Icon(Icons.calendar_today, color: Colors.grey[400], size: 16),
                              const SizedBox(width: 6),
                              Text(_formatDate(appointment['data']), style: TextStyle(color: Colors.grey[300], fontSize: 13)),
                            ],
                          ),
                      ],
                    ),
                  ],
                ),
                if (isToday) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: Colors.green.withOpacity(0.2), borderRadius: BorderRadius.circular(4)),
                    child: const Text('OGGI', style: TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showAppointmentDetails(Map<String, dynamic> appointment) async {
    List<String> services = [];
    if (appointment['APPUNTAMENTI_SERVIZI'] != null) {
      for (var servizio in appointment['APPUNTAMENTI_SERVIZI']) {
        if (servizio['SERVIZI'] != null) {
          services.add(servizio['SERVIZI']['descrizione']);
        }
      }
    }

    showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (context) => Container(
            height: MediaQuery.of(context).size.height * 0.7,
            decoration: const BoxDecoration(color: Color(0xFF2d2d2d), borderRadius: BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20))),
            child: Column(
                children: [
            Container(margin: const EdgeInsets.only(top: 12), width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(2))),
        Container(
        padding: const EdgeInsets.all(24),
    child: Row(
    children: [
    Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: Colors.blue.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
      child: const Icon(Icons.calendar_today, color: Colors.blue, size: 24),
    ),
      const SizedBox(width: 16),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Appuntamento #${appointment['id']}', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            Text(_formatDate(appointment['data']), style: TextStyle(color: Colors.grey[400], fontSize: 14)),
          ],
        ),
      ),
      PopupMenuButton<String>(
        icon: const Icon(Icons.more_vert, color: Colors.white),
        color: const Color(0xFF1a1a1a),
        onSelected: (value) {
          Navigator.of(context).pop();
          if (value == 'edit') {
            _showEditAppointmentDialog(appointment);
          } else if (value == 'delete') {
            _showDeleteConfirmation(appointment);
          }
        },
        itemBuilder: (context) => [
          const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, color: Colors.white, size: 20), SizedBox(width: 8), Text('Modifica', style: TextStyle(color: Colors.white))])),
          const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, color: Colors.red, size: 20), SizedBox(width: 8), Text('Elimina', style: TextStyle(color: Colors.red))])),
        ],
      ),
    ],
    ),
        ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildDetailSection('Cliente', Icons.person, '${appointment['USERS']['nome']} ${appointment['USERS']['cognome']}', appointment['USERS']['telefono'] ?? 'N/D'),
                          const SizedBox(height: 16),
                          _buildDetailSection('Stylist', Icons.content_cut, appointment['STYLIST']['descrizione'], 'Specialista'),
                          const SizedBox(height: 16),
                          _buildDetailSection('Orario', Icons.access_time, '${appointment['ora_inizio'].substring(0, 5)} - ${appointment['ora_fine'].substring(0, 5)}', 'Durata: ${_formatDuration(appointment['durata_totale'])}'),
                          const SizedBox(height: 16),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: _getPaymentStatusColor(appointment['PAGAMENTI']).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: _getPaymentStatusColor(appointment['PAGAMENTI']).withOpacity(0.3), width: 1),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.payment, color: _getPaymentStatusColor(appointment['PAGAMENTI']), size: 20),
                                    const SizedBox(width: 8),
                                    Text('Pagamento', style: TextStyle(color: _getPaymentStatusColor(appointment['PAGAMENTI']), fontSize: 16, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(_getPaymentStatus(appointment['PAGAMENTI']), style: TextStyle(color: _getPaymentStatusColor(appointment['PAGAMENTI']), fontSize: 14, fontWeight: FontWeight.bold)),
                                    Text('€${(appointment['prezzo_totale'] ?? 0).toStringAsFixed(2)}', style: TextStyle(color: _getPaymentStatusColor(appointment['PAGAMENTI']), fontSize: 18, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(color: const Color(0xFF1a1a1a), borderRadius: BorderRadius.circular(12)),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(children: [Icon(Icons.list_alt, color: Colors.purple, size: 20), SizedBox(width: 8), Text('Servizi', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold))]),
                                const SizedBox(height: 12),
                                if (services.isEmpty)
                                  Text('Nessun servizio specificato', style: TextStyle(color: Colors.grey[400], fontSize: 14))
                                else
                                  ...services.map((service) => Padding(
                                    padding: const EdgeInsets.only(bottom: 4),
                                    child: Row(
                                      children: [
                                        Container(width: 4, height: 4, decoration: const BoxDecoration(color: Colors.purple, shape: BoxShape.circle)),
                                        const SizedBox(width: 8),
                                        Expanded(child: Text(service, style: TextStyle(color: Colors.grey[300], fontSize: 14))),
                                      ],
                                    ),
                                  )).toList(),
                              ],
                            ),
                          ),
                          if (appointment['note'] != null && appointment['note'].toString().isNotEmpty) ...[
                            const SizedBox(height: 16),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(color: const Color(0xFF1a1a1a), borderRadius: BorderRadius.circular(12)),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Row(children: [Icon(Icons.note, color: Colors.orange, size: 20), SizedBox(width: 8), Text('Note', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold))]),
                                  const SizedBox(height: 8),
                                  Text(appointment['note'], style: TextStyle(color: Colors.grey[300], fontSize: 14)),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                ],
            ),
        ),
    );
  }

  Widget _buildDetailSection(String title, IconData icon, String mainText, String subText) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF1a1a1a), borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.blue.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: Colors.blue, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: Colors.grey[400], fontSize: 12, fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                Text(mainText, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                Text(subText, style: TextStyle(color: Colors.grey[400], fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}