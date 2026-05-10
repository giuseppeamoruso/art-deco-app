import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'service_selection_page.dart';

class StylistSelectionPage extends StatefulWidget {
  final String section; // 'uomo' o 'donna'

  const StylistSelectionPage({
    super.key,
    required this.section,
  });

  @override
  State<StylistSelectionPage> createState() => _StylistSelectionPageState();
}

class _StylistSelectionPageState extends State<StylistSelectionPage> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _stylists = [];
  Map<String, dynamic>? _selectedStylist;

  @override
  void initState() {
    super.initState();
    _loadStylists();
  }

  Future<void> _loadStylists() async {
    setState(() => _isLoading = true);

    try {
      final supabase = Supabase.instance.client;
      final sessoId = widget.section == 'uomo' ? 1 : 2;

      // Query per ottenere gli stylist filtrati per sesso
      final response = await supabase
          .from('STYLIST')
          .select('''
            id,
            descrizione,
            STYLIST_SESSO_TAGLIO!inner(sesso_id)
          ''')
          .eq('STYLIST_SESSO_TAGLIO.sesso_id', sessoId)
          .isFilter('deleted_at', null);

      setState(() {
        _stylists = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });

      print('✅ Stylist caricati: ${_stylists.length}');

    } catch (e) {
      print('❌ Errore caricamento stylist: $e');
      setState(() => _isLoading = false);

      if (mounted) {
        _showErrorMessage('Errore nel caricamento degli stylist');
      }
    }
  }

  void _selectStylist(Map<String, dynamic> stylist) {
    setState(() {
      _selectedStylist = stylist;
    });
  }

  void _navigateToServiceSelection() {
    if (_selectedStylist == null) {
      _showErrorMessage('Seleziona uno stylist per continuare');
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ServiceSelectionPage(
          section: widget.section,
          stylistId: _selectedStylist!['id'],
          stylistName: _selectedStylist!['descrizione'],
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
        title: Text(
          'Scegli il tuo Stylist - ${widget.section.toUpperCase()}',
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
            : _stylists.isEmpty
            ? _buildEmptyState()
            : _buildStylistList(),
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
              onPressed: _navigateToServiceSelection,
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
                'Continua con ${_selectedStylist!['descrizione']}',
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
          Text(
            'Nessun stylist disponibile',
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
            onPressed: _loadStylists,
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

  Widget _buildStylistList() {
    return Column(
      children: [
        // Header informativo
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
                widget.section == 'donna' ? Icons.face_3 : Icons.face,
                color: widget.section == 'donna' ? Colors.pink : Colors.blue,
                size: 32,
              ),
              const SizedBox(height: 12),
              Text(
                'Stylist disponibili',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Scegli il professionista che preferisci per il tuo trattamento',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey[300],
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),

        // Lista stylist
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: _stylists.length,
            itemBuilder: (context, index) {
              final stylist = _stylists[index];
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
                                  child: const Text(
                                    'Disponibile',
                                    style: TextStyle(
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