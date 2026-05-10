import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'matrimonio_richiesta_form.dart';

class MatrimonioEventiPage extends StatefulWidget {
  const MatrimonioEventiPage({Key? key}) : super(key: key);

  @override
  State<MatrimonioEventiPage> createState() => _MatrimonioEventiPageState();
}

class _MatrimonioEventiPageState extends State<MatrimonioEventiPage> {
  bool _isLoading = true;
  Map<String, dynamic>? _richiestaAttiva;

  @override
  void initState() {
    super.initState();
    _checkRichiestaEsistente();
  }

  Future<void> _checkRichiestaEsistente() async {
    try {
      final user = firebase_auth.FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Recupera user_id da tabella USERS
      final userResponse = await Supabase.instance.client
          .from('USERS')
          .select('id')
          .eq('uid', user.uid)
          .single();

      final userId = userResponse['id'];

      // Cerca richieste attive (non annullate, non cancellate)
      final response = await Supabase.instance.client
          .from('MATRIMONIO_RICHIESTE')
          .select('*')
          .eq('user_id', userId)
          .isFilter('deleted_at', null)
          .order('created_at', ascending: false);

      List<Map<String, dynamic>> richieste = List<Map<String, dynamic>>.from(response);

      // Filtra solo quelle non annullate
      richieste = richieste.where((r) => r['stato'] != 'annullato').toList();

      setState(() {
        _richiestaAttiva = richieste.isNotEmpty ? richieste.first : null;
        _isLoading = false;
      });
    } catch (e) {
      print('Errore caricamento richiesta: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1a1a1a),
      appBar: AppBar(
        title: const Text('Matrimoni & Eventi'),
        backgroundColor: const Color(0xFFD4AF37),
      ),
      body: _isLoading
          ? const Center(
        child: CircularProgressIndicator(color: Color(0xFFD4AF37)),
      )
          : _richiestaAttiva != null
          ? _buildRichiestaStatus()
          : _buildServicesView(),
    );
  }

  // ======================================
  // VIEW: Stato della richiesta esistente
  // ======================================
  Widget _buildRichiestaStatus() {
    final stato = _richiestaAttiva!['stato'];
    final visionata = _richiestaAttiva!['visionata_da_admin'] == true;
    final servizioSposa = _richiestaAttiva!['servizio_sposa'] == true;
    final servizioSposo = _richiestaAttiva!['servizio_sposo'] == true;
    final note = _richiestaAttiva!['note'];

    return RefreshIndicator(
      onRefresh: _checkRichiestaEsistente,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Titolo
              const Text(
                'La Tua Richiesta',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Tieni traccia dello stato della tua richiesta',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[400],
                ),
              ),
              const SizedBox(height: 30),

              // Card principale stato
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFFD4AF37).withOpacity(0.2),
                      const Color(0xFF2d2d2d),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFFD4AF37).withOpacity(0.3),
                    width: 2,
                  ),
                ),
                child: Column(
                  children: [
                    // Icona stato
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: _getStatoColor(stato).withOpacity(0.2),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _getStatoColor(stato),
                          width: 3,
                        ),
                      ),
                      child: Icon(
                        _getStatoIcon(stato),
                        size: 40,
                        color: _getStatoColor(stato),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Stato
                    Text(
                      _getStatoLabel(stato),
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: _getStatoColor(stato),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),

                    // Descrizione
                    Text(
                      _getStatoDescrizione(stato),
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.white70,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Timeline stati
              _buildTimeline(stato, visionata),

              const SizedBox(height: 24),

              // Dettagli richiesta
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF2d2d2d),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Dettagli Richiesta',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Servizi richiesti
                    _buildDetailRow('Servizi richiesti:', ''),
                    const SizedBox(height: 8),
                    if (servizioSposa)
                      _buildServiceChip('💍 Acconciature Sposa', Colors.pink),
                    if (servizioSposo)
                      _buildServiceChip('🤵 Acconciature Sposo', Colors.blue),

                    if (note != null && note.toString().isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _buildDetailRow('Note:', ''),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1a1a1a),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          note,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Info contatto
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.blue.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.blue,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        stato == 'confermato'
                            ? 'La tua richiesta è confermata! Ti contatteremo presto per i dettagli.'
                            : 'Sarai contattato telefonicamente per organizzare il servizio.',
                        style: TextStyle(
                          color: Colors.blue[200],
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimeline(String stato, bool visionata) {
    return Column(
      children: [
        _buildTimelineItem(
          'Richiesta Inviata',
          'La tua richiesta è stata ricevuta',
          Icons.send,
          true,
          true,
        ),
        _buildTimelineItem(
          'Visionata',
          'L\'amministratore ha visionato la richiesta',
          Icons.visibility,
          visionata,
          visionata || stato == 'contattato' || stato == 'confermato',
        ),
        _buildTimelineItem(
          'Contattato',
          'Sei stato contattato dall\'amministratore',
          Icons.phone,
          stato == 'contattato' || stato == 'confermato',
          stato == 'confermato',
        ),
        _buildTimelineItem(
          'Confermato',
          'Appuntamento confermato!',
          Icons.check_circle,
          stato == 'confermato',
          false,
          isLast: true,
        ),
      ],
    );
  }

  Widget _buildTimelineItem(
      String title,
      String subtitle,
      IconData icon,
      bool completed,
      bool hasNext, {
        bool isLast = false,
      }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: completed
                    ? const Color(0xFFD4AF37)
                    : const Color(0xFF2d2d2d),
                shape: BoxShape.circle,
                border: Border.all(
                  color: completed
                      ? const Color(0xFFD4AF37)
                      : Colors.grey[600]!,
                  width: 2,
                ),
              ),
              child: Icon(
                completed ? icon : Icons.radio_button_unchecked,
                size: 20,
                color: completed ? Colors.white : Colors.grey[600],
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 40,
                color: hasNext
                    ? const Color(0xFFD4AF37)
                    : Colors.grey[700],
              ),
          ],
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: completed ? Colors.white : Colors.grey[500],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: completed ? Colors.white70 : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
            ),
          ),
        ),
      ],
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
          fontSize: 13,
        ),
      ),
    );
  }

  // ======================================
  // VIEW: Servizi (quando non ha richieste)
  // ======================================
  Widget _buildServicesView() {
    return SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: 15),

          // Titolo sezione
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'MATRIMONI & EVENTI',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
          ),

          const SizedBox(height: 6),

          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Servizi personalizzati per matrimoni e cerimonie',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
          ),

          const SizedBox(height: 20),

          // 💍 CARD SPOSA
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Immagine sposa.png - RIDIMENSIONATA
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                    child: Image.asset(
                      'assets/images/sposa.png',
                      width: double.infinity,
                      height: 100, // ✅ Ancora più piccola
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          height: 100,
                          color: Colors.grey[300],
                          child: const Center(
                            child: Icon(Icons.image, size: 40, color: Colors.grey),
                          ),
                        );
                      },
                    ),
                  ),

                  // Contenuto
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        const Text(
                          '€400,00',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'COIFFURES DE MARIAGE',
                          style: TextStyle(
                            fontSize: 10,
                            letterSpacing: 1.5,
                            color: Colors.grey[700],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildServiceDetail(
                          '• 2 prove acconciatura glamour',
                          Colors.black87,
                        ),
                        const SizedBox(height: 4),
                        _buildServiceDetail(
                          '• 1 trattamento ricostruzione specifico',
                          Colors.black87,
                        ),
                        const SizedBox(height: 4),
                        _buildServiceDetail(
                          '• Acconciatura finale a domicilio',
                          Colors.black87,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // 🤵 CARD SPOSO
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFD4AF37).withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Immagine sposo.png - RIDIMENSIONATA
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                    child: Image.asset(
                      'assets/images/sposo.png',
                      width: double.infinity,
                      height: 100, // ✅ Ancora più piccola
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          height: 100,
                          color: Colors.grey[800],
                          child: const Center(
                            child: Icon(Icons.image, size: 40, color: Colors.grey),
                          ),
                        );
                      },
                    ),
                  ),

                  // Contenuto
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        const Text(
                          '€200,00',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'COIFFURES DE MARIAGE',
                          style: TextStyle(
                            fontSize: 10,
                            letterSpacing: 1.5,
                            color: Colors.grey[400],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildServiceDetail(
                          '• 1 taglio + 2 prove acconciatura',
                          Colors.white70,
                        ),
                        const SizedBox(height: 4),
                        _buildServiceDetail(
                          '• 1 trattamento ristrutturante specifico',
                          Colors.white70,
                        ),
                        const SizedBox(height: 4),
                        _buildServiceDetail(
                          '• Acconciatura finale a domicilio',
                          Colors.white70,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 30),

          // Bottone RICHIEDI INFORMAZIONI
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const MatrimonioRichiestaForm(),
                    ),
                  );
                  // Ricarica dopo invio richiesta
                  _checkRichiestaEsistente();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD4AF37),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 6,
                ),
                child: const Text(
                  'RICHIEDI INFORMAZIONI',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildServiceDetail(String text, Color color) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          color: color,
          height: 1.3,
        ),
      ),
    );
  }

  // ======================================
  // HELPER FUNCTIONS
  // ======================================
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

  IconData _getStatoIcon(String stato) {
    switch (stato) {
      case 'in_attesa':
        return Icons.schedule;
      case 'visionata':
        return Icons.visibility;
      case 'contattato':
        return Icons.phone;
      case 'confermato':
        return Icons.check_circle;
      case 'annullato':
        return Icons.cancel;
      default:
        return Icons.help;
    }
  }

  String _getStatoLabel(String stato) {
    switch (stato) {
      case 'in_attesa':
        return 'In Attesa';
      case 'visionata':
        return 'Visionata';
      case 'contattato':
        return 'Contattato';
      case 'confermato':
        return 'Confermato';
      case 'annullato':
        return 'Annullato';
      default:
        return stato;
    }
  }

  String _getStatoDescrizione(String stato) {
    switch (stato) {
      case 'in_attesa':
        return 'La tua richiesta è in attesa di essere visionata dall\'amministratore';
      case 'visionata':
        return 'L\'amministratore ha visionato la tua richiesta e ti contatterà presto';
      case 'contattato':
        return 'Sei stato contattato! Attendi la conferma finale';
      case 'confermato':
        return 'La tua richiesta è confermata! Ti aspettiamo!';
      case 'annullato':
        return 'La richiesta è stata annullata';
      default:
        return '';
    }
  }
}