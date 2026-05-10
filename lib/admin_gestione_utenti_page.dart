import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminGestioneUtentiPage extends StatefulWidget {
  const AdminGestioneUtentiPage({Key? key}) : super(key: key);

  @override
  State<AdminGestioneUtentiPage> createState() => _AdminGestioneUtentiPageState();
}

class _AdminGestioneUtentiPageState extends State<AdminGestioneUtentiPage> {
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _utenti = [];
  bool _isLoading = false;
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _loadUtenti();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUtenti() async {
    setState(() => _isLoading = true);

    try {
      // ✅ AGGIUNTO FILTRO per escludere segnalazioni cancellate
      final response = await Supabase.instance.client
          .from('USERS')
          .select('''
          id,
          nome,
          cognome,
          email,
          telefono,
          created_at,
          USERS_CREDITI(crediti),
          USERS_SEGNALAZIONI!inner(
            segnalazione_id,
            deleted_at,
            TBS_SEGNALAZIONI(descrizione)
          )
        ''')
          .neq('role', 'admin')
          .order('created_at', ascending: false);

      // ✅ FILTRA manualmente le segnalazioni attive (deleted_at = null)
      final utentiFiltrati = response.map((user) {
        final segnalazioni = user['USERS_SEGNALAZIONI'] as List?;
        if (segnalazioni != null) {
          user['USERS_SEGNALAZIONI'] = segnalazioni
              .where((s) => s['deleted_at'] == null)
              .toList();
        }
        return user;
      }).toList();

      setState(() {
        _utenti = List<Map<String, dynamic>>.from(utentiFiltrati);
        _isLoading = false;
      });
    } catch (e) {
      print('Errore caricamento utenti: $e');
      setState(() => _isLoading = false);

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

  Future<void> _searchUtenti(String query) async {
    if (query.trim().isEmpty) {
      _loadUtenti();
      return;
    }

    setState(() => _isSearching = true);

    try {
      final response = await Supabase.instance.client
          .from('USERS')
          .select('''
          id,
          nome,
          cognome,
          email,
          telefono,
          created_at,
          USERS_CREDITI(crediti),
          USERS_SEGNALAZIONI(
            segnalazione_id,
            deleted_at,
            TBS_SEGNALAZIONI(descrizione)
          )
        ''')
          .neq('role', 'admin')
          .or('nome.ilike.%$query%,cognome.ilike.%$query%,email.ilike.%$query%,telefono.ilike.%$query%');

      // ✅ FILTRA manualmente le segnalazioni attive
      final utentiFiltrati = response.map((user) {
        final segnalazioni = user['USERS_SEGNALAZIONI'] as List?;
        if (segnalazioni != null) {
          user['USERS_SEGNALAZIONI'] = segnalazioni
              .where((s) => s['deleted_at'] == null)
              .toList();
        }
        return user;
      }).toList();

      setState(() {
        _utenti = List<Map<String, dynamic>>.from(utentiFiltrati);
        _isSearching = false;
      });
    } catch (e) {
      print('Errore ricerca: $e');
      setState(() => _isSearching = false);
    }
  }


  int _getTotalCrediti(Map<String, dynamic> user) {
    final crediti = user['USERS_CREDITI'] as List?;
    if (crediti == null || crediti.isEmpty) return 0;

    return crediti.fold<int>(0, (sum, item) {
      final creditiValue = item['crediti'];
      if (creditiValue is num) {
        return sum + creditiValue.toInt();
      }
      return sum;
    });
  }

  int? _getSegnalazioneId(Map<String, dynamic> user) {
    final segnalazioni = user['USERS_SEGNALAZIONI'] as List?;
    if (segnalazioni == null || segnalazioni.isEmpty) return null;

    // Prendi l'ultima segnalazione (più recente)
    final ultimaSegnalazione = segnalazioni.last;
    return ultimaSegnalazione['segnalazione_id'];
  }

  Color _getSegnalazioneColor(int? segnalazioneId) {
    if (segnalazioneId == null) return Colors.green;
    if (segnalazioneId == 1) return Colors.orange;
    if (segnalazioneId == 2) return Colors.red;
    return Colors.grey;
  }

  String _getSegnalazioneLabel(int? segnalazioneId) {
    if (segnalazioneId == null) return 'Nessuna';
    if (segnalazioneId == 1) return 'Pagamento Bloccato';
    if (segnalazioneId == 2) return 'Account Bloccato';
    return 'Sconosciuto';
  }

  void _mostraDialogCrediti(Map<String, dynamic> user) {
    final creditiAttuali = _getTotalCrediti(user);
    final creditiController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2d2d2d),
        title: Text(
          'Gestisci Crediti - ${user['nome']} ${user['cognome']}',
          style: const TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Crediti attuali: $creditiAttuali',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: creditiController,
              keyboardType: const TextInputType.numberWithOptions(signed: true, decimal: false),  // ✅ CORRETTO
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Crediti da aggiungere/rimuovere',
                labelStyle: TextStyle(color: Colors.grey),
                hintText: 'Es: 5 o -10',
                hintStyle: TextStyle(color: Colors.grey),
                border: OutlineInputBorder(),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.grey),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFFD4AF37)),
                ),
              ),
            )
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annulla'),
          ),
          ElevatedButton(
            onPressed: () async {
              final crediti = int.tryParse(creditiController.text);
              if (crediti == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Inserisci un numero valido'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              Navigator.pop(context);
              await _aggiungiCrediti(user['id'], crediti);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD4AF37),
            ),
            child: const Text('Conferma'),
          ),
        ],
      ),
    );
  }

  Future<void> _aggiungiCrediti(int userId, int crediti) async {
    try {
      print('💰 Aggiunta crediti: $crediti a user $userId');

      // Inserisci crediti
      await Supabase.instance.client
          .from('USERS_CREDITI')
          .insert({
        'users_id': userId,
        'crediti': crediti,
      });

      print('✅ Crediti inseriti nel database');

      // ✅ Calcola totale crediti dopo l'aggiunta
      final creditiResponse = await Supabase.instance.client
          .from('USERS_CREDITI')
          .select('crediti')
          .eq('users_id', userId)
          .isFilter('deleted_at', null);

      List<Map<String, dynamic>> creditiList = List<Map<String, dynamic>>.from(creditiResponse);

      final totalCrediti = creditiList.fold<int>(0, (sum, item) {
        final creditiValue = item['crediti'];
        if (creditiValue is num) {
          return sum + creditiValue.toInt();
        }
        return sum;
      });

      print('📊 Totale crediti dopo aggiunta: $totalCrediti');

      // ✅ Se ha raggiunto 50 crediti, la Edge Function assign-credits gestisce già la notifica!
      // Ma per sicurezza, se l'admin assegna crediti manualmente, possiamo forzare il controllo:
      if (totalCrediti >= 50) {
        print('🎉 User $userId ha raggiunto 50 crediti!');

        // Recupera Firebase UID e nome utente
        final userResponse = await Supabase.instance.client
            .from('USERS')
            .select('uid, nome, cognome')
            .eq('id', userId)
            .single();

        if (userResponse['uid'] != null) {
          print('📤 Invio notifica 50 crediti...');

          // Usa la stessa logica di assign-credits: salva notifica + invia OneSignal
          try {
            // Salva nel database per la campanellina
            await Supabase.instance.client.from('user_notifications').insert({
              'user_id': userId,
              'title': '🎉 Hai raggiunto 50 crediti!',
              'message': 'Complimenti! Hai accumulato 50 crediti e hai diritto ad uno sconto generoso su un prodotto a scelta!',
              'type': 'crediti_milestone',
              'read': false,
            });

            print('✅ Notifica salvata nel database');

            // Invia notifica OneSignal chiamando una funzione separata
            // (Riutilizziamo la stessa Edge Function usata dal cron job)
            await Supabase.instance.client.functions.invoke(
              'send-milestone-notification',
              body: {
                'firebase_uid': userResponse['uid'],
                'user_name': '${userResponse['nome']} ${userResponse['cognome']}',
                'total_crediti': totalCrediti,
              },
            );

            print('✅ Notifica OneSignal inviata');

          } catch (notifError) {
            print('⚠️ Errore invio notifica (non critico): $notifError');
            // Non blocchiamo il flusso se la notifica fallisce
          }
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                crediti > 0
                    ? '✅ Aggiunti $crediti crediti (Totale: $totalCrediti)'
                    : '✅ Rimossi ${crediti.abs()} crediti (Totale: $totalCrediti)'
            ),
            backgroundColor: Colors.green,
          ),
        );
      }

      _loadUtenti();
    } catch (e) {
      print('❌ Errore aggiunta crediti: $e');
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

  void _mostraDialogSegnalazione(Map<String, dynamic> user) {
    final segnalazioneAttuale = _getSegnalazioneId(user);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2d2d2d),
        title: Text(
          'Gestisci Segnalazione - ${user['nome']} ${user['cognome']}',
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Stato attuale: ${_getSegnalazioneLabel(segnalazioneAttuale)}',
              style: TextStyle(
                color: _getSegnalazioneColor(segnalazioneAttuale),
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Seleziona azione:',
              style: TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 12),

            // Nessuna segnalazione
            ListTile(
              tileColor: Colors.green.withOpacity(0.2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              leading: const Icon(Icons.check_circle, color: Colors.green),
              title: const Text(
                'Nessuna segnalazione',
                style: TextStyle(color: Colors.white),
              ),
              subtitle: const Text(
                'Utente regolare',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
              onTap: () {
                Navigator.pop(context);
                _applicaSegnalazione(user['id'], null);
              },
            ),
            const SizedBox(height: 8),

            // Livello 1
            ListTile(
              tileColor: Colors.orange.withOpacity(0.2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              leading: const Icon(Icons.warning, color: Colors.orange),
              title: const Text(
                'Blocca pagamento in loco',
                style: TextStyle(color: Colors.white),
              ),
              subtitle: const Text(
                'Può prenotare solo con carta',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
              onTap: () {
                Navigator.pop(context);
                _applicaSegnalazione(user['id'], 1);
              },
            ),
            const SizedBox(height: 8),

            // Livello 2
            ListTile(
              tileColor: Colors.red.withOpacity(0.2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              leading: const Icon(Icons.block, color: Colors.red),
              title: const Text(
                'Blocca account',
                style: TextStyle(color: Colors.white),
              ),
              subtitle: const Text(
                'Non può accedere all\'app',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
              onTap: () {
                Navigator.pop(context);
                _applicaSegnalazione(user['id'], 2);
              },
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

  Future<void> _applicaSegnalazione(int userId, int? segnalazioneId) async {
    try {
      if (segnalazioneId == null) {
        // Rimuovi tutte le segnalazioni
        await Supabase.instance.client
            .from('USERS_SEGNALAZIONI')
            .update({'deleted_at': DateTime.now().toIso8601String()})
            .eq('users_id', userId)
            .isFilter('deleted_at', null);

        // Ripristina i crediti se aveva perso tutti
        // (opzionale, decidi tu)
      } else {
        // Rimuovi segnalazioni precedenti
        await Supabase.instance.client
            .from('USERS_SEGNALAZIONI')
            .update({'deleted_at': DateTime.now().toIso8601String()})
            .eq('users_id', userId)
            .isFilter('deleted_at', null);

        // Aggiungi nuova segnalazione
        await Supabase.instance.client
            .from('USERS_SEGNALAZIONI')
            .insert({
          'users_id': userId,
          'segnalazione_id': segnalazioneId,
        });

        // Se segnalato, azzera i crediti
        await Supabase.instance.client
            .from('USERS_CREDITI')
            .insert({
          'users_id': userId,
          'crediti': -_getTotalCrediti(_utenti.firstWhere((u) => u['id'] == userId)),
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Segnalazione ${segnalazioneId == null ? "rimossa" : "applicata"}'),
            backgroundColor: Colors.green,
          ),
        );
      }

      _loadUtenti();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1a1a1a),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2d2d2d),
        title: const Text('Gestione Utenti'),
        actions: [
          IconButton(
            onPressed: _loadUtenti,
            icon: const Icon(Icons.refresh),
            tooltip: 'Aggiorna',
          ),
        ],
      ),
      body: Column(
        children: [
          // Barra ricerca
          Container(
            padding: const EdgeInsets.all(16),
            color: const Color(0xFF2d2d2d),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Cerca utente (nome, email, telefono)...',
                hintStyle: const TextStyle(color: Colors.grey),
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                  icon: const Icon(Icons.clear, color: Colors.grey),
                  onPressed: () {
                    _searchController.clear();
                    _loadUtenti();
                  },
                )
                    : null,
                filled: true,
                fillColor: const Color(0xFF1a1a1a),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (value) {
                if (value.length >= 2 || value.isEmpty) {
                  _searchUtenti(value);
                }
              },
            ),
          ),

          // Lista utenti
          Expanded(
            child: _isLoading
                ? const Center(
              child: CircularProgressIndicator(color: Colors.white),
            )
                : _utenti.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.people_outline,
                    size: 64,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Nessun utente trovato',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            )
                : RefreshIndicator(
              onRefresh: _loadUtenti,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _utenti.length,
                itemBuilder: (context, index) {
                  final user = _utenti[index];
                  final crediti = _getTotalCrediti(user);
                  final segnalazione = _getSegnalazioneId(user);

                  return Card(
                    color: const Color(0xFF2d2d2d),
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Nome e badge segnalazione
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${user['nome']} ${user['cognome']}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              if (segnalazione != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _getSegnalazioneColor(segnalazione)
                                        .withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: _getSegnalazioneColor(segnalazione),
                                    ),
                                  ),
                                  child: Text(
                                    _getSegnalazioneLabel(segnalazione),
                                    style: TextStyle(
                                      color: _getSegnalazioneColor(segnalazione),
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          // Email e telefono
                          if (user['email'] != null)
                            Row(
                              children: [
                                const Icon(
                                  Icons.email,
                                  size: 16,
                                  color: Colors.grey,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  user['email'],
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          if (user['telefono'] != null) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(
                                  Icons.phone,
                                  size: 16,
                                  color: Colors.grey,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  user['telefono'],
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 12),

                          // Crediti
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFD4AF37).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.stars,
                                  size: 18,
                                  color: Color(0xFFD4AF37),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '$crediti crediti',
                                  style: const TextStyle(
                                    color: Color(0xFFD4AF37),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Bottoni azione
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => _mostraDialogCrediti(user),
                                  icon: const Icon(Icons.add, size: 18),
                                  label: const Text('Crediti'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFFD4AF37),
                                    side: const BorderSide(
                                      color: Color(0xFFD4AF37),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () => _mostraDialogSegnalazione(user),
                                  icon: const Icon(Icons.flag, size: 18),
                                  label: const Text('Segnalazione'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.orange,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}