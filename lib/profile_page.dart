import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = false;
  bool _isLoadingUserData = true;

  // Dati utente
  Map<String, dynamic>? _currentUserData;

  // Controllers per dati personali
  final _nomeController = TextEditingController();
  final _cognomeController = TextEditingController();
  final _telefonoController = TextEditingController();
  final _emailController = TextEditingController();
  final _codiceFiscaleController = TextEditingController();
  final _personalFormKey = GlobalKey<FormState>();

  // Controllers per cambio password
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _passwordFormKey = GlobalKey<FormState>();
  bool _obscureCurrentPassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadUserData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nomeController.dispose();
    _cognomeController.dispose();
    _telefonoController.dispose();
    _emailController.dispose();
    _codiceFiscaleController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    setState(() => _isLoadingUserData = true);

    try {
      final user = firebase_auth.FirebaseAuth.instance.currentUser;
      if (user == null) {
        _showErrorMessage('Utente non autenticato');
        return;
      }

      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('USERS')
          .select('nome, cognome, email, telefono, codice_fiscale')
          .eq('uid', user.uid)
          .maybeSingle();

      if (response != null) {
        setState(() {
          _currentUserData = response;
          _nomeController.text = response['nome'] ?? '';
          _cognomeController.text = response['cognome'] ?? '';
          _emailController.text = response['email'] ?? user.email ?? '';
          _telefonoController.text = response['telefono'] ?? '';
          _codiceFiscaleController.text = response['codice_fiscale'] ?? '';
        });
      } else {
        // Se non trovato in Supabase, usa i dati Firebase
        _emailController.text = user.email ?? '';
        final displayName = user.displayName?.split(' ') ?? [];
        if (displayName.isNotEmpty) {
          _nomeController.text = displayName.first;
          if (displayName.length > 1) {
            _cognomeController.text = displayName.skip(1).join(' ');
          }
        }
      }

    } catch (e) {
      print('Errore caricamento dati utente: $e');
      _showErrorMessage('Errore nel caricamento dei dati del profilo');
    } finally {
      setState(() => _isLoadingUserData = false);
    }
  }

  Future<void> _updatePersonalData() async {
    if (!_personalFormKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final user = firebase_auth.FirebaseAuth.instance.currentUser;
      if (user == null) {
        _showErrorMessage('Utente non autenticato');
        return;
      }

      final supabase = Supabase.instance.client;

      // Aggiorna i dati su Supabase
      await supabase
          .from('USERS')
          .update({
        'nome': _nomeController.text.trim(),
        'cognome': _cognomeController.text.trim(),
        'email': _emailController.text.trim(),
        'telefono': _telefonoController.text.trim(),
        'codice_fiscale': _codiceFiscaleController.text.trim().isEmpty
            ? null
            : _codiceFiscaleController.text.trim(),
      })
          .eq('uid', user.uid);

      // Aggiorna display name su Firebase se necessario
      final newDisplayName = '${_nomeController.text.trim()} ${_cognomeController.text.trim()}';
      if (user.displayName != newDisplayName) {
        await user.updateDisplayName(newDisplayName);
      }

      _showSuccessMessage('Dati personali aggiornati con successo');

    } catch (e) {
      print('Errore aggiornamento dati: $e');
      _showErrorMessage('Errore nell\'aggiornamento: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _changePassword() async {
    if (!_passwordFormKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final user = firebase_auth.FirebaseAuth.instance.currentUser;
      if (user == null) {
        _showErrorMessage('Utente non autenticato');
        return;
      }

      // Ri-autentica l'utente con la password corrente
      final credential = firebase_auth.EmailAuthProvider.credential(
        email: user.email!,
        password: _currentPasswordController.text,
      );

      await user.reauthenticateWithCredential(credential);

      // Cambia la password
      await user.updatePassword(_newPasswordController.text);

      _showSuccessMessage('Password cambiata con successo');

      // Pulisci i campi password
      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();

    } on firebase_auth.FirebaseAuthException catch (e) {
      String message = 'Errore nel cambio password';

      switch (e.code) {
        case 'wrong-password':
          message = 'Password corrente errata';
          break;
        case 'weak-password':
          message = 'La nuova password è troppo debole';
          break;
        case 'requires-recent-login':
          message = 'Per sicurezza, esci e accedi nuovamente prima di cambiare la password';
          break;
      }

      _showErrorMessage(message);
    } catch (e) {
      print('Errore cambio password: $e');
      _showErrorMessage('Errore nel cambio password: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
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

  InputDecoration _inputDecoration({
    required String labelText,
    required Widget prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: labelText,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      labelStyle: const TextStyle(color: Colors.white70),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.white30),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.white),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red),
      ),
      filled: true,
      fillColor: const Color(0xFF2d2d2d),
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
          'Il Mio Profilo',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.grey[400],
          labelStyle: const TextStyle(fontWeight: FontWeight.bold),
          tabs: const [
            Tab(
              icon: Icon(Icons.person),
              text: 'Dati Personali',
            ),
            Tab(
              icon: Icon(Icons.lock),
              text: 'Sicurezza',
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: _isLoadingUserData
            ? const Center(
          child: CircularProgressIndicator(color: Colors.white),
        )
            : TabBarView(
          controller: _tabController,
          children: [
            _buildPersonalDataTab(),
            _buildSecurityTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildPersonalDataTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _personalFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue, Colors.blue.withOpacity(0.7)],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(40),
                    ),
                    child: const Icon(
                      Icons.person,
                      size: 40,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '${_nomeController.text} ${_cognomeController.text}'.trim().isEmpty
                        ? 'Il tuo Profilo'
                        : '${_nomeController.text} ${_cognomeController.text}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _emailController.text.isEmpty
                        ? 'Completa il tuo profilo'
                        : _emailController.text,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Campi del form
            TextFormField(
              controller: _nomeController,
              style: const TextStyle(color: Colors.white),
              decoration: _inputDecoration(
                labelText: 'Nome',
                prefixIcon: const Icon(Icons.person_outline, color: Colors.white70),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Il nome è richiesto';
                }
                return null;
              },
            ),

            const SizedBox(height: 16),

            TextFormField(
              controller: _cognomeController,
              style: const TextStyle(color: Colors.white),
              decoration: _inputDecoration(
                labelText: 'Cognome',
                prefixIcon: const Icon(Icons.person_outline, color: Colors.white70),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Il cognome è richiesto';
                }
                return null;
              },
            ),

            const SizedBox(height: 16),

            TextFormField(
              controller: _emailController,
              style: const TextStyle(color: Colors.white),
              keyboardType: TextInputType.emailAddress,
              enabled: false, // Email non modificabile
              decoration: _inputDecoration(
                labelText: 'Email',
                prefixIcon: const Icon(Icons.email_outlined, color: Colors.white70),
              ),
            ),

            const SizedBox(height: 16),

            TextFormField(
              controller: _telefonoController,
              style: const TextStyle(color: Colors.white),
              keyboardType: TextInputType.phone,
              decoration: _inputDecoration(
                labelText: 'Numero di Telefono',
                prefixIcon: const Icon(Icons.phone_outlined, color: Colors.white70),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Il numero di telefono è richiesto per le prenotazioni';
                }
                if (value.trim().length < 10) {
                  return 'Inserisci un numero di telefono valido';
                }
                return null;
              },
            ),

            const SizedBox(height: 16),

            TextFormField(
              controller: _codiceFiscaleController,
              style: const TextStyle(color: Colors.white),
              decoration: _inputDecoration(
                labelText: 'Codice Fiscale (opzionale)',
                prefixIcon: const Icon(Icons.assignment_ind_outlined, color: Colors.white70),
              ),
              validator: (value) {
                if (value != null && value.trim().isNotEmpty && value.trim().length != 16) {
                  return 'Il codice fiscale deve essere di 16 caratteri';
                }
                return null;
              },
            ),

            const SizedBox(height: 32),

            // Pulsante salva
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _updatePersonalData,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                    : const Text(
                  'Salva Modifiche',
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
    );
  }

  Widget _buildSecurityTab() {
    final user = firebase_auth.FirebaseAuth.instance.currentUser;
    final isGoogleUser = user?.providerData.any((info) => info.providerId == 'google.com') ?? false;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.orange, Colors.orange.withOpacity(0.7)],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(40),
                  ),
                  child: const Icon(
                    Icons.security,
                    size: 40,
                    color: Colors.orange,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Sicurezza Account',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Gestisci la sicurezza del tuo account',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          if (isGoogleUser) ...[
            // Messaggio per utenti Google
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Colors.blue,
                    size: 32,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Account Google',
                    style: TextStyle(
                      color: Colors.blue,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Hai effettuato l\'accesso con Google. Per cambiare la password, vai alle impostazioni del tuo account Google.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.grey[300],
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            // Form cambio password per utenti email
            Form(
              key: _passwordFormKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _currentPasswordController,
                    style: const TextStyle(color: Colors.white),
                    obscureText: _obscureCurrentPassword,
                    decoration: _inputDecoration(
                      labelText: 'Password Corrente',
                      prefixIcon: const Icon(Icons.lock_outline, color: Colors.white70),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureCurrentPassword ? Icons.visibility : Icons.visibility_off,
                          color: Colors.white70,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscureCurrentPassword = !_obscureCurrentPassword;
                          });
                        },
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Inserisci la password corrente';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _newPasswordController,
                    style: const TextStyle(color: Colors.white),
                    obscureText: _obscureNewPassword,
                    decoration: _inputDecoration(
                      labelText: 'Nuova Password',
                      prefixIcon: const Icon(Icons.lock, color: Colors.white70),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureNewPassword ? Icons.visibility : Icons.visibility_off,
                          color: Colors.white70,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscureNewPassword = !_obscureNewPassword;
                          });
                        },
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Inserisci la nuova password';
                      }
                      if (value.length < 6) {
                        return 'La password deve essere di almeno 6 caratteri';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _confirmPasswordController,
                    style: const TextStyle(color: Colors.white),
                    obscureText: _obscureConfirmPassword,
                    decoration: _inputDecoration(
                      labelText: 'Conferma Nuova Password',
                      prefixIcon: const Icon(Icons.lock, color: Colors.white70),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirmPassword ? Icons.visibility : Icons.visibility_off,
                          color: Colors.white70,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscureConfirmPassword = !_obscureConfirmPassword;
                          });
                        },
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Conferma la nuova password';
                      }
                      if (value != _newPasswordController.text) {
                        return 'Le password non coincidono';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 32),

                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _changePassword,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                          : const Text(
                        'Cambia Password',
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
          ],

          const SizedBox(height: 32),

          // Informazioni account
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF2d2d2d),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Informazioni Account',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                _buildInfoRow('Email', user?.email ?? 'Non disponibile'),
                _buildInfoRow('Metodo di accesso', isGoogleUser ? 'Google' : 'Email/Password'),
                _buildInfoRow('Account verificato', user?.emailVerified == true ? 'Sì' : 'No'),
                if (user?.metadata.creationTime != null)
                  _buildInfoRow(
                    'Data registrazione',
                    '${user!.metadata.creationTime!.day}/${user!.metadata.creationTime!.month}/${user!.metadata.creationTime!.year}',
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
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
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}