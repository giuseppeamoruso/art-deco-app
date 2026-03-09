import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'admin_appointments_page.dart';
import 'admin_gestione_utenti_page.dart';
import 'login_page.dart';
import 'admin_new_appointment_page.dart';
import 'stylist_assenze_admin_page.dart';
import 'admin_orari_eccezioni_page.dart';
import 'admin_matrimonio_richieste_page.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  bool _isLoading = true;
  Map<String, dynamic>? _adminData;
  Map<String, int> _todayStats = {
    'appointments': 0,
    'revenue': 0,
    'pending': 0,
    'completed': 0,
  };
  int _richiesteMatrimoniNonViste = 0;

  @override
  void initState() {
    super.initState();
    _loadAdminData();
    _loadTodayStats();
    _loadRichiesteMatrimoni();
  }

  Future<void> _loadAdminData() async {
    try {
      final user = firebase_auth.FirebaseAuth.instance.currentUser;
      if (user == null) {
        _navigateToLogin();
        return;
      }

      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('USERS')
          .select('nome, cognome, email, role')
          .eq('uid', user.uid)
          .single();

      setState(() {
        _adminData = response;
        _isLoading = false;
      });

    } catch (e) {
      print('Errore caricamento dati admin: $e');
      if (mounted) {
        _showErrorMessage('Errore nel caricamento dei dati');
        _navigateToLogin();
      }
    }
  }

  Future<void> _loadTodayStats() async {
    try {
      final today = DateTime.now();
      final todayString = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

      final supabase = Supabase.instance.client;

      // Appuntamenti di oggi
      final appointmentsResponse = await supabase
          .from('APPUNTAMENTI')
          .select('prezzo_totale')
          .eq('data', todayString);

      // Calcola statistiche
      final appointments = appointmentsResponse;
      final totalRevenue = appointments.fold<double>(0, (sum, app) => sum + (app['prezzo_totale'] ?? 0));

      setState(() {
        _todayStats = {
          'appointments': appointments.length,
          'revenue': totalRevenue.round(),
          'pending': appointments.length,
          'completed': 0,
        };
      });

    } catch (e) {
      print('Errore caricamento statistiche: $e');
    }
  }

  Future<void> _loadRichiesteMatrimoni() async {
    try {
      final supabase = Supabase.instance.client;

      final response = await supabase
          .from('MATRIMONIO_RICHIESTE')
          .select()
          .isFilter('deleted_at', null);

      List<Map<String, dynamic>> richieste = List<Map<String, dynamic>>.from(response);

      // Conta quelle non viste
      int nonViste = richieste.where((r) => r['visionata_da_admin'] == false).length;

      setState(() {
        _richiesteMatrimoniNonViste = nonViste;
      });
    } catch (e) {
      print('Errore caricamento richieste matrimoni: $e');
    }
  }

  Future<void> _logout() async {
    try {
      await firebase_auth.FirebaseAuth.instance.signOut();
      _navigateToLogin();
    } catch (e) {
      _showErrorMessage('Errore durante il logout');
    }
  }

  void _navigateToLogin() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginPage()),
          (route) => false,
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

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2d2d2d),
        title: const Text(
          'Conferma Logout',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Sei sicuro di voler uscire dal pannello amministratore?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annulla', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _logout();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Esci'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF1a1a1a),
        body: Center(
          child: CircularProgressIndicator(color: Colors.red),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF1a1a1a),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2d2d2d),
        elevation: 0,
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.admin_panel_settings,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Admin Dashboard',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Benvenuto ${_adminData?['nome'] ?? 'Admin'}',
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () {
              _loadTodayStats();
              _loadRichiesteMatrimoni();
            },
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Aggiorna',
          ),
          IconButton(
            onPressed: _showLogoutDialog,
            icon: const Icon(Icons.logout, color: Colors.white),
            tooltip: 'Logout',
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: Colors.red,
          onRefresh: () async {
            await _loadTodayStats();
            await _loadRichiesteMatrimoni();
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Statistiche di oggi
                _buildTodayStatsSection(),

                const SizedBox(height: 24),

                // Menu principale
                _buildMainMenuSection(),

                const SizedBox(height: 24),

                // Quick Actions
                _buildQuickActionsSection(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTodayStatsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Statistiche di Oggi',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
          style: TextStyle(
            color: Colors.grey[400],
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 16),

        // Griglia statistiche
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          childAspectRatio: 1.5,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          children: [
            _buildStatCard(
              title: 'Appuntamenti',
              value: _todayStats['appointments'].toString(),
              icon: Icons.calendar_today,
              color: Colors.blue,
            ),
            _buildStatCard(
              title: 'Incasso',
              value: '€${_todayStats['revenue']}',
              icon: Icons.euro,
              color: Colors.green,
            ),
            _buildStatCard(
              title: 'In Attesa',
              value: _todayStats['pending'].toString(),
              icon: Icons.schedule,
              color: Colors.orange,
            ),
            _buildStatCard(
              title: 'Completati',
              value: _todayStats['completed'].toString(),
              icon: Icons.check_circle,
              color: Colors.teal,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2d2d2d),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(
                icon,
                color: color,
                size: 24,
              ),
              Text(
                value,
                style: TextStyle(
                  color: color,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          Text(
            title,
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainMenuSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Gestione',
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),

        // Card per Appuntamenti
        _buildMenuCard(
          title: 'Appuntamenti',
          subtitle: 'Gestione calendario',
          icon: Icons.calendar_month,
          color: Colors.blue,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const AdminAppointmentsPage(),
              ),
            );
          },
        ),

        const SizedBox(height: 12),

        // Card per Gestione Assenze
        _buildMenuCard(
          title: 'Gestione Assenze',
          subtitle: 'Gestisci assenze stilisti',
          icon: Icons.event_busy,
          color: Colors.orange,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const StylistAssenzeAdminPage(),
              ),
            );
          },
        ),

        const SizedBox(height: 12),

        // Card per Gestione Orari ed Eccezioni
        _buildMenuCard(
          title: 'Orari e Chiusure',
          subtitle: 'Gestisci festività e orari speciali',
          icon: Icons.access_time,
          color: Colors.purple,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const AdminOrariEccezioniPage(),
              ),
            );
          },
        ),

        const SizedBox(height: 12),

        // 💍 Card per Richieste Matrimoni
        _buildMenuCard(
          title: 'Richieste Matrimoni',
          subtitle: _richiesteMatrimoniNonViste > 0
              ? '⚠️ $_richiesteMatrimoniNonViste nuove richieste'
              : 'Gestisci richieste matrimoni',
          icon: Icons.favorite,
          color: const Color(0xFFD4AF37), // Oro
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const AdminMatrimonioRichiestePage(),
              ),
            );
            // Ricarica dopo il ritorno per aggiornare il badge
            _loadRichiesteMatrimoni();
          },
        ),
        const SizedBox(height: 12),

// 👥 Card Gestione Utenti
        _buildMenuCard(
          title: 'Gestione Utenti',
          subtitle: 'Crediti, segnalazioni e blocchi',
          icon: Icons.people,
          color: Colors.teal,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const AdminGestioneUtentiPage(),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildQuickActionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Azioni Rapide',
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),

        Row(
          children: [
            Expanded(
              child: _buildQuickActionButton(
                title: 'Nuovo Appuntamento',
                icon: Icons.add_circle,
                color: Colors.green,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const AdminNewAppointmentPage(),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMenuCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      color: const Color(0xFF2d2d2d),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: Colors.grey[400],
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActionButton({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  void _showFeatureComingSoon(String featureName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2d2d2d),
        title: const Text(
          'Funzionalità in Sviluppo',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'La funzionalità "$featureName" sarà disponibile presto!',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}