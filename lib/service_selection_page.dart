import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'datetime_selection_page.dart';

class ServiceSelectionPage extends StatefulWidget {
  final String section; // 'uomo' o 'donna'

  const ServiceSelectionPage({
    super.key,
    required this.section,
  });

  @override
  State<ServiceSelectionPage> createState() => _ServiceSelectionPageState();
}

class _ServiceSelectionPageState extends State<ServiceSelectionPage> {
  String _searchQuery = '';
  bool _isLoading = true;
  List<Map<String, dynamic>> _services = [];
  List<Map<String, dynamic>> _selectedServices = [];
  double _totalPrice = 0.0;
  Duration _totalDuration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _loadServices();
  }

  Future<void> _loadServices() async {
    setState(() => _isLoading = true);

    try {
      final supabase = Supabase.instance.client;
      final sessoId = widget.section == 'uomo' ? 1 : 2;

      final response = await supabase
          .from('SERVIZI')
          .select('id, descrizione, prezzo, durata')
          .eq('sesso_id', sessoId)
          .order('ordine', ascending: true);

      setState(() {
        _services = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });

      print('✅ Servizi caricati: ${_services.length}');
    } catch (e) {
      print('❌ Errore caricamento servizi: $e');
      setState(() => _isLoading = false);

      if (mounted) {
        _showErrorMessage('Errore nel caricamento dei servizi');
      }
    }
  }

  void _toggleService(Map<String, dynamic> service) {
    setState(() {
      final existingIndex = _selectedServices.indexWhere(
            (s) => s['id'] == service['id'],
      );

      if (existingIndex >= 0) {
        _selectedServices.removeAt(existingIndex);
      } else {
        _selectedServices.add(service);
      }

      _calculateTotals();
    });
  }

  void _calculateTotals() {
    _totalPrice = 0.0;
    _totalDuration = Duration.zero;

    for (final service in _selectedServices) {
      final prezzoString =
      service['prezzo'].toString().replaceAll('€', '').trim();
      _totalPrice += double.tryParse(prezzoString) ?? 0.0;

      final durataString = service['durata'].toString();
      final parts = durataString.split(':');
      if (parts.length >= 3) {
        final hours = int.tryParse(parts[0]) ?? 0;
        final minutes = int.tryParse(parts[1]) ?? 0;
        final seconds = int.tryParse(parts[2]) ?? 0;

        _totalDuration += Duration(
          hours: hours,
          minutes: minutes,
          seconds: seconds,
        );
      }
    }
  }

  void _navigateToDateTime() {
    if (_selectedServices.isEmpty) {
      _showErrorMessage('Seleziona almeno un servizio per continuare');
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => DateTimeSelectionPage(
          section: widget.section,
          selectedServices: _selectedServices,
          totalDuration: _totalDuration,
          totalPrice: _totalPrice,
        ),
      ),
    );
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

  String _formatPrice(dynamic price) {
    if (price is String) {
      return price.endsWith('€') ? price : '$price€';
    }
    return '$price€';
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
        title: Text(
          'Seleziona Servizi - ${widget.section.toUpperCase()}',
          style: const TextStyle(
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
        child: _isLoading
            ? const Center(
          child: CircularProgressIndicator(color: Colors.white),
        )
            : _services.isEmpty
            ? _buildEmptyState()
            : _buildServicesList(),
      ),
      bottomNavigationBar: _selectedServices.isNotEmpty
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1a1a1a),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_selectedServices.length} servizio/i',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Durata: ${_formatDuration(_totalDuration)}',
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '€${_totalPrice.toStringAsFixed(2)}',
                      style: TextStyle(
                        color: widget.section == 'donna'
                            ? Colors.pink
                            : Colors.blue,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _navigateToDateTime,
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
                  child: const Text(
                    'Continua',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
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
            Icons.content_cut_outlined,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Nessun servizio disponibile',
            style: TextStyle(
              color: Colors.grey[300],
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'per la sezione ${widget.section}',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _loadServices,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF1a1a1a),
            ),
            child: const Text('Riprova'),
          ),
        ],
      ),
    );
  }

  Widget _buildServicesList() {
    // ✅ Filtra i servizi in base alla ricerca
    final filteredServices = _services.where((service) {
      final descrizione =
          service['descrizione']?.toString().toLowerCase() ?? '';
      return descrizione.contains(_searchQuery.toLowerCase());
    }).toList();

    return Column(
      children: [
        // Header con barra di ricerca
        Container(
          width: double.infinity,
          margin: const EdgeInsets.all(20),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF2d2d2d),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                spreadRadius: 2,
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Icon(
                Icons.content_cut,
                color:
                widget.section == 'donna' ? Colors.pink : Colors.blue,
                size: 32,
              ),
              const SizedBox(height: 12),
              const Text(
                'I nostri servizi',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Seleziona uno o più servizi per il tuo trattamento',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 16),

              // 🔍 BARRA DI RICERCA
              TextField(
                onChanged: (value) => setState(() => _searchQuery = value),
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Cerca servizio...',
                  hintStyle: TextStyle(color: Colors.grey[500]),
                  prefixIcon: Icon(
                    Icons.search,
                    color: widget.section == 'donna'
                        ? Colors.pink
                        : Colors.blue,
                  ),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                    icon: const Icon(Icons.clear, color: Colors.grey),
                    onPressed: () =>
                        setState(() => _searchQuery = ''),
                  )
                      : null,
                  filled: true,
                  fillColor: const Color(0xFF1a1a1a),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: widget.section == 'donna'
                          ? Colors.pink
                          : Colors.blue,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Lista servizi filtrata
        Expanded(
          child: filteredServices.isEmpty
              ? Center(
            child: Text(
              'Nessun servizio trovato per "$_searchQuery"',
              style: TextStyle(color: Colors.grey[400], fontSize: 16),
              textAlign: TextAlign.center,
            ),
          )
              : ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: filteredServices.length,
            itemBuilder: (context, index) {
              final service = filteredServices[index];
              final isSelected = _selectedServices.any(
                    (s) => s['id'] == service['id'],
              );

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                child: Card(
                  color: isSelected
                      ? (widget.section == 'donna'
                      ? Colors.pink.withOpacity(0.1)
                      : Colors.blue.withOpacity(0.1))
                      : const Color(0xFF2d2d2d),
                  elevation: isSelected ? 8 : 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: isSelected
                        ? BorderSide(
                      color: widget.section == 'donna'
                          ? Colors.pink
                          : Colors.blue,
                      width: 2,
                    )
                        : BorderSide.none,
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => _toggleService(service),
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          // Icona servizio
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: widget.section == 'donna'
                                  ? Colors.pink.withOpacity(0.2)
                                  : Colors.blue.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(25),
                              border: isSelected
                                  ? Border.all(
                                color: widget.section == 'donna'
                                    ? Colors.pink
                                    : Colors.blue,
                                width: 2,
                              )
                                  : null,
                            ),
                            child: Icon(
                              Icons.content_cut,
                              color: widget.section == 'donna'
                                  ? Colors.pink
                                  : Colors.blue,
                              size: 24,
                            ),
                          ),

                          const SizedBox(width: 16),

                          // Informazioni servizio
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                              CrossAxisAlignment.start,
                              children: [
                                Text(
                                  service['descrizione'] ?? 'Servizio',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.access_time,
                                      color: Colors.grey[400],
                                      size: 16,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      _formatDuration(
                                        Duration(
                                          hours: int.tryParse(service[
                                          'durata']
                                              .toString()
                                              .split(':')[0]) ??
                                              0,
                                          minutes: int.tryParse(service[
                                          'durata']
                                              .toString()
                                              .split(':')[1]) ??
                                              0,
                                        ),
                                      ),
                                      style: TextStyle(
                                        color: Colors.grey[400],
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Icon(
                                      Icons.euro,
                                      color: Colors.grey[400],
                                      size: 16,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      _formatPrice(service['prezzo']),
                                      style: TextStyle(
                                        color: widget.section == 'donna'
                                            ? Colors.pink
                                            : Colors.blue,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          // Checkbox selezione
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? (widget.section == 'donna'
                                  ? Colors.pink
                                  : Colors.blue)
                                  : Colors.transparent,
                              border: Border.all(
                                color: isSelected
                                    ? (widget.section == 'donna'
                                    ? Colors.pink
                                    : Colors.blue)
                                    : Colors.grey,
                                width: 2,
                              ),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: isSelected
                                ? const Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 16,
                            )
                                : null,
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