import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class AdminOrariEccezioniPage extends StatefulWidget {
  const AdminOrariEccezioniPage({Key? key}) : super(key: key);

  @override
  State<AdminOrariEccezioniPage> createState() => _AdminOrariEccezioniPageState();
}

class _AdminOrariEccezioniPageState extends State<AdminOrariEccezioniPage> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> eccezioni = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _caricaEccezioni();
  }

  Future<void> _caricaEccezioni() async {
    setState(() => isLoading = true);
    try {
      final response = await supabase
          .from('orari_eccezioni')
          .select()
          .order('data', ascending: true);

      setState(() {
        eccezioni = List<Map<String, dynamic>>.from(response);
        isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore: $e')),
        );
      }
      setState(() => isLoading = false);
    }
  }

  Future<void> _aggiungiEccezione() async {
    DateTime? selectedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      locale: const Locale('it', 'IT'),
    );

    if (selectedDate == null || !mounted) return;

    String? tipo = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tipo di Eccezione'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.block, color: Colors.red),
              title: const Text('Chiuso tutto il giorno'),
              subtitle: const Text('Il salone sarà completamente chiuso'),
              onTap: () => Navigator.pop(context, 'chiuso'),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.wb_sunny, color: Colors.orange),
              title: const Text('Solo Mattina'),
              subtitle: const Text('Aperto solo al mattino'),
              onTap: () => Navigator.pop(context, 'solo_mattina'),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.nights_stay, color: Colors.blue),
              title: const Text('Solo Pomeriggio'),
              subtitle: const Text('Aperto solo al pomeriggio'),
              onTap: () => Navigator.pop(context, 'solo_pomeriggio'),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.schedule, color: Colors.green),
              title: const Text('Orario Personalizzato'),
              subtitle: const Text('Imposta orari specifici'),
              onTap: () => Navigator.pop(context, 'orario_ridotto'),
            ),
          ],
        ),
      ),
    );

    if (tipo == null || !mounted) return;

    TimeOfDay? aperturaMattina;
    TimeOfDay? chiusuraMattina;
    TimeOfDay? aperturaPomeriggio;
    TimeOfDay? chiusuraPomeriggio;

    if (tipo == 'solo_mattina') {
      aperturaMattina = await _showTimePicker('Apertura Mattina', const TimeOfDay(hour: 8, minute: 30));
      if (aperturaMattina == null || !mounted) return;

      chiusuraMattina = await _showTimePicker('Chiusura Mattina', const TimeOfDay(hour: 13, minute: 0));
      if (chiusuraMattina == null || !mounted) return;

    } else if (tipo == 'solo_pomeriggio') {
      aperturaPomeriggio = await _showTimePicker('Apertura Pomeriggio', const TimeOfDay(hour: 16, minute: 0));
      if (aperturaPomeriggio == null || !mounted) return;

      chiusuraPomeriggio = await _showTimePicker('Chiusura Pomeriggio', const TimeOfDay(hour: 20, minute: 0));
      if (chiusuraPomeriggio == null || !mounted) return;

    } else if (tipo == 'orario_ridotto') {
      // Chiedi se vuole orario mattina
      final bool? vuoleMattina = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Turno Mattina'),
          content: const Text('Vuoi impostare un orario per la mattina?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('No'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Sì'),
            ),
          ],
        ),
      );

      if (vuoleMattina == true) {
        aperturaMattina = await _showTimePicker('Apertura Mattina', const TimeOfDay(hour: 8, minute: 30));
        if (aperturaMattina == null || !mounted) return;

        chiusuraMattina = await _showTimePicker('Chiusura Mattina', const TimeOfDay(hour: 13, minute: 0));
        if (chiusuraMattina == null || !mounted) return;
      }

      // Chiedi se vuole orario pomeriggio
      final bool? vuolePomeriggio = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Turno Pomeriggio'),
          content: const Text('Vuoi impostare un orario per il pomeriggio?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('No'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Sì'),
            ),
          ],
        ),
      );

      if (vuolePomeriggio == true) {
        aperturaPomeriggio = await _showTimePicker('Apertura Pomeriggio', const TimeOfDay(hour: 16, minute: 0));
        if (aperturaPomeriggio == null || !mounted) return;

        chiusuraPomeriggio = await _showTimePicker('Chiusura Pomeriggio', const TimeOfDay(hour: 20, minute: 0));
        if (chiusuraPomeriggio == null || !mounted) return;
      }
    }

    // Chiedi un motivo opzionale
    String? motivo;
    if (mounted) {
      final TextEditingController motivoController = TextEditingController();
      motivo = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Motivo (opzionale)'),
          content: TextField(
            controller: motivoController,
            decoration: const InputDecoration(
              hintText: 'Es: Vigilia di Natale',
            ),
            maxLength: 100,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text('Salta'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, motivoController.text),
              child: const Text('Salva'),
            ),
          ],
        ),
      );
    }

    if (!mounted) return;

    try {
      final data = {
        'data': DateFormat('yyyy-MM-dd').format(selectedDate),
        'tipo': tipo,
        'orario_apertura_mattina': aperturaMattina != null
            ? '${aperturaMattina.hour.toString().padLeft(2, '0')}:${aperturaMattina.minute.toString().padLeft(2, '0')}'
            : null,
        'orario_chiusura_mattina': chiusuraMattina != null
            ? '${chiusuraMattina.hour.toString().padLeft(2, '0')}:${chiusuraMattina.minute.toString().padLeft(2, '0')}'
            : null,
        'orario_apertura_pomeriggio': aperturaPomeriggio != null
            ? '${aperturaPomeriggio.hour.toString().padLeft(2, '0')}:${aperturaPomeriggio.minute.toString().padLeft(2, '0')}'
            : null,
        'orario_chiusura_pomeriggio': chiusuraPomeriggio != null
            ? '${chiusuraPomeriggio.hour.toString().padLeft(2, '0')}:${chiusuraPomeriggio.minute.toString().padLeft(2, '0')}'
            : null,
        'motivo': motivo?.isEmpty == true ? null : motivo,
      };

      await supabase.from('orari_eccezioni').upsert(data);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Eccezione salvata con successo'),
            backgroundColor: Colors.green,
          ),
        );
        _caricaEccezioni();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<TimeOfDay?> _showTimePicker(String title, TimeOfDay initialTime) async {
    return await showDialog<TimeOfDay>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Seleziona l\'orario'),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () async {
                final time = await showTimePicker(
                  context: context,
                  initialTime: initialTime,
                  builder: (context, child) {
                    return MediaQuery(
                      data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
                      child: child!,
                    );
                  },
                );
                if (time != null && context.mounted) {
                  Navigator.pop(context, time);
                }
              },
              icon: const Icon(Icons.access_time),
              label: const Text('Scegli orario'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annulla'),
          ),
        ],
      ),
    );
  }

  Future<void> _eliminaEccezione(int id) async {
    final conferma = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Conferma eliminazione'),
        content: const Text('Sei sicuro di voler eliminare questa eccezione?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annulla'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );

    if (conferma != true || !mounted) return;

    try {
      await supabase.from('orari_eccezioni').delete().eq('id', id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Eccezione eliminata')),
        );
        _caricaEccezioni();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestione Orari e Chiusure'),
        backgroundColor: Colors.brown,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : eccezioni.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.calendar_today, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Nessuna eccezione configurata',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              'Orario standard:\nMar-Sab 8:30-13:00 / 16:00-20:00',
              style: TextStyle(color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      )
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: eccezioni.length,
        itemBuilder: (context, index) {
          final eccezione = eccezioni[index];
          final data = DateTime.parse(eccezione['data']);
          final tipo = eccezione['tipo'];

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            elevation: 2,
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: CircleAvatar(
                backgroundColor: _getColoreTipo(tipo),
                child: Icon(
                  _getIconaTipo(tipo),
                  color: Colors.white,
                ),
              ),
              title: Text(
                DateFormat('EEEE, d MMMM yyyy', 'it_IT').format(data),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_getDescrizioneEccezione(eccezione)),
                    if (eccezione['motivo'] != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Motivo: ${eccezione['motivo']}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () => _eliminaEccezione(eccezione['id']),
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _aggiungiEccezione,
        backgroundColor: Colors.brown,
        icon: const Icon(Icons.add),
        label: const Text('Aggiungi Eccezione'),
      ),
    );
  }

  Color _getColoreTipo(String tipo) {
    switch (tipo) {
      case 'chiuso':
        return Colors.red;
      case 'solo_mattina':
        return Colors.orange;
      case 'solo_pomeriggio':
        return Colors.blue;
      case 'orario_ridotto':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  IconData _getIconaTipo(String tipo) {
    switch (tipo) {
      case 'chiuso':
        return Icons.block;
      case 'solo_mattina':
        return Icons.wb_sunny;
      case 'solo_pomeriggio':
        return Icons.nights_stay;
      case 'orario_ridotto':
        return Icons.schedule;
      default:
        return Icons.info;
    }
  }

  String _getDescrizioneEccezione(Map<String, dynamic> eccezione) {
    switch (eccezione['tipo']) {
      case 'chiuso':
        return 'CHIUSO TUTTO IL GIORNO';
      case 'solo_mattina':
        return 'Solo mattina: ${eccezione['orario_apertura_mattina']} - ${eccezione['orario_chiusura_mattina']}';
      case 'solo_pomeriggio':
        return 'Solo pomeriggio: ${eccezione['orario_apertura_pomeriggio']} - ${eccezione['orario_chiusura_pomeriggio']}';
      case 'orario_ridotto':
        String desc = '';
        if (eccezione['orario_apertura_mattina'] != null) {
          desc += 'Mattina: ${eccezione['orario_apertura_mattina']} - ${eccezione['orario_chiusura_mattina']}';
        }
        if (eccezione['orario_apertura_pomeriggio'] != null) {
          if (desc.isNotEmpty) desc += '\n';
          desc += 'Pomeriggio: ${eccezione['orario_apertura_pomeriggio']} - ${eccezione['orario_chiusura_pomeriggio']}';
        }
        return desc;
      default:
        return '';
    }
  }
}