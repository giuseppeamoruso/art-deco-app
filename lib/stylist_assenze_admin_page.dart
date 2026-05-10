import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class StylistAssenzeAdminPage extends StatefulWidget {
  const StylistAssenzeAdminPage({super.key});

  @override
  State<StylistAssenzeAdminPage> createState() => _StylistAssenzeAdminPageState();
}

class _StylistAssenzeAdminPageState extends State<StylistAssenzeAdminPage> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _assenze = [];
  List<Map<String, dynamic>> _stylists = [];
  String _selectedFilter = 'tutte'; // tutte, richiesto, approvato, rifiutato
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final supabase = Supabase.instance.client;

      // Carica stylists
      final stylistsResponse = await supabase
          .from('STYLIST')
          .select('id, descrizione')
          .isFilter('deleted_at', null);

      // Carica assenze con join stylist
      final assenzeResponse = await supabase
          .from('STYLIST_ASSENZE')
          .select('''
            id, stylist_id, tipo, data_inizio, data_fine, 
            ora_inizio, ora_fine, motivo, stato, 
            approvato_da, approvato_il, note_admin, created_at,
            STYLIST!inner(descrizione)
          ''')
          .order('created_at', ascending: false);

      setState(() {
        _stylists = List<Map<String, dynamic>>.from(stylistsResponse);
        _assenze = List<Map<String, dynamic>>.from(assenzeResponse);
        _isLoading = false;
      });

    } catch (e) {
      print('❌ Errore caricamento dati: $e');
      setState(() => _isLoading = false);
      _showErrorMessage('Errore nel caricamento dei dati');
    }
  }

  List<Map<String, dynamic>> get _filteredAssenze {
    return _assenze.where((assenza) {
      // Filtro per stato
      if (_selectedFilter != 'tutte' && assenza['stato'] != _selectedFilter) {
        return false;
      }

      // Filtro per ricerca
      if (_searchQuery.isNotEmpty) {
        final stylistDescrizione = assenza['STYLIST']['descrizione'].toString().toLowerCase();
        final tipo = assenza['tipo'].toString().toLowerCase();
        final query = _searchQuery.toLowerCase();

        if (!stylistDescrizione.contains(query) && !tipo.contains(query)) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '-';
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    } catch (e) {
      return dateStr;
    }
  }

  String _formatDateTime(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  String _formatTime(String? timeStr) {
    if (timeStr == null) return '-';
    try {
      // Se il time include i microsecondi, li rimuoviamo
      String cleanTime = timeStr.split('.').first;
      if (cleanTime.length > 8) {
        cleanTime = cleanTime.substring(0, 8);
      }
      return cleanTime.substring(0, 5); // HH:MM
    } catch (e) {
      return timeStr;
    }
  }

  Color _getStatusColor(String stato) {
    switch (stato) {
      case 'richiesto':
        return Colors.orange;
      case 'approvato':
        return Colors.green;
      case 'rifiutato':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getTipoDisplayName(String tipo) {
    switch (tipo) {
      case 'permesso_ore':
        return 'Permesso Ore';
      case 'permesso_giorno':
        return 'Permesso Giorno';
      case 'ferie':
        return 'Ferie';
      case 'malattia':
        return 'Malattia';
      default:
        return tipo;
    }
  }

  Future<void> _showAssenzaDialog({Map<String, dynamic>? assenza}) async {
    final isEditing = assenza != null;

    String selectedStylistId = assenza?['stylist_id']?.toString() ?? '';
    String selectedTipo = assenza?['tipo'] ?? 'permesso_ore';
    DateTime? dataInizio = assenza != null ? DateTime.tryParse(assenza['data_inizio']) : null;
    DateTime? dataFine = assenza != null && assenza['data_fine'] != null
        ? DateTime.tryParse(assenza['data_fine']) : null;
    TimeOfDay? oraInizio = assenza != null && assenza['ora_inizio'] != null
        ? _parseTimeOfDay(assenza['ora_inizio']) : null;
    TimeOfDay? oraFine = assenza != null && assenza['ora_fine'] != null
        ? _parseTimeOfDay(assenza['ora_fine']) : null;
    String motivo = assenza?['motivo'] ?? '';
    String stato = assenza?['stato'] ?? 'richiesto';
    String noteAdmin = assenza?['note_admin'] ?? '';

    final motivoController = TextEditingController(text: motivo);
    final noteController = TextEditingController(text: noteAdmin);

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF2d2d2d),
              title: Text(
                isEditing ? 'Modifica Assenza' : 'Nuova Assenza',
                style: const TextStyle(color: Colors.white),
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Selezione Stylist
                      DropdownButtonFormField<String>(
                        value: selectedStylistId.isEmpty ? null : selectedStylistId,
                        decoration: const InputDecoration(
                          labelText: 'Stylist',
                          labelStyle: TextStyle(color: Colors.white70),
                          enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.white30),
                          ),
                        ),
                        dropdownColor: const Color(0xFF2d2d2d),
                        style: const TextStyle(color: Colors.white),
                        items: _stylists.map((stylist) {
                          return DropdownMenuItem<String>(
                            value: stylist['id'].toString(),
                            child: Text(stylist['descrizione']),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setDialogState(() {
                            selectedStylistId = value ?? '';
                          });
                        },
                      ),
                      const SizedBox(height: 16),

                      // Tipo assenza
                      DropdownButtonFormField<String>(
                        value: selectedTipo,
                        decoration: const InputDecoration(
                          labelText: 'Tipo Assenza',
                          labelStyle: TextStyle(color: Colors.white70),
                          enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.white30),
                          ),
                        ),
                        dropdownColor: const Color(0xFF2d2d2d),
                        style: const TextStyle(color: Colors.white),
                        items: const [
                          DropdownMenuItem(value: 'permesso_ore', child: Text('Permesso Ore')),
                          DropdownMenuItem(value: 'permesso_giorno', child: Text('Permesso Giorno')),
                          DropdownMenuItem(value: 'ferie', child: Text('Ferie')),
                          DropdownMenuItem(value: 'malattia', child: Text('Malattia')),
                        ],
                        onChanged: (value) {
                          setDialogState(() {
                            selectedTipo = value!;
                          });
                        },
                      ),
                      const SizedBox(height: 16),

                      // Data inizio
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Data Inizio', style: TextStyle(color: Colors.white70)),
                        subtitle: Text(
                          dataInizio != null
                              ? _formatDateTime(dataInizio!)
                              : 'Seleziona data',
                          style: const TextStyle(color: Colors.white),
                        ),
                        trailing: const Icon(Icons.calendar_today, color: Colors.white70),
                        onTap: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: dataInizio ?? DateTime.now(),
                            firstDate: DateTime.now().subtract(const Duration(days: 365)),
                            lastDate: DateTime.now().add(const Duration(days: 365)),
                          );
                          if (date != null) {
                            setDialogState(() {
                              dataInizio = date;
                            });
                          }
                        },
                      ),

                      // Data fine (solo per permessi giorno e ferie)
                      if (selectedTipo == 'permesso_giorno' || selectedTipo == 'ferie') ...[
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Data Fine (opzionale)', style: TextStyle(color: Colors.white70)),
                          subtitle: Text(
                            dataFine != null
                                ? _formatDateTime(dataFine!)
                                : 'Seleziona data',
                            style: const TextStyle(color: Colors.white),
                          ),
                          trailing: const Icon(Icons.calendar_today, color: Colors.white70),
                          onTap: () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: dataFine ?? dataInizio ?? DateTime.now(),
                              firstDate: dataInizio ?? DateTime.now(),
                              lastDate: DateTime.now().add(const Duration(days: 365)),
                            );
                            if (date != null) {
                              setDialogState(() {
                                dataFine = date;
                              });
                            }
                          },
                        ),
                      ],

                      // Ora inizio/fine per permessi ore
                      if (selectedTipo == 'permesso_ore') ...[
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Ora Inizio', style: TextStyle(color: Colors.white70)),
                          subtitle: Text(
                            oraInizio != null
                                ? oraInizio!.format(context)
                                : 'Seleziona ora',
                            style: const TextStyle(color: Colors.white),
                          ),
                          trailing: const Icon(Icons.access_time, color: Colors.white70),
                          onTap: () async {
                            final time = await showTimePicker(
                              context: context,
                              initialTime: oraInizio ?? TimeOfDay.now(),
                            );
                            if (time != null) {
                              setDialogState(() {
                                oraInizio = time;
                              });
                            }
                          },
                        ),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Ora Fine', style: TextStyle(color: Colors.white70)),
                          subtitle: Text(
                            oraFine != null
                                ? oraFine!.format(context)
                                : 'Seleziona ora',
                            style: const TextStyle(color: Colors.white),
                          ),
                          trailing: const Icon(Icons.access_time, color: Colors.white70),
                          onTap: () async {
                            final time = await showTimePicker(
                              context: context,
                              initialTime: oraFine ?? TimeOfDay.now(),
                            );
                            if (time != null) {
                              setDialogState(() {
                                oraFine = time;
                              });
                            }
                          },
                        ),
                      ],

                      const SizedBox(height: 16),

                      // Motivo
                      TextField(
                        controller: motivoController,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          labelText: 'Motivo',
                          labelStyle: TextStyle(color: Colors.white70),
                          enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.white30),
                          ),
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 16),

                      // Stato
                      DropdownButtonFormField<String>(
                        value: stato,
                        decoration: const InputDecoration(
                          labelText: 'Stato',
                          labelStyle: TextStyle(color: Colors.white70),
                          enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.white30),
                          ),
                        ),
                        dropdownColor: const Color(0xFF2d2d2d),
                        style: const TextStyle(color: Colors.white),
                        items: const [
                          DropdownMenuItem(value: 'richiesto', child: Text('Richiesto')),
                          DropdownMenuItem(value: 'approvato', child: Text('Approvato')),
                          DropdownMenuItem(value: 'rifiutato', child: Text('Rifiutato')),
                        ],
                        onChanged: (value) {
                          setDialogState(() {
                            stato = value!;
                          });
                        },
                      ),
                      const SizedBox(height: 16),

                      // Note admin
                      TextField(
                        controller: noteController,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          labelText: 'Note Admin',
                          labelStyle: TextStyle(color: Colors.white70),
                          enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.white30),
                          ),
                        ),
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Annulla', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (selectedStylistId.isEmpty || dataInizio == null) {
                      _showErrorMessage('Compila tutti i campi obbligatori');
                      return;
                    }

                    await _saveAssenza(
                      id: assenza?['id'],
                      stylistId: int.parse(selectedStylistId),
                      tipo: selectedTipo,
                      dataInizio: dataInizio!,
                      dataFine: dataFine,
                      oraInizio: oraInizio,
                      oraFine: oraFine,
                      motivo: motivoController.text.trim(),
                      stato: stato,
                      noteAdmin: noteController.text.trim(),
                    );

                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                  ),
                  child: Text(isEditing ? 'Salva' : 'Crea'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  TimeOfDay? _parseTimeOfDay(String? timeStr) {
    if (timeStr == null) return null;
    try {
      String cleanTime = timeStr.split('.').first;
      if (cleanTime.length > 8) {
        cleanTime = cleanTime.substring(0, 8);
      }
      final parts = cleanTime.split(':');
      return TimeOfDay(
        hour: int.parse(parts[0]),
        minute: int.parse(parts[1]),
      );
    } catch (e) {
      return null;
    }
  }

  Future<void> _saveAssenza({
    int? id,
    required int stylistId,
    required String tipo,
    required DateTime dataInizio,
    DateTime? dataFine,
    TimeOfDay? oraInizio,
    TimeOfDay? oraFine,
    required String motivo,
    required String stato,
    required String noteAdmin,
  }) async {
    try {
      final supabase = Supabase.instance.client;

      final data = {
        'stylist_id': stylistId,
        'tipo': tipo,
        'data_inizio': dataInizio.toIso8601String().split('T')[0],
        'data_fine': dataFine?.toIso8601String().split('T')[0],
        'ora_inizio': oraInizio != null
            ? '${oraInizio.hour.toString().padLeft(2, '0')}:${oraInizio.minute.toString().padLeft(2, '0')}:00'
            : null,
        'ora_fine': oraFine != null
            ? '${oraFine.hour.toString().padLeft(2, '0')}:${oraFine.minute.toString().padLeft(2, '0')}:00'
            : null,
        'motivo': motivo.isEmpty ? null : motivo,
        'stato': stato,
        'note_admin': noteAdmin.isEmpty ? null : noteAdmin,
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (id != null) {
        // Aggiorna
        await supabase
            .from('STYLIST_ASSENZE')
            .update(data)
            .eq('id', id);
        _showSuccessMessage('Assenza aggiornata con successo');
      } else {
        // Crea nuovo
        await supabase
            .from('STYLIST_ASSENZE')
            .insert(data);
        _showSuccessMessage('Assenza creata con successo');
      }

      _loadData();

    } catch (e) {
      print('❌ Errore salvataggio assenza: $e');
      _showErrorMessage('Errore nel salvataggio dell\'assenza');
    }
  }

  Future<void> _deleteAssenza(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2d2d2d),
        title: const Text('Conferma Eliminazione', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Sei sicuro di voler eliminare questa assenza?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annulla', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await Supabase.instance.client
            .from('STYLIST_ASSENZE')
            .delete()
            .eq('id', id);

        _showSuccessMessage('Assenza eliminata con successo');
        _loadData();
      } catch (e) {
        print('❌ Errore eliminazione assenza: $e');
        _showErrorMessage('Errore nell\'eliminazione dell\'assenza');
      }
    }
  }

  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
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
          'Gestione Assenze Stylist',
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
          IconButton(
            icon: const Icon(Icons.add, color: Colors.white),
            onPressed: () => _showAssenzaDialog(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Header con filtri e ricerca
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Barra di ricerca
                TextField(
                  controller: _searchController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Cerca per stylist o tipo assenza...',
                    hintStyle: const TextStyle(color: Colors.grey),
                    prefixIcon: const Icon(Icons.search, color: Colors.grey),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                      icon: const Icon(Icons.clear, color: Colors.grey),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _searchQuery = '';
                        });
                      },
                    )
                        : null,
                    filled: true,
                    fillColor: const Color(0xFF2d2d2d),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                ),
                const SizedBox(height: 16),

                // Filtri per stato
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('Tutte', 'tutte'),
                      _buildFilterChip('Richieste', 'richiesto'),
                      _buildFilterChip('Approvate', 'approvato'),
                      _buildFilterChip('Rifiutate', 'rifiutato'),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Lista assenze
          Expanded(
            child: _isLoading
                ? const Center(
              child: CircularProgressIndicator(color: Colors.white),
            )
                : _filteredAssenze.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.event_busy,
                    size: 64,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _searchQuery.isNotEmpty || _selectedFilter != 'tutte'
                        ? 'Nessuna assenza trovata con i filtri selezionati'
                        : 'Nessuna assenza presente',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 16,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
                : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _filteredAssenze.length,
                itemBuilder: (context, index) {
                  final assenza = _filteredAssenze[index];
                  return _buildAssenzaCard(assenza);
                },
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAssenzaDialog(),
        backgroundColor: Colors.blue,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedFilter == value;
    return Container(
      margin: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          setState(() {
            _selectedFilter = value;
          });
        },
        backgroundColor: const Color(0xFF2d2d2d),
        selectedColor: Colors.blue,
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : Colors.grey[300],
        ),
      ),
    );
  }

  Widget _buildAssenzaCard(Map<String, dynamic> assenza) {
    final stylist = assenza['STYLIST'];
    final statusColor = _getStatusColor(assenza['stato']);

    return Card(
      color: const Color(0xFF2d2d2d),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        assenza['STYLIST']['descrizione'],
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _getTipoDisplayName(assenza['tipo']),
                        style: TextStyle(
                          color: Colors.grey[300],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: statusColor),
                  ),
                  child: Text(
                    assenza['stato'].toUpperCase(),
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                PopupMenuButton(
                  icon: const Icon(Icons.more_vert, color: Colors.white),
                  color: const Color(0xFF3d3d3d),
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'edit',
                      child: const Row(
                        children: [
                          Icon(Icons.edit, color: Colors.white, size: 20),
                          SizedBox(width: 8),
                          Text('Modifica', style: TextStyle(color: Colors.white)),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: const Row(
                        children: [
                          Icon(Icons.delete, color: Colors.red, size: 20),
                          SizedBox(width: 8),
                          Text('Elimina', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                  onSelected: (value) {
                    if (value == 'edit') {
                      _showAssenzaDialog(assenza: assenza);
                    } else if (value == 'delete') {
                      _deleteAssenza(assenza['id']);
                    }
                  },
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Dettagli
            Row(
              children: [
                Expanded(
                  child: _buildDetailItem(
                    'Data Inizio',
                    _formatDate(assenza['data_inizio']),
                  ),
                ),
                if (assenza['data_fine'] != null)
                  Expanded(
                    child: _buildDetailItem(
                      'Data Fine',
                      _formatDate(assenza['data_fine']),
                    ),
                  ),
              ],
            ),

            if (assenza['ora_inizio'] != null && assenza['ora_fine'] != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildDetailItem(
                      'Orario',
                      '${_formatTime(assenza['ora_inizio'])} - ${_formatTime(assenza['ora_fine'])}',
                    ),
                  ),
                ],
              ),
            ],

            if (assenza['motivo'] != null && assenza['motivo'].toString().isNotEmpty) ...[
              const SizedBox(height: 8),
              _buildDetailItem('Motivo', assenza['motivo']),
            ],

            if (assenza['note_admin'] != null && assenza['note_admin'].toString().isNotEmpty) ...[
              const SizedBox(height: 8),
              _buildDetailItem('Note Admin', assenza['note_admin']),
            ],

            const SizedBox(height: 8),
            Text(
              'Creata il ${_formatDate(assenza['created_at']?.split('T')[0])}',
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[400],
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}