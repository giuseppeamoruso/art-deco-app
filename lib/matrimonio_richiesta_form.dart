import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MatrimonioRichiestaForm extends StatefulWidget {
  const MatrimonioRichiestaForm({Key? key}) : super(key: key);

  @override
  State<MatrimonioRichiestaForm> createState() => _MatrimonioRichiestaFormState();
}

class _MatrimonioRichiestaFormState extends State<MatrimonioRichiestaForm> {
  final _formKey = GlobalKey<FormState>();
  final _telefonoController = TextEditingController();
  final _noteController = TextEditingController();

  bool _servizioSposa = false;
  bool _servizioSposo = false;
  bool _isLoading = false;
  bool _isLoadingData = true;
  String? _errorMessage;

  String _nome = '';
  String _cognome = '';
  String _telefono = '';
  int? _userId;

  @override
  void initState() {
    super.initState();
    print('🚀 MatrimonioRichiestaForm - initState');
    _loadUserData();
  }

  @override
  void dispose() {
    _telefonoController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    print('🔍 Inizio caricamento dati utente...');

    try {
      // ✅ USA FIREBASE AUTH invece di Supabase Auth
      final user = firebase_auth.FirebaseAuth.instance.currentUser;
      print('👤 Firebase User ID: ${user?.uid}');

      if (user == null) {
        print('❌ Utente non autenticato!');
        setState(() {
          _errorMessage = 'Utente non autenticato';
          _isLoadingData = false;
        });
        return;
      }

      print('📡 Chiamata a Supabase USERS con Firebase UID...');

      // Recupera dati da tabella USERS usando Firebase UID
      final response = await Supabase.instance.client
          .from('USERS')
          .select('id, nome, cognome, telefono')
          .eq('uid', user.uid)  // ✅ Firebase UID
          .single()
          .timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Timeout: impossibile caricare i dati');
        },
      );

      print('✅ Risposta ricevuta: $response');

      if (mounted) {
        setState(() {
          _userId = response['id'];
          _nome = response['nome'] ?? '';
          _cognome = response['cognome'] ?? '';
          _telefono = response['telefono'] ?? '';
          _telefonoController.text = _telefono;
          _isLoadingData = false;
          _errorMessage = null;
        });

        print('✅ Dati caricati con successo!');
        print('   User ID: $_userId');
        print('   Nome: $_nome');
        print('   Cognome: $_cognome');
        print('   Telefono: $_telefono');
      }

    } catch (e) {
      print('❌ ERRORE caricamento dati: $e');

      if (mounted) {
        setState(() {
          _errorMessage = 'Errore: $e';
          _isLoadingData = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore caricamento dati: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  /// Invia la richiesta
  Future<void> _inviaRichiesta() async {
    print('📤 Invio richiesta...');

    if (!_formKey.currentState!.validate()) {
      print('❌ Form non valido');
      return;
    }

    // Verifica che almeno un servizio sia selezionato
    if (!_servizioSposa && !_servizioSposo) {
      print('⚠️ Nessun servizio selezionato');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Seleziona almeno un servizio'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // ✅ CONTROLLO: Verifica se esiste già una richiesta attiva
      print('1️⃣ Controllo richieste esistenti...');

      final existing = await Supabase.instance.client
          .from('MATRIMONIO_RICHIESTE')
          .select('id, stato')
          .eq('user_id', _userId!)
          .isFilter('deleted_at', null);

      List<Map<String, dynamic>> richiesteAttive = List<Map<String, dynamic>>.from(existing);

      // Filtra solo richieste non annullate
      richiesteAttive = richiesteAttive.where((r) => r['stato'] != 'annullato').toList();

      if (richiesteAttive.isNotEmpty) {
        print('⚠️ Richiesta già esistente!');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('⚠️ Hai già una richiesta attiva! Attendi che venga processata.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 4),
            ),
          );
          setState(() => _isLoading = false);
        }
        return;
      }

      print('2️⃣ Inserimento nel database...');

      // 1. Inserisci richiesta nel database
      final richiestaResponse = await Supabase.instance.client
          .from('MATRIMONIO_RICHIESTE')
          .insert({
        'user_id': _userId,
        'nome': _nome,
        'cognome': _cognome,
        'telefono': _telefonoController.text.trim(),
        'servizio_sposa': _servizioSposa,
        'servizio_sposo': _servizioSposo,
        'note': _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
        'stato': 'in_attesa',
        'visionata_da_admin': false,
      })
          .select('id')
          .single();

      final richiestaId = richiestaResponse['id'];
      print('✅ Richiesta inserita con ID: $richiestaId');

      print('3️⃣ Invio notifica admin...');

      // 2. Chiama Edge Function per notificare gli admin
      try {
        await Supabase.instance.client.functions.invoke(
          'notify-matrimonio',
          body: {
            'type': 'new_request',
            'richiesta_id': richiestaId,
          },
        );
        print('✅ Notifica inviata');
      } catch (notifError) {
        print('⚠️ Errore notifica (non bloccante): $notifError');
        // Non blocchiamo il flusso se la notifica fallisce
      }

      if (mounted) {
        print('✅ Tutto completato con successo!');

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Richiesta inviata con successo!'),
            backgroundColor: Colors.green,
          ),
        );

        // Torna indietro
        Navigator.pop(context);
      }
    } catch (e) {
      print('❌ ERRORE invio richiesta: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore invio richiesta: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    print('🎨 Build widget - Loading: $_isLoadingData, Error: $_errorMessage');

    return Scaffold(
      backgroundColor: const Color(0xFF1a1a1a),
      appBar: AppBar(
        title: const Text('Richiesta Info Matrimonio'),
        backgroundColor: const Color(0xFFD4AF37),
      ),
      body: _isLoadingData
          ? const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Color(0xFFD4AF37)),
            SizedBox(height: 16),
            Text(
              'Caricamento dati...',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
      )
          : _errorMessage != null
          ? Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                color: Colors.red,
                size: 64,
              ),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.white),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _isLoadingData = true;
                    _errorMessage = null;
                  });
                  _loadUserData();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD4AF37),
                ),
                child: const Text('Riprova'),
              ),
            ],
          ),
        ),
      )
          : SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Intestazione
              const Text(
                'Compila il modulo per richiedere informazioni sui nostri servizi per matrimoni',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 30),

              // Nome (readonly)
              TextFormField(
                initialValue: _nome,
                style: const TextStyle(color: Colors.white70),
                decoration: const InputDecoration(
                  labelText: 'Nome',
                  labelStyle: TextStyle(color: Colors.grey),
                  border: OutlineInputBorder(),
                  suffixIcon: Icon(Icons.lock, size: 18, color: Colors.grey),
                  disabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey),
                  ),
                ),
                enabled: false,
              ),
              const SizedBox(height: 15),

              // Cognome (readonly)
              TextFormField(
                initialValue: _cognome,
                style: const TextStyle(color: Colors.white70),
                decoration: const InputDecoration(
                  labelText: 'Cognome',
                  labelStyle: TextStyle(color: Colors.grey),
                  border: OutlineInputBorder(),
                  suffixIcon: Icon(Icons.lock, size: 18, color: Colors.grey),
                  disabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey),
                  ),
                ),
                enabled: false,
              ),
              const SizedBox(height: 15),

              // Telefono (editabile)
              TextFormField(
                controller: _telefonoController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Telefono *',
                  labelStyle: TextStyle(color: Colors.grey),
                  border: OutlineInputBorder(),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFFD4AF37)),
                  ),
                  prefixIcon: Icon(Icons.phone, color: Colors.grey),
                  hintText: 'Es: 333-1234567',
                  hintStyle: TextStyle(color: Colors.grey),
                ),
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Il telefono è obbligatorio';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 25),

              // Servizi richiesti
              const Text(
                'Servizi richiesti:',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 10),

              // Checkbox Sposa
              CheckboxListTile(
                title: const Text(
                  '💍 Acconciature Sposa (€400)',
                  style: TextStyle(color: Colors.white),
                ),
                subtitle: const Text(
                  '2 prove acconciatura glamour, trattamento ricostruzione, acconciatura finale',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                value: _servizioSposa,
                onChanged: (value) {
                  setState(() => _servizioSposa = value ?? false);
                },
                activeColor: const Color(0xFFD4AF37),
              ),

              // Checkbox Sposo
              CheckboxListTile(
                title: const Text(
                  '🤵 Acconciature Sposo (€200)',
                  style: TextStyle(color: Colors.white),
                ),
                subtitle: const Text(
                  '1 taglio, 2 prove acconciatura, trattamento ristrutturante, acconciatura finale',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                value: _servizioSposo,
                onChanged: (value) {
                  setState(() => _servizioSposo = value ?? false);
                },
                activeColor: const Color(0xFFD4AF37),
              ),

              const SizedBox(height: 20),

              // Note aggiuntive
              TextFormField(
                controller: _noteController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Note aggiuntive (facoltativo)',
                  labelStyle: TextStyle(color: Colors.grey),
                  border: OutlineInputBorder(),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFFD4AF37)),
                  ),
                  hintText: 'Es: data prevista, richieste particolari...',
                  hintStyle: TextStyle(color: Colors.grey),
                  alignLabelWithHint: true,
                ),
                maxLines: 4,
              ),
              const SizedBox(height: 30),

              // Bottone Invio
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _inviaRichiesta,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD4AF37),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                    'INVIA RICHIESTA',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}