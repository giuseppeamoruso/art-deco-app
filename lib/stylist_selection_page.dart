import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'datetime_selection_page.dart';

class StylistSelectionPage extends StatefulWidget {
  final String section;
  final List<Map<String, dynamic>> selectedServices;
  final Duration totalDuration;
  final double totalPrice;

  const StylistSelectionPage({
    super.key,
    required this.section,
    required this.selectedServices,
    required this.totalDuration,
    required this.totalPrice,
  });

  @override
  State<StylistSelectionPage> createState() => _StylistSelectionPageState();
}

class _StylistSelectionPageState extends State<StylistSelectionPage> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _stylists = [];

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

      final response = await supabase
          .from('STYLIST')
          .select('id, descrizione, STYLIST_SESSO_TAGLIO!inner(sesso_id)')
          .eq('STYLIST_SESSO_TAGLIO.sesso_id', sessoId)
          .isFilter('deleted_at', null);

      setState(() {
        _stylists = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      print('❌ Errore caricamento stylist: $e');
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Errore nel caricamento degli stylist'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _selectStylist(Map<String, dynamic> stylist) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => DateTimeSelectionPage(
          section: widget.section,
          selectedServices: widget.selectedServices,
          totalDuration: widget.totalDuration,
          totalPrice: widget.totalPrice,
          selectedStylist: stylist,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = widget.section == 'donna' ? Colors.pink : Colors.blue;

    return Scaffold(
      backgroundColor: const Color(0xFF1a1a1a),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2d2d2d),
        elevation: 0,
        title: const Text(
          'Scegli il tuo Stylist',
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
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Colors.white))
            : _stylists.isEmpty
                ? _buildEmptyState()
                : _buildStylistsList(accentColor),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Text(
          'Nessuno stylist disponibile al momento.',
          style: TextStyle(color: Colors.white70, fontSize: 16),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildStylistsList(Color accentColor) {
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _stylists.length,
      itemBuilder: (context, index) {
        final stylist = _stylists[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          child: InkWell(
            onTap: () => _selectStylist(stylist),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF2d2d2d),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withOpacity(0.08),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: accentColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Icon(
                      Icons.person,
                      color: accentColor,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          stylist['descrizione'] ?? 'Stylist',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Seleziona per vedere le disponibilità',
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios,
                    color: Colors.grey[600],
                    size: 16,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
