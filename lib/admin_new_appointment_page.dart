import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'admin_dashboard_page.dart';
import 'appointment_notification_service.dart';

class AdminNewAppointmentPage extends StatefulWidget {
  const AdminNewAppointmentPage({super.key});

  @override
  State<AdminNewAppointmentPage> createState() => _AdminNewAppointmentPageState();
}

class _AdminNewAppointmentPageState extends State<AdminNewAppointmentPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _surnameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _searchController = TextEditingController();

  String _selectedSection = 'donna'; // Default
  bool _isCreating = false;
  bool _isSearching = false;
  bool _fieldsEnabled = true; // Per abilitare/disabilitare i campi

  List<Map<String, dynamic>> _searchResults = [];
  Map<String, dynamic>? _selectedUser; // Utente selezionato
  bool _showSearchResults = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _surnameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // Ricerca utenti mentre l'admin digita
  void _onSearchChanged() {
    if (_searchController.text.isEmpty) {
      setState(() {
        _showSearchResults = false;
        _searchResults = [];
      });
      return;
    }

    // Debounce search
    Future.delayed(const Duration(milliseconds: 500), () {
      if (_searchController.text.isNotEmpty) {
        _searchUsers(_searchController.text);
      }
    });
  }

  // Cerca utenti nel database
  Future<void> _searchUsers(String query) async {
    if (query.isEmpty) return;

    setState(() => _isSearching = true);

    try {
      final supabase = Supabase.instance.client;

      // Cerca per nome, cognome, email o telefono
      final response = await supabase
          .from('USERS')
          .select('id, nome, cognome, email, telefono, is_admin_created')
          .or('nome.ilike.%$query%,cognome.ilike.%$query%,email.ilike.%$query%,telefono.ilike.%$query%')
          .eq('role', 'user') // Solo utenti, non admin
          .eq('is_admin_created', true); // ✅ SOLO utenti creati dall'admin


      setState(() {
        _searchResults = List<Map<String, dynamic>>.from(response);
        _showSearchResults = _searchResults.isNotEmpty;
        _isSearching = false;
      });

    } catch (e) {
      print('❌ Errore ricerca utenti: $e');
      setState(() => _isSearching = false);
    }
  }

  // Seleziona un utente esistente
  void _selectExistingUser(Map<String, dynamic> user) {
    setState(() {
      _selectedUser = user;
      _nameController.text = user['nome'] ?? '';
      _surnameController.text = user['cognome'] ?? '';
      _phoneController.text = user['telefono'] ?? '';
      _emailController.text = user['email'] ?? '';
      _fieldsEnabled = false; // Disabilita i campi
      _showSearchResults = false;
      _searchController.clear();
    });

    // Mostra snackbar di conferma
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Cliente selezionato: ${user['nome']} ${user['cognome']}'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // Rimuovi la selezione dell'utente
  void _clearSelection() {
    setState(() {
      _selectedUser = null;
      _nameController.clear();
      _surnameController.clear();
      _phoneController.clear();
      _emailController.clear();
      _fieldsEnabled = true; // Riabilita i campi
    });
  }

  void _proceedToServiceSelection() {
    if (_formKey.currentState!.validate()) {
      // Se è stato selezionato un utente esistente, usa il suo ID
      // altrimenti crea un oggetto cliente temporaneo per il flusso
      final clientData = _selectedUser != null
          ? {
        'id': _selectedUser!['id'], // ID dell'utente esistente
        'nome': _selectedUser!['nome'],
        'cognome': _selectedUser!['cognome'],
        'telefono': _selectedUser!['telefono'],
        'email': _selectedUser!['email'],
        'is_existing_user': true, // Flag per indicare che è un utente esistente
      }
          : {
        'nome': _nameController.text.trim(),
        'cognome': _surnameController.text.trim(),
        'telefono': _phoneController.text.trim(),
        'email': _emailController.text.trim(),
        'is_existing_user': false, // Flag per indicare che è un nuovo utente
        'is_admin_booking': true,
      };

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => AdminServiceSelectionPage(
            section: _selectedSection,
            clientData: clientData,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1a1a1a),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2d2d2d),
        elevation: 0,
        title: const Text(
          'Nuovo Appuntamento',
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF4CAF50),
                        Color(0xFF45A049),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.person_add,
                        color: Colors.white,
                        size: 48,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Prenota per un Cliente',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Cerca un cliente esistente o creane uno nuovo',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // Sezione Ricerca Cliente Esistente
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2d2d2d),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.blue.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.search,
                            color: Colors.blue,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Cerca Cliente Esistente',
                            style: TextStyle(
                              color: Colors.blue,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _searchController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Cerca per nome, cognome, email o telefono...',
                          hintStyle: TextStyle(color: Colors.grey[400]),
                          prefixIcon: Icon(
                            Icons.person_search,
                            color: Colors.grey[400],
                          ),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                            icon: const Icon(Icons.clear, color: Colors.grey),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _showSearchResults = false;
                                _searchResults = [];
                              });
                            },
                          )
                              : _isSearching
                              ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.blue,
                              ),
                            ),
                          )
                              : null,
                          filled: true,
                          fillColor: const Color(0xFF1a1a1a),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),

                      // Risultati ricerca
                      if (_showSearchResults) ...[
                        const SizedBox(height: 12),
                        Container(
                          constraints: const BoxConstraints(maxHeight: 200),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1a1a1a),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.blue.withOpacity(0.2),
                              width: 1,
                            ),
                          ),
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: _searchResults.length,
                            itemBuilder: (context, index) {
                              final user = _searchResults[index];
                              final isAdminCreated = user['is_admin_created'] ?? false;

                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: isAdminCreated
                                      ? Colors.orange.withOpacity(0.2)
                                      : Colors.green.withOpacity(0.2),
                                  child: Icon(
                                    Icons.person,
                                    color: isAdminCreated ? Colors.orange : Colors.green,
                                    size: 20,
                                  ),
                                ),
                                title: Text(
                                  '${user['nome']} ${user['cognome']}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                subtitle: Text(
                                  '${user['email'] ?? 'Nessuna email'} • ${user['telefono'] ?? 'Nessun telefono'}',
                                  style: TextStyle(
                                    color: Colors.grey[400],
                                    fontSize: 12,
                                  ),
                                ),
                                trailing: isAdminCreated
                                    ? Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'Admin',
                                    style: TextStyle(
                                      color: Colors.orange,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                )
                                    : null,
                                onTap: () => _selectExistingUser(user),
                              );
                            },
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Divider con "OPPURE"
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 1,
                        color: Colors.grey[600],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'OPPURE',
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Container(
                        height: 1,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Sezione Cliente con indicatore se selezionato
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Dati Cliente',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (_selectedUser != null)
                      TextButton.icon(
                        onPressed: _clearSelection,
                        icon: const Icon(Icons.close, color: Colors.red, size: 18),
                        label: const Text(
                          'Rimuovi selezione',
                          style: TextStyle(color: Colors.red, fontSize: 12),
                        ),
                      ),
                  ],
                ),

                if (_selectedUser != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.green.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.check_circle,
                          color: Colors.green,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Cliente esistente selezionato: ${_selectedUser!['nome']} ${_selectedUser!['cognome']}',
                            style: const TextStyle(
                              color: Colors.green,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 16),

                // Nome
                _buildInputField(
                  controller: _nameController,
                  label: 'Nome',
                  icon: Icons.person,
                  enabled: _fieldsEnabled,
                  validator: (value) {
                    if (_fieldsEnabled) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Il nome è obbligatorio';
                      }
                      if (value.trim().length < 2) {
                        return 'Il nome deve essere di almeno 2 caratteri';
                      }
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                // Cognome
                _buildInputField(
                  controller: _surnameController,
                  label: 'Cognome',
                  icon: Icons.person_outline,
                  enabled: _fieldsEnabled,
                  validator: (value) {
                    if (_fieldsEnabled) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Il cognome è obbligatorio';
                      }
                      if (value.trim().length < 2) {
                        return 'Il cognome deve essere di almeno 2 caratteri';
                      }
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                // Telefono
                _buildInputField(
                  controller: _phoneController,
                  label: 'Telefono',
                  icon: Icons.phone,
                  keyboardType: TextInputType.phone,
                  enabled: _fieldsEnabled,
                  validator: (value) {
                    if (_fieldsEnabled) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Il telefono è obbligatorio';
                      }
                      if (value.trim().length < 8) {
                        return 'Inserisci un numero di telefono valido';
                      }
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                // Email (opzionale)
                _buildInputField(
                  controller: _emailController,
                  label: 'Email (opzionale)',
                  icon: Icons.email,
                  keyboardType: TextInputType.emailAddress,
                  isRequired: false,
                  enabled: _fieldsEnabled,
                  validator: (value) {
                    if (_fieldsEnabled && value != null && value.trim().isNotEmpty) {
                      if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                        return 'Inserisci un\'email valida';
                      }
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 32),

                // Sezione
                const Text(
                  'Tipo di Servizio',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: _buildSectionCard(
                        title: 'DONNA',
                        isSelected: _selectedSection == 'donna',
                        color: Colors.pink,
                        onTap: () => setState(() => _selectedSection = 'donna'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildSectionCard(
                        title: 'UOMO',
                        isSelected: _selectedSection == 'uomo',
                        color: Colors.blue,
                        onTap: () => setState(() => _selectedSection = 'uomo'),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 32),

                // Note informative
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.blue.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.info_outline,
                        color: Colors.blue,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Prenotazione Admin',
                              style: TextStyle(
                                color: Colors.blue,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _selectedUser != null
                                  ? 'Stai creando un appuntamento per un cliente esistente. Il pagamento sarà impostato su "In loco".'
                                  : 'Se crei un nuovo cliente, verrà salvato nel database per future prenotazioni. Il pagamento sarà impostato su "In loco".',
                              style: TextStyle(
                                color: Colors.grey[300],
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: Container(
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
              onPressed: _isCreating ? null : _proceedToServiceSelection,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 3,
              ),
              child: _isCreating
                  ? const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  ),
                  SizedBox(width: 12),
                  Text(
                    'Elaborazione...',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              )
                  : const Text(
                'Continua con i Servizi',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    bool isRequired = true,
    bool enabled = true,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      style: TextStyle(
        color: enabled ? Colors.white : Colors.grey[500],
      ),
      enabled: enabled,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: enabled ? Colors.grey[400] : Colors.grey[600],
          fontSize: 16,
        ),
        prefixIcon: Icon(
          icon,
          color: enabled ? Colors.grey[400] : Colors.grey[600],
        ),
        filled: true,
        fillColor: enabled ? const Color(0xFF2d2d2d) : const Color(0xFF1a1a1a),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: Colors.green,
            width: 2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: Colors.red,
            width: 2,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: Colors.red,
            width: 2,
          ),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: Colors.grey[700]!,
            width: 1,
          ),
        ),
        errorStyle: const TextStyle(
          color: Colors.red,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required bool isSelected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.2) : const Color(0xFF2d2d2d),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : Colors.grey.withOpacity(0.3),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              title == 'DONNA' ? Icons.face_3 : Icons.face,
              color: isSelected ? color : Colors.grey[400],
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                color: isSelected ? color : Colors.grey[300],
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Resto del codice rimane invariato...
// Include: AdminServiceSelectionPage, AdminDateTimeSelectionPage, AdminStylistSelectionPage, AdminBookingConfirmationPage

// NOTA: Le altre classi rimangono uguali, con una modifica nella classe AdminBookingConfirmationPage
// per gestire gli utenti esistenti...

// Nuova classe per la selezione servizi admin (versione modificata)
class AdminServiceSelectionPage extends StatefulWidget {
  final String section;
  final Map<String, dynamic> clientData;

  const AdminServiceSelectionPage({
    super.key,
    required this.section,
    required this.clientData,
  });

  @override
  State<AdminServiceSelectionPage> createState() => _AdminServiceSelectionPageState();
}

class _AdminServiceSelectionPageState extends State<AdminServiceSelectionPage> {
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
          .order('ordine');

      setState(() {
        _services = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });

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
              (s) => s['id'] == service['id']
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
      final prezzoString = service['prezzo'].toString().replaceAll('€', '').trim();
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
        builder: (context) => AdminDateTimeSelectionPage(
          section: widget.section,
          clientData: widget.clientData,
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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Servizi - ${widget.section.toUpperCase()}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'Cliente: ${widget.clientData['nome']} ${widget.clientData['cognome']}',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
              ),
            ),
          ],
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
                        color: widget.section == 'donna' ? Colors.pink : Colors.blue,
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
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 3,
                  ),
                  child: const Text(
                    'Continua con Data e Ora',
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
    return Column(
      children: [
        Container(
          width: double.infinity,
          margin: const EdgeInsets.all(20),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.green.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.admin_panel_settings,
                color: Colors.green,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Modalità Admin - Prenotazione per ${widget.clientData['nome']} ${widget.clientData['cognome']}',
                  style: const TextStyle(
                    color: Colors.green,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),

        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: _services.length,
            itemBuilder: (context, index) {
              final service = _services[index];
              final isSelected = _selectedServices.any(
                      (s) => s['id'] == service['id']
              );

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                child: Card(
                  color: isSelected
                      ? Colors.green.withOpacity(0.1)
                      : const Color(0xFF2d2d2d),
                  elevation: isSelected ? 8 : 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: isSelected
                        ? const BorderSide(
                      color: Colors.green,
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
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(25),
                              border: isSelected
                                  ? Border.all(
                                color: Colors.green,
                                width: 2,
                              )
                                  : null,
                            ),
                            child: const Icon(
                              Icons.content_cut,
                              color: Colors.green,
                              size: 24,
                            ),
                          ),

                          const SizedBox(width: 16),

                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
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
                                          hours: int.tryParse(service['durata'].toString().split(':')[0]) ?? 0,
                                          minutes: int.tryParse(service['durata'].toString().split(':')[1]) ?? 0,
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
                                      style: const TextStyle(
                                        color: Colors.green,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: isSelected ? Colors.green : Colors.transparent,
                              border: Border.all(
                                color: isSelected ? Colors.green : Colors.grey,
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

// ============================================================================
// CLASSE COMPLETA: AdminDateTimeSelectionPage
// Da sostituire nel file admin_new_appointment_page.dart
// ============================================================================

class AdminDateTimeSelectionPage extends StatefulWidget {
  final String section;
  final Map<String, dynamic> clientData;
  final List<Map<String, dynamic>> selectedServices;
  final Duration totalDuration;
  final double totalPrice;

  const AdminDateTimeSelectionPage({
    super.key,
    required this.section,
    required this.clientData,
    required this.selectedServices,
    required this.totalDuration,
    required this.totalPrice,
  });

  @override
  State<AdminDateTimeSelectionPage> createState() => _AdminDateTimeSelectionPageState();
}

class _AdminDateTimeSelectionPageState extends State<AdminDateTimeSelectionPage> {
  bool _isLoading = true;
  DateTime _selectedDate = DateTime.now();
  String? _selectedTimeSlot;
  List<String> _availableTimeSlots = [];

  @override
  void initState() {
    super.initState();
    _initializeSelectedDate();
    _loadAvailableTimeSlots();
  }

  void _initializeSelectedDate() {
    final now = DateTime.now();
    for (int i = 0; i < 12; i++) {
      final monthToCheck = DateTime(now.year, now.month + i);
      final firstAvailableDay = _getFirstAvailableDayOfMonth(monthToCheck);
      if (firstAvailableDay != null) {
        _selectedDate = firstAvailableDay;
        print('✅ Data iniziale selezionata: ${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}');
        return;
      }
    }
    _selectedDate = DateTime.now().add(const Duration(days: 1));
  }

  Future<void> _loadAvailableTimeSlots() async {
    setState(() => _isLoading = true);

    try {
      final availableSlots = await _checkAvailability(_selectedDate);
      setState(() {
        _availableTimeSlots = availableSlots;
        _selectedTimeSlot = null;
        _isLoading = false;
      });

      print('✅ Slot disponibili per ${_formatDate(_selectedDate)}: ${_availableTimeSlots.length}');
    } catch (e) {
      print('❌ Errore caricamento slot: $e');
      setState(() => _isLoading = false);
      if (mounted) {
        _showErrorMessage('Errore nel caricamento degli orari disponibili');
      }
    }
  }

  // NUOVO: Controlla se c'è un'eccezione per una data specifica
  Future<Map<String, dynamic>?> _getEccezionePerData(DateTime data) async {
    final supabase = Supabase.instance.client;
    final dateString = '${data.year}-${data.month.toString().padLeft(2, '0')}-${data.day.toString().padLeft(2, '0')}';

    try {
      final response = await supabase
          .from('orari_eccezioni')
          .select()
          .eq('data', dateString)
          .maybeSingle();

      return response;
    } catch (e) {
      print('Errore recupero eccezioni: $e');
      return null;
    }
  }

  // NUOVO: Ottieni l'orario standard per un giorno della settimana
  Future<Map<String, dynamic>?> _getOrarioStandard(int giornoSettimana) async {
    final supabase = Supabase.instance.client;

    try {
      final response = await supabase
          .from('orari_settimanali')
          .select()
          .eq('giorno_settimana', giornoSettimana)
          .single();

      return response;
    } catch (e) {
      print('Errore recupero orario standard: $e');
      return null;
    }
  }

  // NUOVO: Genera lista orari basata su apertura/chiusura
  List<String> _generaListaOrari(String? apertura, String? chiusura) {
    if (apertura == null || chiusura == null) return [];

    List<String> orari = [];

    try {
      final apre = _parseTimeString(apertura);
      final chiude = _parseTimeString(chiusura);

      int minutiApertura = apre.hour * 60 + apre.minute;
      int minutiChiusura = chiude.hour * 60 + chiude.minute;

      // Genera slot ogni 15 minuti
      for (int minuti = minutiApertura; minuti < minutiChiusura; minuti += 15) {
        // Controlla se c'è tempo sufficiente per completare i servizi
        final slotStart = DateTime(2000, 1, 1, minuti ~/ 60, minuti % 60);
        final slotEnd = slotStart.add(widget.totalDuration);
        final closing = DateTime(2000, 1, 1, chiude.hour, chiude.minute);

        if (slotEnd.isAfter(closing)) break;

        int ore = minuti ~/ 60;
        int min = minuti % 60;
        orari.add('${ore.toString().padLeft(2, '0')}:${min.toString().padLeft(2, '0')}');
      }
    } catch (e) {
      print('Errore generazione orari: $e');
    }

    return orari;
  }

  TimeOfDay _parseTimeString(String time) {
    final parts = time.split(':');
    return TimeOfDay(
      hour: int.parse(parts[0]),
      minute: int.parse(parts[1]),
    );
  }

  Future<List<String>> _checkAvailability(DateTime date) async {
    final supabase = Supabase.instance.client;
    final sessoId = widget.section == 'uomo' ? 1 : 2;
    final dateString = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

    try {
      // 1. Query per stylist del sesso giusto
      final stylistSessoResponse = await supabase
          .from('STYLIST_SESSO_TAGLIO')
          .select('stylist_id')
          .eq('sesso_id', sessoId);

      List<int> stylistIds = stylistSessoResponse
          .map<int>((s) => s['stylist_id'] as int)
          .toList();

      if (stylistIds.isEmpty) return [];

      // 2. Filtra solo stylist non cancellati
      final validStylistsResponse = await supabase
          .from('STYLIST')
          .select('id')
          .inFilter('id', stylistIds)
          .isFilter('deleted_at', null);

      List<int> validStylistIds = validStylistsResponse
          .map<int>((s) => s['id'] as int)
          .toList();

      if (validStylistIds.isEmpty) return [];

      // 3. *** NUOVO: Controlla orari e eccezioni ***
      final eccezione = await _getEccezionePerData(date);

      if (eccezione != null) {
        if (eccezione['tipo'] == 'chiuso') {
          print('❌ Giorno chiuso per eccezione: $dateString');
          return [];
        }

        // Genera orari basati sull'eccezione
        List<String> orariGiornata = [];

        if (eccezione['tipo'] == 'solo_mattina' || eccezione['tipo'] == 'orario_ridotto') {
          if (eccezione['orario_apertura_mattina'] != null) {
            orariGiornata.addAll(_generaListaOrari(
              eccezione['orario_apertura_mattina'],
              eccezione['orario_chiusura_mattina'],
            ));
          }
        }

        if (eccezione['tipo'] == 'solo_pomeriggio' || eccezione['tipo'] == 'orario_ridotto') {
          if (eccezione['orario_apertura_pomeriggio'] != null) {
            orariGiornata.addAll(_generaListaOrari(
              eccezione['orario_apertura_pomeriggio'],
              eccezione['orario_chiusura_pomeriggio'],
            ));
          }
        }

        print('✅ Orari da eccezione (${eccezione['tipo']}): ${orariGiornata.length} slot');

        // Continua con il controllo appuntamenti e assenze
        return await _filtraOrariDisponibili(
            orariGiornata,
            validStylistIds,
            dateString
        );
      }

      // Altrimenti usa l'orario standard
      final giornoSettimana = date.weekday;
      final orarioStandard = await _getOrarioStandard(giornoSettimana);

      if (orarioStandard == null || orarioStandard['aperto'] == false) {
        print('❌ Giorno chiuso: ${_getWeekdayAbbr(giornoSettimana)}');
        return [];
      }

      // Genera orari con i due turni
      List<String> orariGiornata = [];

      // Turno mattina
      if (orarioStandard['orario_apertura_mattina'] != null) {
        orariGiornata.addAll(_generaListaOrari(
          orarioStandard['orario_apertura_mattina'],
          orarioStandard['orario_chiusura_mattina'],
        ));
      }

      // Turno pomeriggio
      if (orarioStandard['orario_apertura_pomeriggio'] != null) {
        orariGiornata.addAll(_generaListaOrari(
          orarioStandard['orario_apertura_pomeriggio'],
          orarioStandard['orario_chiusura_pomeriggio'],
        ));
      }

      print('✅ Orari standard: ${orariGiornata.length} slot (${_getWeekdayAbbr(giornoSettimana)})');

      // Filtra orari basati su appuntamenti e assenze
      return await _filtraOrariDisponibili(
          orariGiornata,
          validStylistIds,
          dateString
      );

    } catch (e) {
      print('❌ Errore controllo disponibilità: $e');
      return [];
    }
  }

  // NUOVO: Filtra orari controllando appuntamenti e assenze
  Future<List<String>> _filtraOrariDisponibili(
      List<String> orariGiornata,
      List<int> stylistIds,
      String dateString,
      ) async {
    final supabase = Supabase.instance.client;

    // Query appuntamenti
    final appointmentsResponse = await supabase
        .from('APPUNTAMENTI')
        .select('stylist_id, ora_inizio, ora_fine')
        .eq('data', dateString)
        .inFilter('stylist_id', stylistIds);

    // Query assenze
    final assenzeResponse = await supabase
        .from('STYLIST_ASSENZE')
        .select('stylist_id, tipo, data_inizio, data_fine, ora_inizio, ora_fine')
        .eq('stato', 'approvato')
        .inFilter('stylist_id', stylistIds);

    // Preprocessa le assenze
    Map<int, List<Map<String, dynamic>>> stylistAssenze = {};
    for (var assenza in assenzeResponse) {
      int stylistId = assenza['stylist_id'];
      if (!stylistAssenze.containsKey(stylistId)) {
        stylistAssenze[stylistId] = [];
      }
      stylistAssenze[stylistId]!.add(assenza);
    }

    // Filtra gli orari
    List<String> availableSlots = [];

    for (int i = 0; i < orariGiornata.length; i++) {
      String slot = orariGiornata[i];

      if (_isSlotAvailableWithAbsences(
        slot,
        appointmentsResponse,
        stylistIds,
        stylistAssenze,
        dateString,
      )) {
        availableSlots.add(slot);
      }

      // Yield control ogni 10 slot
      if (i % 10 == 0) {
        await Future.delayed(Duration.zero);
      }
    }

    return availableSlots;
  }

  bool _isSlotAvailableWithAbsences(
      String startTime,
      List<dynamic> appointments,
      List<int> allStylistIds,
      Map<int, List<Map<String, dynamic>>> stylistAssenze,
      String dateString
      ) {
    final startDateTime = DateTime.parse('2000-01-01 $startTime:00');
    final endDateTime = startDateTime.add(widget.totalDuration);
    final endTime = '${endDateTime.hour.toString().padLeft(2, '0')}:${endDateTime.minute.toString().padLeft(2, '0')}';

    Set<int> unavailableStylistIds = {};

    // 1. Controlla stylist occupati con appuntamenti
    for (var appointment in appointments) {
      final appoStart = appointment['ora_inizio'] as String;
      final appoEnd = appointment['ora_fine'] as String;

      if (_timeOverlaps(startTime, endTime, appoStart.substring(0, 5), appoEnd.substring(0, 5))) {
        unavailableStylistIds.add(appointment['stylist_id'] as int);
      }
    }

    // 2. Controlla stylist in assenza
    for (int stylistId in allStylistIds) {
      if (unavailableStylistIds.contains(stylistId)) {
        continue;
      }

      final assenzeStylist = stylistAssenze[stylistId] ?? [];

      for (var assenza in assenzeStylist) {
        if (_isStylistInAssenza(assenza, dateString, startTime, endTime)) {
          unavailableStylistIds.add(stylistId);
          break;
        }
      }
    }

    int availableStylistCount = allStylistIds.length - unavailableStylistIds.length;
    return availableStylistCount > 0;
  }

  bool _isStylistInAssenza(
      Map<String, dynamic> assenza,
      String dateString,
      String slotStartTime,
      String slotEndTime
      ) {
    final tipo = assenza['tipo'] as String;
    final dataInizio = assenza['data_inizio'] as String?;
    final dataFine = assenza['data_fine'] as String?;

    bool isDateInRange = false;

    if (dataFine == null) {
      isDateInRange = dataInizio == dateString;
    } else {
      isDateInRange = dateString.compareTo(dataInizio!) >= 0 &&
          dateString.compareTo(dataFine) <= 0;
    }

    if (!isDateInRange) {
      return false;
    }

    if (tipo == 'permesso_ore') {
      final oraInizio = assenza['ora_inizio'] as String?;
      final oraFine = assenza['ora_fine'] as String?;

      if (oraInizio != null && oraFine != null) {
        String assenzaStart = _formatTimeForComparison(oraInizio);
        String assenzaEnd = _formatTimeForComparison(oraFine);
        return _timeOverlaps(slotStartTime, slotEndTime, assenzaStart, assenzaEnd);
      }
    }

    if (tipo == 'ferie' || tipo == 'malattia' || tipo == 'permesso_giorno') {
      return true;
    }

    return false;
  }

  String _formatTimeForComparison(String timeStr) {
    try {
      String cleanTime = timeStr.split('.').first;
      if (cleanTime.length > 8) {
        cleanTime = cleanTime.substring(0, 8);
      }
      return cleanTime.substring(0, 5);
    } catch (e) {
      return timeStr;
    }
  }

  bool _timeOverlaps(String start1, String end1, String start2, String end2) {
    final s1 = _parseTime(start1);
    final e1 = _parseTime(end1);
    final s2 = _parseTime(start2);
    final e2 = _parseTime(end2);
    return s1.isBefore(e2) && s2.isBefore(e1);
  }

  DateTime _parseTime(String time) {
    final parts = time.split(':');
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);
    return DateTime(2000, 1, 1, hour, minute);
  }

  Future<void> _selectDate(DateTime date) async {
    if (date.isBefore(DateTime.now().subtract(const Duration(days: 1)))) {
      _showErrorMessage('Non puoi selezionare date passate');
      return;
    }

    // Controlla eccezioni
    final eccezione = await _getEccezionePerData(date);
    if (eccezione != null && eccezione['tipo'] == 'chiuso') {
      _showErrorMessage('Il salone è chiuso in questa data');
      return;
    }

    // Controlla orario standard
    final orarioStandard = await _getOrarioStandard(date.weekday);
    if (orarioStandard != null && orarioStandard['aperto'] == false) {
      _showErrorMessage('Il salone è chiuso il ${_getWeekdayAbbr(date.weekday)}');
      return;
    }

    setState(() {
      _selectedDate = date;
    });
    _loadAvailableTimeSlots();
  }

  void _selectTimeSlot(String timeSlot) {
    setState(() {
      _selectedTimeSlot = timeSlot;
    });
  }

  void _navigateToStylistSelection() {
    if (_selectedTimeSlot == null) {
      _showErrorMessage('Seleziona un orario per continuare');
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AdminStylistSelectionPage(
          section: widget.section,
          clientData: widget.clientData,
          selectedServices: widget.selectedServices,
          totalDuration: widget.totalDuration,
          totalPrice: widget.totalPrice,
          selectedDate: _selectedDate,
          selectedTimeSlot: _selectedTimeSlot!,
        ),
      ),
    );
  }

  DateTime? _getFirstAvailableDayOfMonth(DateTime monthDate) {
    final today = DateTime.now();
    final lastDay = DateTime(monthDate.year, monthDate.month + 1, 0);

    for (int day = 1; day <= lastDay.day; day++) {
      final dayDate = DateTime(monthDate.year, monthDate.month, day);

      if (dayDate.isBefore(DateTime(today.year, today.month, today.day))) {
        continue;
      }

      // Salta lunedì (1) e domenica (7)
      if (dayDate.weekday == 1 || dayDate.weekday == 7) {
        continue;
      }

      return dayDate;
    }
    return null;
  }

  String _formatDate(DateTime date) {
    const months = ['', 'Gen', 'Feb', 'Mar', 'Apr', 'Mag', 'Giu', 'Lug', 'Ago', 'Set', 'Ott', 'Nov', 'Dic'];
    const weekdays = ['', 'Lun', 'Mar', 'Mer', 'Gio', 'Ven', 'Sab', 'Dom'];
    return '${weekdays[date.weekday]} ${date.day} ${months[date.month]}';
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

  String _getWeekdayAbbr(int weekday) {
    const weekdays = ['', 'LUN', 'MAR', 'MER', 'GIO', 'VEN', 'SAB', 'DOM'];
    return weekdays[weekday];
  }

  String _getMonthAbbrShort(int month) {
    const months = [
      '', 'GEN', 'FEB', 'MAR', 'APR', 'MAG', 'GIU',
      'LUG', 'AGO', 'SET', 'OTT', 'NOV', 'DIC'
    ];
    return months[month];
  }

  void _selectMonth(DateTime monthDate) {
    setState(() {
      final firstAvailableDay = _getFirstAvailableDayOfMonth(monthDate);
      if (firstAvailableDay != null) {
        _selectedDate = firstAvailableDay;
        _loadAvailableTimeSlots();
      }
    });
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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Seleziona Data e Ora',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'Cliente: ${widget.clientData['nome']} ${widget.clientData['cognome']}',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
              ),
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Riepilogo servizi
            Container(
              width: double.infinity,
              margin: const EdgeInsets.all(20),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.green.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.admin_panel_settings,
                    color: Colors.green,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Prenotazione Admin',
                          style: TextStyle(
                            color: Colors.green,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${widget.selectedServices.length} servizio/i - ${_formatDuration(widget.totalDuration)} - €${widget.totalPrice.toStringAsFixed(2)}',
                          style: TextStyle(
                            color: Colors.grey[300],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Calendario
            Expanded(
              child: _isLoading
                  ? const Center(
                child: CircularProgressIndicator(color: Colors.white),
              )
                  : SingleChildScrollView(
                child: Column(
                  children: [
                    _buildDateSelector(),
                    const SizedBox(height: 20),
                    _buildTimeSlotSelector(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _selectedTimeSlot != null
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
              onPressed: _navigateToStylistSelection,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 3,
              ),
              child: Text(
                'Scegli Stylist - ${_formatDate(_selectedDate)} alle $_selectedTimeSlot',
                style: const TextStyle(
                  fontSize: 14,
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

  Widget _buildDateSelector() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Seleziona la data',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          // Selettore mese/anno
          Container(
            height: 40,
            margin: const EdgeInsets.only(bottom: 12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: List.generate(12, (index) {
                  final monthDate = DateTime(DateTime.now().year, DateTime.now().month + index);
                  final isCurrentMonth = monthDate.month == _selectedDate.month &&
                      monthDate.year == _selectedDate.year;

                  // Controlla se il mese ha giorni disponibili
                  final hasAvailableDays = _getFirstAvailableDayOfMonth(monthDate) != null;

                  return Container(
                    margin: const EdgeInsets.only(right: 8),
                    child: InkWell(
                      onTap: hasAvailableDays ? () => _selectMonth(monthDate) : null,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        constraints: const BoxConstraints(
                          minWidth: 50,
                          maxWidth: 70,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        decoration: BoxDecoration(
                          color: isCurrentMonth
                              ? Colors.green
                              : hasAvailableDays
                              ? const Color(0xFF2d2d2d)
                              : Colors.grey.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _getMonthAbbrShort(monthDate.month),
                              style: TextStyle(
                                color: hasAvailableDays
                                    ? (isCurrentMonth ? Colors.white : Colors.grey[300])
                                    : Colors.grey,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 1),
                            Text(
                              monthDate.year.toString().substring(2),
                              style: TextStyle(
                                color: hasAvailableDays
                                    ? (isCurrentMonth ? Colors.white70 : Colors.grey[400])
                                    : Colors.grey,
                                fontSize: 8,
                              ),
                              maxLines: 1,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),

          // Giorni del mese selezionato
          SizedBox(
            height: 80,
            child: _buildDaysForMonth(_selectedDate),
          ),
        ],
      ),
    );
  }

  Widget _buildDaysForMonth(DateTime monthDate) {
    final lastDay = DateTime(monthDate.year, monthDate.month + 1, 0);
    final today = DateTime.now();

    List<DateTime> daysInMonth = [];
    for (int day = 1; day <= lastDay.day; day++) {
      final dayDate = DateTime(monthDate.year, monthDate.month, day);
      if ((dayDate.isAfter(today) || dayDate.isAtSameMomentAs(DateTime(today.year, today.month, today.day)))
          && dayDate.weekday != 1 && dayDate.weekday != 7) {
        daysInMonth.add(dayDate);
      }
    }

    if (daysInMonth.isEmpty) {
      return Center(
        child: Text(
          'Nessun giorno disponibile in questo mese',
          style: TextStyle(
            color: Colors.grey[400],
            fontSize: 14,
          ),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: daysInMonth.map((date) {
          final isSelected = _selectedDate.day == date.day &&
              _selectedDate.month == date.month &&
              _selectedDate.year == date.year;
          final isToday = date.day == DateTime.now().day &&
              date.month == DateTime.now().month &&
              date.year == DateTime.now().year;

          return Container(
            margin: const EdgeInsets.only(right: 10),
            child: InkWell(
              onTap: () => _selectDate(date),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 65,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.green : const Color(0xFF2d2d2d),
                  borderRadius: BorderRadius.circular(12),
                  border: isToday ? Border.all(color: Colors.white, width: 1) : null,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      date.day.toString(),
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatDate(date).split(' ')[0],
                      style: TextStyle(
                        color: isSelected ? Colors.white70 : Colors.grey[300],
                        fontSize: 9,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTimeSlotSelector() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Orari disponibili - ${_formatDate(_selectedDate)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          _availableTimeSlots.isEmpty
              ? Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF2d2d2d),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: Text(
                'Nessun orario disponibile per questa data',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          )
              : GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              childAspectRatio: 2,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: _availableTimeSlots.length,
            itemBuilder: (context, index) {
              final timeSlot = _availableTimeSlots[index];
              final isSelected = _selectedTimeSlot == timeSlot;

              return InkWell(
                onTap: () => _selectTimeSlot(timeSlot),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.green : const Color(0xFF2d2d2d),
                    borderRadius: BorderRadius.circular(8),
                    border: isSelected
                        ? Border.all(color: Colors.green, width: 2)
                        : null,
                  ),
                  child: Center(
                    child: Text(
                      timeSlot,
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.grey[300],
                        fontSize: 14,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}


// AdminStylistSelectionPage
class AdminStylistSelectionPage extends StatefulWidget {
  final String section;
  final Map<String, dynamic> clientData;
  final List<Map<String, dynamic>> selectedServices;
  final Duration totalDuration;
  final double totalPrice;
  final DateTime selectedDate;
  final String selectedTimeSlot;

  const AdminStylistSelectionPage({
    super.key,
    required this.section,
    required this.clientData,
    required this.selectedServices,
    required this.totalDuration,
    required this.totalPrice,
    required this.selectedDate,
    required this.selectedTimeSlot,
  });

  @override
  State<AdminStylistSelectionPage> createState() => _AdminStylistSelectionPageState();
}

class _AdminStylistSelectionPageState extends State<AdminStylistSelectionPage> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _availableStylists = [];
  Map<String, dynamic>? _selectedStylist;

  @override
  void initState() {
    super.initState();
    _loadAvailableStylists();
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 🔒 FUNZIONE _loadAvailableStylists CORRETTA CON CONTROLLO ASSENZE
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// In AdminStylistSelectionPage, sostituisci la funzione _loadAvailableStylists
// (circa riga 2321) con questa versione aggiornata
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

// HELPER FUNCTIONS - Aggiungi queste alla classe se non ci sono già
  String _formatTimeForComparison(String timeStr) {
    try {
      String cleanTime = timeStr.split('.').first;
      if (cleanTime.length > 8) {
        cleanTime = cleanTime.substring(0, 8);
      }
      return cleanTime.substring(0, 5); // Ritorna solo HH:MM
    } catch (e) {
      return timeStr;
    }
  }

  bool _isStylistInAssenza(
      Map<String, dynamic> assenza,
      String dateString,
      String slotStartTime,
      String slotEndTime
      ) {
    final tipo = assenza['tipo'] as String;
    final dataInizio = assenza['data_inizio'] as String?;
    final dataFine = assenza['data_fine'] as String?;

    // Controlla se la data è nel range dell'assenza
    bool isDateInRange = false;

    if (dataFine == null) {
      // Assenza di un solo giorno
      isDateInRange = dataInizio == dateString;
    } else {
      // Assenza con range di date
      isDateInRange = dateString.compareTo(dataInizio!) >= 0 &&
          dateString.compareTo(dataFine) <= 0;
    }

    if (!isDateInRange) {
      return false; // La data non è nel range dell'assenza
    }

    // Se è permesso ore, controlla anche gli orari
    if (tipo == 'permesso_ore') {
      final oraInizio = assenza['ora_inizio'] as String?;
      final oraFine = assenza['ora_fine'] as String?;

      if (oraInizio != null && oraFine != null) {
        String assenzaStart = _formatTimeForComparison(oraInizio);
        String assenzaEnd = _formatTimeForComparison(oraFine);

        return _timeOverlaps(slotStartTime, slotEndTime, assenzaStart, assenzaEnd);
      }
    }

    // Per ferie, malattia, permesso_giorno: stylist non disponibile per l'intera giornata
    if (tipo == 'ferie' || tipo == 'malattia' || tipo == 'permesso_giorno') {
      return true;
    }

    return false;
  }

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// FUNZIONE PRINCIPALE CORRETTA
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Future<void> _loadAvailableStylists() async {
    setState(() => _isLoading = true);

    try {
      final supabase = Supabase.instance.client;
      final sessoId = widget.section == 'uomo' ? 1 : 2;
      final dateString = '${widget.selectedDate.year}-${widget.selectedDate.month.toString().padLeft(2, '0')}-${widget.selectedDate.day.toString().padLeft(2, '0')}';

      final startDateTime = DateTime.parse('$dateString ${widget.selectedTimeSlot}:00');
      final endDateTime = startDateTime.add(widget.totalDuration);
      final endTime = '${endDateTime.hour.toString().padLeft(2, '0')}:${endDateTime.minute.toString().padLeft(2, '0')}';

      print('🔍 Caricamento stylist disponibili per ${widget.selectedTimeSlot} - $endTime');

      // 1️⃣ Carica tutti gli stylist del sesso giusto
      final allStylistsResponse = await supabase
          .from('STYLIST')
          .select('''
          id,
          descrizione,
          STYLIST_SESSO_TAGLIO!inner(sesso_id)
        ''')
          .eq('STYLIST_SESSO_TAGLIO.sesso_id', sessoId)
          .isFilter('deleted_at', null);

      List<Map<String, dynamic>> allStylists = List<Map<String, dynamic>>.from(allStylistsResponse);
      print('📋 Stylist totali: ${allStylists.length}');

      // 2️⃣ Controlla appuntamenti esistenti
      final appointmentsResponse = await supabase
          .from('APPUNTAMENTI')
          .select('stylist_id, ora_inizio, ora_fine')
          .eq('data', dateString);

      Set<int> busyStylistIds = {};
      for (var appointment in appointmentsResponse) {
        final appoStart = _formatTimeForComparison(appointment['ora_inizio'] as String);
        final appoEnd = _formatTimeForComparison(appointment['ora_fine'] as String);

        if (_timeOverlaps(widget.selectedTimeSlot, endTime, appoStart, appoEnd)) {
          busyStylistIds.add(appointment['stylist_id'] as int);
          print('⚠️ Stylist ${appointment['stylist_id']} occupato con appuntamento ${appoStart}-${appoEnd}');
        }
      }

      // 3️⃣ NUOVO: Controlla assenze stylist
      final assenzeResponse = await supabase
          .from('STYLIST_ASSENZE')
          .select('stylist_id, tipo, data_inizio, data_fine, ora_inizio, ora_fine')
          .eq('stato', 'approvato');

      print('🔍 Assenze totali da controllare: ${assenzeResponse.length}');

      Set<int> absentStylistIds = {};
      for (var assenza in assenzeResponse) {
        int stylistId = assenza['stylist_id'];

        // Controlla se lo stylist è in assenza per questa data/orario
        if (_isStylistInAssenza(assenza, dateString, widget.selectedTimeSlot, endTime)) {
          absentStylistIds.add(stylistId);
          print('⚠️ Stylist $stylistId in assenza (${assenza['tipo']})');
        }
      }

      // 4️⃣ Filtra stylist disponibili (né occupati né assenti)
      Set<int> unavailableStylistIds = {...busyStylistIds, ...absentStylistIds};

      List<Map<String, dynamic>> availableStylists = allStylists
          .where((stylist) => !unavailableStylistIds.contains(stylist['id']))
          .toList();

      print('✅ Stylist disponibili: ${availableStylists.length}');
      print('   - Occupati con appuntamenti: ${busyStylistIds.length}');
      print('   - In assenza: ${absentStylistIds.length}');

      setState(() {
        _availableStylists = availableStylists;
        _isLoading = false;
      });

    } catch (e) {
      print('❌ Errore caricamento stylist disponibili: $e');
      setState(() => _isLoading = false);
      if (mounted) {
        _showErrorMessage('Errore nel caricamento degli stylist disponibili');
      }
    }
  }

  bool _timeOverlaps(String start1, String end1, String start2, String end2) {
    final s1 = _parseTime(start1);
    final e1 = _parseTime(end1);
    final s2 = _parseTime(start2);
    final e2 = _parseTime(end2);
    return s1.isBefore(e2) && s2.isBefore(e1);
  }

  DateTime _parseTime(String time) {
    final parts = time.split(':');
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);
    return DateTime(2000, 1, 1, hour, minute);
  }

  void _selectStylist(Map<String, dynamic> stylist) {
    setState(() {
      _selectedStylist = stylist;
    });
  }

  void _navigateToConfirmation() {
    if (_selectedStylist == null) {
      _showErrorMessage('Seleziona uno stylist per continuare');
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AdminBookingConfirmationPage(
          section: widget.section,
          clientData: widget.clientData,
          selectedServices: widget.selectedServices,
          totalDuration: widget.totalDuration,
          totalPrice: widget.totalPrice,
          selectedDate: widget.selectedDate,
          selectedTimeSlot: widget.selectedTimeSlot,
          selectedStylist: _selectedStylist!,
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    const months = ['', 'Gen', 'Feb', 'Mar', 'Apr', 'Mag', 'Giu', 'Lug', 'Ago', 'Set', 'Ott', 'Nov', 'Dic'];
    const weekdays = ['', 'Lun', 'Mar', 'Mer', 'Gio', 'Ven', 'Sab', 'Dom'];
    return '${weekdays[date.weekday]} ${date.day} ${months[date.month]}';
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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Scegli lo Stylist',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              '${widget.clientData['nome']} ${widget.clientData['cognome']} - ${_formatDate(widget.selectedDate)} alle ${widget.selectedTimeSlot}',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 11,
              ),
            ),
          ],
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
            : _availableStylists.isEmpty
            ? _buildEmptyState()
            : _buildStylistsList(),
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
              onPressed: _navigateToConfirmation,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 3,
              ),
              child: Text(
                'Conferma con ${_selectedStylist!['descrizione']}',
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
          const Text(
            'Nessun stylist disponibile',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'per ${_formatDate(widget.selectedDate)} alle ${widget.selectedTimeSlot}',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF1a1a1a),
            ),
            child: const Text('Scegli un altro orario'),
          ),
        ],
      ),
    );
  }

  Widget _buildStylistsList() {
    return Column(
      children: [
        Container(
          width: double.infinity,
          margin: const EdgeInsets.all(20),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.green.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.admin_panel_settings,
                color: Colors.green,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '${_availableStylists.length} stylist disponibili per questo orario',
                  style: const TextStyle(
                    color: Colors.green,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),

        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: _availableStylists.length,
            itemBuilder: (context, index) {
              final stylist = _availableStylists[index];
              final isSelected = _selectedStylist?['id'] == stylist['id'];

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                child: Card(
                  color: isSelected
                      ? Colors.green.withOpacity(0.1)
                      : const Color(0xFF2d2d2d),
                  elevation: isSelected ? 8 : 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: isSelected
                        ? const BorderSide(
                      color: Colors.green,
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
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(30),
                              border: isSelected
                                  ? Border.all(
                                color: Colors.green,
                                width: 2,
                              )
                                  : null,
                            ),
                            child: const Icon(
                              Icons.person,
                              color: Colors.green,
                              size: 30,
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
                                  child: Text(
                                    'Libero alle ${widget.selectedTimeSlot}',
                                    style: const TextStyle(
                                      color: Colors.green,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          if (isSelected)
                            Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: Colors.green,
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

// AdminBookingConfirmationPage - Pagina finale di conferma e salvataggio
class AdminBookingConfirmationPage extends StatefulWidget {
  final String section;
  final Map<String, dynamic> clientData;
  final List<Map<String, dynamic>> selectedServices;
  final Duration totalDuration;
  final double totalPrice;
  final DateTime selectedDate;
  final String selectedTimeSlot;
  final Map<String, dynamic> selectedStylist;

  const AdminBookingConfirmationPage({
    super.key,
    required this.section,
    required this.clientData,
    required this.selectedServices,
    required this.totalDuration,
    required this.totalPrice,
    required this.selectedDate,
    required this.selectedTimeSlot,
    required this.selectedStylist,
  });

  @override
  State<AdminBookingConfirmationPage> createState() => _AdminBookingConfirmationPageState();
}

class _AdminBookingConfirmationPageState extends State<AdminBookingConfirmationPage> {
  bool _isBooking = false;

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 🔒 FUNZIONE _confirmBooking CON CONTROLLI CORRETTI
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// Sostituisci la funzione _confirmBooking esistente (circa riga 2754)
// con questa versione aggiornata
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

// Helper functions - AGGIUNGI QUESTE ALLA CLASSE _AdminBookingConfirmationPageState
  DateTime _parseTime(String time) {
    final parts = time.split(':');
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);
    return DateTime(2000, 1, 1, hour, minute);
  }

  bool _timeOverlaps(String start1, String end1, String start2, String end2) {
    final s1 = _parseTime(start1);
    final e1 = _parseTime(end1);
    final s2 = _parseTime(start2);
    final e2 = _parseTime(end2);

    return s1.isBefore(e2) && s2.isBefore(e1);
  }

  String _formatTimeForComparison(String timeStr) {
    try {
      String cleanTime = timeStr.split('.').first;
      if (cleanTime.length > 8) {
        cleanTime = cleanTime.substring(0, 8);
      }
      return cleanTime.substring(0, 5); // Ritorna solo HH:MM
    } catch (e) {
      return timeStr;
    }
  }

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// FUNZIONE PRINCIPALE
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Future<void> _confirmBooking() async {
    setState(() => _isBooking = true);

    try {
      final supabase = Supabase.instance.client;
      final adminUser = firebase_auth.FirebaseAuth.instance.currentUser;

      if (adminUser == null) {
        throw Exception('Admin non autenticato');
      }

      print('🔍 Inizio creazione appuntamento admin...');

      // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
      // 🔒 CONTROLLI DI VALIDAZIONE (esattamente come datetime_selection_page)
      // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

      final dateString = '${widget.selectedDate.year}-${widget.selectedDate.month.toString().padLeft(2, '0')}-${widget.selectedDate.day.toString().padLeft(2, '0')}';
      final dayOfWeek = widget.selectedDate.weekday;

      print('🔍 STEP 1: Controllo eccezioni (chiusure straordinarie)...');

      // 1️⃣ CONTROLLO ECCEZIONI (PRIORITÀ MASSIMA)
      final eccezioniResponse = await supabase
          .from('orari_eccezioni')
          .select()
          .eq('data', dateString)
          .maybeSingle();

      if (eccezioniResponse != null && eccezioniResponse['tipo'] == 'chiuso') {
        final motivo = eccezioniResponse['motivo'] ?? 'Chiusura straordinaria';
        throw Exception('Il salone è chiuso il ${_formatDate(widget.selectedDate)}: $motivo');
      }

      print('✅ Nessuna chiusura eccezionale');

      // 2️⃣ CONTROLLO ORARIO STANDARD (se non ci sono eccezioni)
      print('🔍 STEP 2: Controllo orario standard...');

      final orarioStandardResponse = await supabase
          .from('orari_settimanali')
          .select()
          .eq('giorno_settimana', dayOfWeek)
          .maybeSingle();

      if (orarioStandardResponse == null || orarioStandardResponse['aperto'] == false) {
        throw Exception('Il salone è chiuso di ${_getWeekdayName(dayOfWeek)}.');
      }

      // Verifica che l'orario selezionato rientri negli orari di apertura
      final selectedTime = widget.selectedTimeSlot;
      final startDateTime = DateTime.parse('${dateString} ${selectedTime}:00');
      final endDateTime = startDateTime.add(widget.totalDuration);
      final endTime = '${endDateTime.hour.toString().padLeft(2, '0')}:${endDateTime.minute.toString().padLeft(2, '0')}';

      // Controlla se l'appuntamento rientra negli orari di apertura
      bool isInOpeningHours = false;

      // Controlla mattina
      if (orarioStandardResponse['orario_apertura_mattina'] != null) {
        final mattOpen = _formatTimeForComparison(orarioStandardResponse['orario_apertura_mattina']);
        final mattClose = _formatTimeForComparison(orarioStandardResponse['orario_chiusura_mattina']);

        if (_parseTime(selectedTime).isAfter(_parseTime(mattOpen).subtract(const Duration(minutes: 1))) &&
            _parseTime(endTime).isBefore(_parseTime(mattClose).add(const Duration(minutes: 1)))) {
          isInOpeningHours = true;
        }
      }

      // Controlla pomeriggio
      if (!isInOpeningHours && orarioStandardResponse['orario_apertura_pomeriggio'] != null) {
        final pomOpen = _formatTimeForComparison(orarioStandardResponse['orario_apertura_pomeriggio']);
        final pomClose = _formatTimeForComparison(orarioStandardResponse['orario_chiusura_pomeriggio']);

        if (_parseTime(selectedTime).isAfter(_parseTime(pomOpen).subtract(const Duration(minutes: 1))) &&
            _parseTime(endTime).isBefore(_parseTime(pomClose).add(const Duration(minutes: 1)))) {
          isInOpeningHours = true;
        }
      }

      if (!isInOpeningHours) {
        throw Exception('L\'orario selezionato non rientra negli orari di apertura del salone.');
      }

      print('✅ Orario valido');

      // 3️⃣ CONTROLLO ASSENZE STYLIST
      print('🔍 STEP 3: Controllo assenze stylist...');

      final assenzeResponse = await supabase
          .from('STYLIST_ASSENZE')
          .select()
          .eq('stylist_id', widget.selectedStylist['id'])
          .eq('stato', 'approvato');

      for (var assenza in assenzeResponse) {
        final tipo = assenza['tipo'] as String;
        final dataInizio = assenza['data_inizio'] as String?;
        final dataFine = assenza['data_fine'] as String?;

        // Controlla se la data è nel range dell'assenza
        bool isDateInRange = false;

        if (dataFine == null) {
          isDateInRange = dataInizio == dateString;
        } else {
          isDateInRange = dateString.compareTo(dataInizio!) >= 0 &&
              dateString.compareTo(dataFine) <= 0;
        }

        if (!isDateInRange) continue;

        // Se è permesso ore, controlla anche gli orari
        if (tipo == 'permesso_ore') {
          final oraInizio = assenza['ora_inizio'] as String?;
          final oraFine = assenza['ora_fine'] as String?;

          if (oraInizio != null && oraFine != null) {
            String assenzaStart = _formatTimeForComparison(oraInizio);
            String assenzaEnd = _formatTimeForComparison(oraFine);

            if (_timeOverlaps(selectedTime, endTime, assenzaStart, assenzaEnd)) {
              final motivo = assenza['motivo'] ?? 'Non disponibile';
              throw Exception('${widget.selectedStylist['descrizione']} non è disponibile in questo orario: $motivo');
            }
          }
        }

        // Per ferie, malattia, permesso_giorno: stylist non disponibile per l'intera giornata
        if (tipo == 'ferie' || tipo == 'malattia' || tipo == 'permesso_giorno') {
          final motivo = assenza['motivo'] ?? 'Assente';
          throw Exception('${widget.selectedStylist['descrizione']} non è disponibile il ${_formatDate(widget.selectedDate)}: $motivo');
        }
      }

      print('✅ Stylist disponibile (no assenze)');

      // 4️⃣ CONTROLLO SOVRAPPOSIZIONI CON ALTRI APPUNTAMENTI
      print('🔍 STEP 4: Controllo sovrapposizioni appuntamenti...');

      final startTime = '${widget.selectedTimeSlot}:00';
      final endTimeWithSeconds = '${endTime}:00';

      final overlappingAppointments = await supabase
          .from('APPUNTAMENTI')
          .select('ora_inizio, ora_fine')
          .eq('stylist_id', widget.selectedStylist['id'])
          .eq('data', dateString);

      for (var apt in overlappingAppointments) {
        final aptStart = _formatTimeForComparison(apt['ora_inizio'] as String);
        final aptEnd = _formatTimeForComparison(apt['ora_fine'] as String);

        if (_timeOverlaps(selectedTime, endTime, aptStart, aptEnd)) {
          throw Exception('${widget.selectedStylist['descrizione']} ha già un appuntamento in questo orario (${aptStart} - ${aptEnd}). Scegli un altro orario o stylist.');
        }
      }

      print('✅ Nessuna sovrapposizione');

      print('✅ TUTTI I CONTROLLI SUPERATI! Procedo con la creazione...');

      // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
      // 📝 CREAZIONE APPUNTAMENTO (solo se tutti i controlli passano)
      // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

      // ✅ GESTIONE UTENTE
      String clientUserId;

      if (widget.clientData['is_existing_user'] == true) {
        clientUserId = widget.clientData['id'].toString();
        print('✅ Uso utente esistente con ID: $clientUserId');
      } else {
        final clientEmail = widget.clientData['email']?.toString().trim() ?? '';
        final clientPhone = widget.clientData['telefono']?.toString().trim() ?? '';

        String? existingUserId;

        if (clientEmail.isNotEmpty) {
          final existingUserByEmail = await supabase
              .from('USERS')
              .select('id')
              .eq('email', clientEmail)
              .maybeSingle();

          if (existingUserByEmail != null) {
            existingUserId = existingUserByEmail['id'].toString();
            print('✅ Utente esistente trovato per email: $clientEmail (ID: $existingUserId)');
          }
        }

        if (existingUserId == null && clientPhone.isNotEmpty) {
          final existingUserByPhone = await supabase
              .from('USERS')
              .select('id')
              .eq('telefono', clientPhone)
              .maybeSingle();

          if (existingUserByPhone != null) {
            existingUserId = existingUserByPhone['id'].toString();
            print('✅ Utente esistente trovato per telefono: $clientPhone (ID: $existingUserId)');
          }
        }

        if (existingUserId != null) {
          clientUserId = existingUserId;
          print('✅ Uso utente esistente trovato: $clientUserId');
        } else {
          final fakeUid = 'admin_client_${DateTime.now().millisecondsSinceEpoch}_${widget.clientData['nome']}_${widget.clientData['cognome']}'.toLowerCase().replaceAll(' ', '_');

          final clientUserData = {
            'uid': fakeUid,
            'nome': widget.clientData['nome'],
            'cognome': widget.clientData['cognome'],
            'email': clientEmail.isNotEmpty ? clientEmail : null,
            'telefono': clientPhone,
            'role': 'user',
            'created_at': DateTime.now().toIso8601String(),
            'is_admin_created': true,
            'password': null,
          };

          print('📝 Creazione nuovo utente: $clientUserData');

          final clientUserResponse = await supabase
              .from('USERS')
              .insert(clientUserData)
              .select('id')
              .single();

          clientUserId = clientUserResponse['id'].toString();
          print('✅ Nuovo utente creato con ID: $clientUserId');
        }
      }

      // CREA APPUNTAMENTO
      final durationString = '${widget.totalDuration.inHours.toString().padLeft(2, '0')}:${widget.totalDuration.inMinutes.remainder(60).toString().padLeft(2, '0')}:00';

      final appointmentData = {
        'user_id': int.parse(clientUserId),
        'data': dateString,
        'ora_inizio': startTime,
        'ora_fine': endTimeWithSeconds,
        'durata_totale': durationString,
        'stylist_id': widget.selectedStylist['id'],
        'prezzo_totale': widget.totalPrice,
        'note': widget.clientData['is_existing_user'] == true
            ? 'Prenotazione admin per cliente esistente'
            : 'Prenotazione admin per nuovo cliente',
        'created_at': DateTime.now().toIso8601String(),
      };

      print('📝 Creazione appuntamento: $appointmentData');

      final appointmentResponse = await supabase
          .from('APPUNTAMENTI')
          .insert(appointmentData)
          .select('id')
          .single();

      final appointmentId = appointmentResponse['id'];
      print('✅ Appuntamento creato con ID: $appointmentId');

      try {
        await AppointmentNotificationService.scheduleAppointmentReminder(
          appointmentId: appointmentId,
          clientName: '${widget.clientData['nome']} ${widget.clientData['cognome']}',
          stylistName: widget.selectedStylist['descrizione'],
          appointmentDate: widget.selectedDate,
          appointmentTime: widget.selectedTimeSlot,
          services: widget.selectedServices
              .map((s) => s['descrizione'] as String)
              .toList(),
        );

        print('🔔 Notifica promemoria programmata per cliente');
      } catch (e) {
        print('⚠️ Errore programmazione notifica (non critico): $e');
      }

      // INSERISCI SERVIZI
      for (final service in widget.selectedServices) {
        final serviceData = {
          'appuntamento_id': appointmentId,
          'servizio_id': service['id'],
          'quantita': 1,
        };

        await supabase.from('APPUNTAMENTI_SERVIZI').insert(serviceData);
        print('✅ Servizio aggiunto: ${service['descrizione']}');
      }

      // CREA PAGAMENTO
      final paymentData = {
        'appuntamento_id': appointmentId,
        'metodo_pagamento': 'in_loco',
        'stato': 'in_attesa',
        'importo': widget.totalPrice,
        'stripe_payment_intent_id': null,
        'created_at': DateTime.now().toIso8601String(),
      };

      await supabase.from('PAGAMENTI').insert(paymentData);
      print('✅ Record pagamento creato: in_loco - in_attesa');

      print('🎉 Appuntamento admin creato con successo!');

      if (mounted) {
        _showSuccessDialog();
      }

    } catch (e) {
      print('❌ Errore creazione appuntamento: $e');
      setState(() => _isBooking = false);

      if (mounted) {
        _showErrorMessage('Errore: ${e.toString()}');
      }
    }
  }

// Helper aggiuntivo se non esiste
  String _getWeekdayName(int day) {
    const days = ['', 'Lunedì', 'Martedì', 'Mercoledì', 'Giovedì', 'Venerdì', 'Sabato', 'Domenica'];
    return days[day];
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2d2d2d),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.check_circle,
                color: Colors.green,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Appuntamento Creato',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'L\'appuntamento per ${widget.clientData['nome']} ${widget.clientData['cognome']} è stato creato con successo!',
              style: TextStyle(
                color: Colors.grey[300],
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1a1a1a),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _buildConfirmationDetail('Cliente', '${widget.clientData['nome']} ${widget.clientData['cognome']}'),
                  _buildConfirmationDetail('Stylist', widget.selectedStylist['descrizione']),
                  _buildConfirmationDetail('Data', _formatDate(widget.selectedDate)),
                  _buildConfirmationDetail('Orario', '${widget.selectedTimeSlot} - ${_getEndTime()}'),
                  _buildConfirmationDetail('Durata', _formatDuration(widget.totalDuration)),
                  _buildConfirmationDetail('Prezzo', '€${widget.totalPrice.toStringAsFixed(2)}'),
                  _buildConfirmationDetail('Pagamento', 'In loco'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.green.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.admin_panel_settings,
                    color: Colors.green,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Lo slot orario è ora occupato e non sarà disponibile per altre prenotazioni.',
                      style: TextStyle(
                        color: Colors.grey[300],
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () {
                // Torna alla dashboard admin
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const AdminDashboardPage()),
                      (route) => false,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Torna alla Dashboard',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmationDetail(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 14,
            ),
          ),
          Flexible(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  String _getEndTime() {
    final startDateTime = DateTime.parse(
        '2000-01-01 ${widget.selectedTimeSlot}:00'
    );
    final endDateTime = startDateTime.add(widget.totalDuration);
    return '${endDateTime.hour.toString().padLeft(2, '0')}:${endDateTime.minute.toString().padLeft(2, '0')}';
  }

  String _formatDate(DateTime date) {
    const months = [
      '', 'Gennaio', 'Febbraio', 'Marzo', 'Aprile', 'Maggio', 'Giugno',
      'Luglio', 'Agosto', 'Settembre', 'Ottobre', 'Novembre', 'Dicembre'
    ];
    const weekdays = [
      '', 'Lunedì', 'Martedì', 'Mercoledì', 'Giovedì', 'Venerdì', 'Sabato', 'Domenica'
    ];

    return '${weekdays[date.weekday]}, ${date.day} ${months[date.month]} ${date.year}';
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

  String _formatServiceDuration(dynamic duration) {
    if (duration is String) {
      final parts = duration.split(':');
      if (parts.length >= 2) {
        final hours = int.tryParse(parts[0]) ?? 0;
        final minutes = int.tryParse(parts[1]) ?? 0;

        if (hours > 0) {
          return '${hours}h ${minutes}m';
        } else {
          return '${minutes}m';
        }
      }
    }
    return duration.toString();
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
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
          'Conferma Appuntamento Admin',
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Admin
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF4CAF50),
                      Color(0xFF45A049),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.admin_panel_settings,
                      color: Colors.white,
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Conferma Prenotazione Admin',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Verifica i dettagli e conferma l\'appuntamento',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Dati Cliente
              _buildDetailSection(
                'Cliente',
                Icons.person,
                '${widget.clientData['nome']} ${widget.clientData['cognome']}',
                widget.clientData['telefono'] ?? 'Telefono non inserito',
              ),

              const SizedBox(height: 16),

              // Stylist
              _buildDetailSection(
                'Stylist',
                Icons.face,
                widget.selectedStylist['descrizione'],
                'Specialista ${widget.section}',
              ),

              const SizedBox(height: 16),

              // Data e Orario
              _buildDetailSection(
                'Data e Orario',
                Icons.access_time,
                _formatDate(widget.selectedDate),
                '${widget.selectedTimeSlot} - ${_getEndTime()} (${_formatDuration(widget.totalDuration)})',
              ),

              const SizedBox(height: 16),

              // Servizi
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF2d2d2d),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.content_cut,
                            color: Colors.green,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Servizi Selezionati',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    ...widget.selectedServices.map((service) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          Container(
                            width: 4,
                            height: 20,
                            decoration: BoxDecoration(
                              color: Colors.green,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  service['descrizione'],
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  _formatServiceDuration(service['durata']),
                                  style: TextStyle(
                                    color: Colors.grey[400],
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '${service['prezzo']}',
                            style: const TextStyle(
                              color: Colors.green,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    )).toList(),

                    const SizedBox(height: 16),
                    Container(
                      height: 1,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(height: 16),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'TOTALE',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '€${widget.totalPrice.toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: Colors.green,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Metodo Pagamento
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.green.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.payment,
                      color: Colors.green,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Pagamento in Loco',
                            style: TextStyle(
                              color: Colors.green,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Il cliente pagherà direttamente al salone al momento del servizio. L\'appuntamento verrà comunque registrato nel sistema.',
                            style: TextStyle(
                              color: Colors.grey[300],
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Container(
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
              onPressed: _isBooking ? null : _confirmBooking,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 3,
              ),
              child: _isBooking
                  ? const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  ),
                  SizedBox(width: 12),
                  Text(
                    'Creazione appuntamento...',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              )
                  : const Text(
                'CONFERMA E CREA APPUNTAMENTO',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailSection(String title, IconData icon, String mainText, String subText) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF2d2d2d),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: Colors.green,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            mainText,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subText,
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}