import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class AdminMatrimonioRichiestePage extends StatefulWidget {
  const AdminMatrimonioRichiestePage({Key? key}) : super(key: key);

  @override
  State<AdminMatrimonioRichiestePage> createState() =>
      _AdminMatrimonioRichiestePageState();
}

class _AdminMatrimonioRichiestePageState
    extends State<AdminMatrimonioRichiestePage> {
  List<Map<String, dynamic>> _richieste = [];
  bool _isLoading = true;
  String _filtroStato = 'tutti'; // tutti, in_attesa, visionata, contattato, confermato

  @override
  void initState() {
    super.initState();
    _loadRichieste();
  }

  Future<void> _loadRichieste() async {
    setState(() => _isLoading = true);

    try {
      // Carica tutte le richieste non cancellate
      final response = await Supabase.instance.client
          .from('MATRIMONIO_RICHIESTE')
          .select()
          .isFilter('deleted_at', null)
          .order('created_at', ascending: false);

      List<Map<String, dynamic>> allRichieste = List<Map<String, dynamic>>.from(response);

      // Applica filtro stato manualmente
      if (_filtroStato != 'tutti') {
        allRichieste = allRichieste.where((r) => r['stato'] == _filtroStato).toList();
      }

      setState(() {
        _richieste = allRichieste;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore caricamento richieste: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _segnaVisionata(int richiestaId) async {
    try {
      // Aggiorna nel database
      await Supabase.instance.client
          .from('MATRIMONIO_RICHIESTE')
          .update({
        'visionata_da_admin': true,
        'visionata_il': DateTime.now().toIso8601String(),
        'stato': 'visionata',
      })
          .eq('id', richiestaId);

      // Chiama Edge Function per notificare lo user
      await Supabase.instance.client.functions.invoke(
        'notify-matrimonio',
        body: {
          'type': 'request_viewed',
          'richiesta_id': richiestaId,
        },
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Richiesta segnata come visionata'),
            backgroundColor: Colors.green,
          ),
        );
      }

      // Ricarica lista
      _loadRichieste();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _cambiaStato(int richiestaId, String nuovoStato) async {
    try {
      print('🔄 Cambio stato richiesta $richiestaId a: $nuovoStato');

      // Aggiorna stato nel database
      await Supabase.instance.client
          .from('MATRIMONIO_RICHIESTE')
          .update({'stato': nuovoStato})
          .eq('id', richiestaId);

      print('✅ Stato aggiornato nel database');

      // ✅ Notifica user del cambio stato (solo per stati importanti)
      if (nuovoStato == 'contattato' || nuovoStato == 'confermato' || nuovoStato == 'annullato') {
        print('📤 Invio notifica cambio stato...');

        try {
          await Supabase.instance.client.functions.invoke(
            'notify-matrimonio',
            body: {
              'type': 'status_changed',
              'richiesta_id': richiestaId,
              'new_status': nuovoStato,
            },
          );
          print('✅ Notifica inviata');
        } catch (notifError) {
          print('⚠️ Errore notifica cambio stato: $notifError');
          // Non blocchiamo il flusso se la notifica fallisce
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Stato aggiornato a: $nuovoStato'),
            backgroundColor: Colors.green,
          ),
        );
      }

      _loadRichieste();
    } catch (e) {
      print('❌ Errore cambio stato: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _eliminaRichiesta(int richiestaId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2d2d2d),
        title: const Text(
          'Conferma Eliminazione',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Sei sicuro di voler eliminare questa richiesta?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annulla'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        // Soft delete
        await Supabase.instance.client
            .from('MATRIMONIO_RICHIESTE')
            .update({'deleted_at': DateTime.now().toIso8601String()})
            .eq('id', richiestaId);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Richiesta eliminata'),
              backgroundColor: Colors.green,
            ),
          );
        }

        _loadRichieste();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Errore: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _mostraDettagli(Map<String, dynamic> richiesta) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF2d2d2d),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Dettagli Richiesta',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, color: Colors.white),
                    ),
                  ],
                ),
                const Divider(color: Colors.white24),
                const SizedBox(height: 10),

                // Info cliente
                _buildInfoRow('👤 Nome:', '${richiesta['nome']} ${richiesta['cognome']}'),
                _buildInfoRow('📞 Telefono:', richiesta['telefono']),
                const SizedBox(height: 10),

                // Servizi
                const Text(
                  'Servizi richiesti:',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                if (richiesta['servizio_sposa'] == true)
                  _buildServiceChip('💍 Acconciature Sposa', Colors.pink),
                if (richiesta['servizio_sposo'] == true)
                  _buildServiceChip('🤵 Acconciature Sposo', Colors.blue),
                const SizedBox(height: 15),

                // Note
                if (richiesta['note'] != null && richiesta['note'].toString().isNotEmpty) ...[
                  const Text(
                    'Note:',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1a1a1a),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      richiesta['note'],
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ),
                  const SizedBox(height: 15),
                ],

                // Stato e date
                _buildInfoRow(
                  'Stato:',
                  _getStatoLabel(richiesta['stato']),
                ),
                _buildInfoRow(
                  'Data richiesta:',
                  _formatDate(richiesta['created_at']),
                ),
                if (richiesta['visionata_il'] != null)
                  _buildInfoRow(
                    'Visionata il:',
                    _formatDate(richiesta['visionata_il']),
                  ),
                const SizedBox(height: 20),

                // Azioni
                if (richiesta['visionata_da_admin'] == false)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _segnaVisionata(richiesta['id']);
                      },
                      icon: const Icon(Icons.check),
                      label: const Text('SEGNA COME VISIONATA'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                      ),
                    ),
                  ),
                const SizedBox(height: 10),

                // Cambia stato
                SizedBox(
                  width: double.infinity,
                  child: DropdownButtonFormField<String>(
                    value: richiesta['stato'],
                    decoration: const InputDecoration(
                      labelText: 'Cambia stato',
                      border: OutlineInputBorder(),
                      labelStyle: TextStyle(color: Colors.white70),
                    ),
                    dropdownColor: const Color(0xFF2d2d2d),
                    style: const TextStyle(color: Colors.white),
                    items: const [
                      DropdownMenuItem(value: 'in_attesa', child: Text('In attesa')),
                      DropdownMenuItem(value: 'visionata', child: Text('Visionata')),
                      DropdownMenuItem(value: 'contattato', child: Text('Contattato')),
                      DropdownMenuItem(value: 'confermato', child: Text('Confermato')),
                      DropdownMenuItem(value: 'annullato', child: Text('Annullato')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        Navigator.pop(context);
                        _cambiaStato(richiesta['id'], value);
                      }
                    },
                  ),
                ),
                const SizedBox(height: 10),

                // Elimina
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _eliminaRichiesta(richiesta['id']);
                    },
                    icon: const Icon(Icons.delete, color: Colors.red),
                    label: const Text(
                      'ELIMINA RICHIESTA',
                      style: TextStyle(color: Colors.red),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(vertical: 15),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceChip(String label, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return DateFormat('dd/MM/yyyy HH:mm').format(date);
    } catch (e) {
      return dateString;
    }
  }

  String _getStatoLabel(String stato) {
    switch (stato) {
      case 'in_attesa':
        return '⏳ In attesa';
      case 'visionata':
        return '👁️ Visionata';
      case 'contattato':
        return '📞 Contattato';
      case 'confermato':
        return '✅ Confermato';
      case 'annullato':
        return '❌ Annullato';
      default:
        return stato;
    }
  }

  Color _getStatoColor(String stato) {
    switch (stato) {
      case 'in_attesa':
        return Colors.orange;
      case 'visionata':
        return Colors.blue;
      case 'contattato':
        return Colors.purple;
      case 'confermato':
        return Colors.green;
      case 'annullato':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1a1a1a),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2d2d2d),
        title: const Text('Richieste Matrimoni'),
        actions: [
          IconButton(
            onPressed: _loadRichieste,
            icon: const Icon(Icons.refresh),
            tooltip: 'Aggiorna',
          ),
        ],
      ),
      body: Column(
        children: [
          // Filtri
          Container(
            padding: const EdgeInsets.all(16),
            color: const Color(0xFF2d2d2d),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFiltroChip('Tutti', 'tutti'),
                  _buildFiltroChip('In attesa', 'in_attesa'),
                  _buildFiltroChip('Visionata', 'visionata'),
                  _buildFiltroChip('Contattato', 'contattato'),
                  _buildFiltroChip('Confermato', 'confermato'),
                ],
              ),
            ),
          ),

          // Lista richieste
          Expanded(
            child: _isLoading
                ? const Center(
              child: CircularProgressIndicator(color: Colors.white),
            )
                : _richieste.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.inbox,
                    size: 64,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Nessuna richiesta',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            )
                : RefreshIndicator(
              onRefresh: _loadRichieste,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _richieste.length,
                itemBuilder: (context, index) {
                  final richiesta = _richieste[index];
                  return _buildRichiestaCard(richiesta);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFiltroChip(String label, String value) {
    final isSelected = _filtroStato == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          setState(() {
            _filtroStato = value;
            _loadRichieste();
          });
        },
        backgroundColor: const Color(0xFF1a1a1a),
        selectedColor: const Color(0xFFD4AF37),
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : Colors.white70,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }

  Widget _buildRichiestaCard(Map<String, dynamic> richiesta) {
    final stato = richiesta['stato'] ?? 'in_attesa';
    final statoColor = _getStatoColor(stato);
    final visionata = richiesta['visionata_da_admin'] == true;

    return Card(
      color: const Color(0xFF2d2d2d),
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _mostraDettagli(richiesta),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  // Badge stato
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statoColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: statoColor),
                    ),
                    child: Text(
                      _getStatoLabel(stato),
                      style: TextStyle(
                        color: statoColor,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Badge non visionata
                  if (!visionata)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red),
                      ),
                      child: const Text(
                        '⚠️ NON VISIONATA',
                        style: TextStyle(
                          color: Colors.red,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  const Spacer(),
                  Text(
                    _formatDate(richiesta['created_at']),
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Nome cliente
              Text(
                '${richiesta['nome']} ${richiesta['cognome']}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),

              // Telefono
              Row(
                children: [
                  const Icon(Icons.phone, size: 16, color: Colors.grey),
                  const SizedBox(width: 6),
                  Text(
                    richiesta['telefono'],
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Servizi
              Row(
                children: [
                  if (richiesta['servizio_sposa'] == true)
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.pink.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        '💍 Sposa',
                        style: TextStyle(color: Colors.pink, fontSize: 12),
                      ),
                    ),
                  if (richiesta['servizio_sposo'] == true)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        '🤵 Sposo',
                        style: TextStyle(color: Colors.blue, fontSize: 12),
                      ),
                    ),
                ],
              ),

              // Bottone azione rapida
              if (!visionata) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _segnaVisionata(richiesta['id']),
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('SEGNA COME VISIONATA'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(vertical: 10),
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
}