import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'home_page.dart';
import 'admin_dashboard_page.dart';
import 'onesignal_push_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool _isLoading = false;
  bool _showRegisterForm = false;

  // Controllers per login
  final _loginEmailController = TextEditingController();
  final _loginPasswordController = TextEditingController();
  final _loginFormKey = GlobalKey<FormState>();

  // Controllers per la registrazione
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nomeController = TextEditingController();
  final _cognomeController = TextEditingController();
  final _telefonoController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _loginEmailController.dispose();
    _loginPasswordController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _nomeController.dispose();
    _cognomeController.dispose();
    _telefonoController.dispose();
    super.dispose();
  }

  // 🔥 Sincronizza utente con Supabase
  Future<void> syncUserWithSupabase({
    String? nome,
    String? cognome,
    String? telefono,
    String? email,
  }) async {
    final authUser = firebase_auth.FirebaseAuth.instance.currentUser;
    final supabase = Supabase.instance.client;

    if (authUser == null) {
      print('❌ Nessun utente Firebase autenticato');
      return;
    }

    final userId = authUser.uid;
    print('🔍 Sincronizzazione per UID: $userId');

    try {
      // Controlla se l'utente esiste già
      final existing = await supabase
          .from('USERS')
          .select()
          .eq('uid', userId)
          .maybeSingle();

      print('🔍 Utente esistente: ${existing != null ? 'SÌ' : 'NO'}');

      if (existing != null) {
        print('✅ Utente già presente in Supabase');
        return;
      }

      // Prepara i dati per l'inserimento
      final userData = {
        'uid': userId,
        'nome': nome ?? authUser.displayName?.split(' ').first ?? 'Utente',
        'cognome': cognome ?? (authUser.displayName?.split(' ').length != null && authUser.displayName!.split(' ').length > 1
            ? authUser.displayName!.split(' ').skip(1).join(' ')
            : ''),
        'email': email ?? authUser.email ?? '',
        'telefono': telefono ?? authUser.phoneNumber ?? '',
        'created_at': DateTime.now().toIso8601String(),
        'codice_fiscale': null,
        'password': null,
        'role': 'user',
      };

      print('📝 Dati da inserire: $userData');

      // Crea nuovo utente
      final response = await supabase
          .from('USERS')
          .insert(userData)
          .select()
          .single();

      print('✅ Utente registrato su Supabase: $response');

      if (mounted) {
        _showSuccessMessage('✅ Profilo creato con successo!');
      }

    } catch (e) {
      print('❌ Errore sincronizzazione Supabase: $e');
      if (mounted) {
        _showErrorMessage('⚠️ Errore durante la sincronizzazione del profilo');
      }
    }
  }

  // ✅ NUOVO: Controlla se l'utente è bannato (segnalazione livello 2)
  Future<bool> _checkIfBanned(String firebaseUid) async {
    try {
      final supabase = Supabase.instance.client;

      // Recupera user_id
      final userResponse = await supabase
          .from('USERS')
          .select('id')
          .eq('uid', firebaseUid)
          .single();

      final userId = userResponse['id'];

      // Controlla segnalazioni attive
      final segnalazioniResponse = await supabase
          .from('USERS_SEGNALAZIONI')
          .select('segnalazione_id')
          .eq('users_id', userId)
          .isFilter('deleted_at', null);

      List<Map<String, dynamic>> segnalazioni =
      List<Map<String, dynamic>>.from(segnalazioniResponse);

      // Controlla se ha segnalazione livello 2 (account bloccato)
      final isBanned = segnalazioni.any((s) => s['segnalazione_id'] == 2);

      if (isBanned) {
        print('🚫 Account bloccato - Livello 2');
      }

      return isBanned;
    } catch (e) {
      print('⚠️ Errore controllo ban: $e');
      return false; // In caso di errore, non bloccare l'accesso
    }
  }

  // ✅ NUOVO: Mostra dialog account bloccato
  void _showBannedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2d2d2d),
        title: Row(
          children: [
            const Icon(Icons.block, color: Colors.red, size: 32),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Account Bloccato',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        content: const Text(
          'Il tuo account è stato bloccato dall\'amministratore.\n\n'
              'Per maggiori informazioni, contatta il negozio direttamente.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // 🔹 Controlla ruolo e naviga di conseguenza
  Future<void> _checkUserRoleAndNavigate() async {
    try {
      final user = firebase_auth.FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // ✅ CONTROLLO BAN PRIMA DI TUTTO
      final isBanned = await _checkIfBanned(user.uid);

      if (isBanned) {
        // Logout immediato
        await firebase_auth.FirebaseAuth.instance.signOut();

        if (mounted) {
          setState(() => _isLoading = false);
          _showBannedDialog();
        }
        return;
      }

      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('USERS')
          .select('role, nome, cognome')
          .eq('uid', user.uid)
          .maybeSingle();

      if (response == null) {
        _showErrorMessage('Errore: utente non trovato nel sistema');
        return;
      }

      final userRole = response['role']?.toString().toLowerCase() ?? 'user';

      // ✅ Registra su OneSignal
      await OneSignalPushService.loginUser(user.uid);
      print('✅ OneSignal login completato');

      if (mounted) {
        if (userRole == 'admin') {
          _showSuccessMessage('Benvenuto Admin ${response['nome'] ?? ''}!');
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const AdminDashboardPage()),
                (route) => false,
          );
        } else {
          _showSuccessMessage('✅ Accesso effettuato con successo!');
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const HomePage()),
                (route) => false,
          );
        }
      }

    } catch (e) {
      print('Errore controllo ruolo: $e');
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const HomePage()),
              (route) => false,
        );
      }
    }
  }

  // 🔹 Login con Google
  Future<void> signInWithGoogle() async {
    setState(() => _isLoading = true);

    try {
      print('📱 Piattaforma: ${Platform.isIOS ? "iOS" : "Android"}');

      final GoogleSignIn googleSignIn = Platform.isIOS
          ? GoogleSignIn(
        clientId: '1025005736352-g9bc0uddu4jch9jhicrqpb076089l487.apps.googleusercontent.com',
      )
          : GoogleSignIn();

      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

      if (googleUser == null) {
        print('⚠️ Login Google annullato dall\'utente');
        setState(() => _isLoading = false);
        return;
      }

      print('✅ Utente Google selezionato: ${googleUser.email}');

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      print('✅ Token ottenuti');

      final credential = firebase_auth.GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      print('✅ Credential creato, accesso a Firebase...');

      final userCredential = await firebase_auth.FirebaseAuth.instance.signInWithCredential(credential);

      print('✅ Accesso Firebase completato: ${userCredential.user?.uid}');

      if (userCredential.user != null) {
        // Sincronizza con Supabase
        await syncUserWithSupabase(
          nome: googleUser.displayName?.split(' ').first,
          cognome: googleUser.displayName != null && googleUser.displayName!.split(' ').length > 1
              ? googleUser.displayName!.split(' ').skip(1).join(' ')
              : null,
          email: googleUser.email,
          telefono: null,
        );

        // ✅ Controlla ban e naviga
        await _checkUserRoleAndNavigate();
      }
    } catch (e) {
      print('❌ Errore Google Sign-In: $e');
      if (mounted) {
        _showErrorMessage('❌ Errore durante il login con Google: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // 🍎 Login con Apple - iOS only
  Future<void> signInWithApple() async {
    setState(() => _isLoading = true);

    try {
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      final oauthCredential = firebase_auth.OAuthProvider('apple.com').credential(
        idToken: appleCredential.identityToken,
        accessToken: appleCredential.authorizationCode,
      );

      final userCredential = await firebase_auth.FirebaseAuth.instance
          .signInWithCredential(oauthCredential);

      if (userCredential.user != null) {
        // Apple fornisce nome/cognome solo al PRIMO login
        final fullName = appleCredential.givenName != null
            ? '${appleCredential.givenName} ${appleCredential.familyName ?? ''}'.trim()
            : null;

        await syncUserWithSupabase(
          nome: appleCredential.givenName,
          cognome: appleCredential.familyName,
          email: appleCredential.email ?? userCredential.user?.email,
          telefono: null,
        );
        await OneSignalPushService.loginUser(userCredential.user!.uid);
        await _checkUserRoleAndNavigate();
      }
    } catch (e) {
      print('❌ Errore Apple Sign-In: $e');
      if (mounted) {
        _showErrorMessage('❌ Errore durante il login con Apple: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // 🔹 Login con Email/Password
  Future<void> signInWithEmail() async {
    if (!_loginFormKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final userCredential = await firebase_auth.FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _loginEmailController.text.trim(),
        password: _loginPasswordController.text,
      );

      if (userCredential.user != null) {
        // ✅ Controlla ban e naviga
        await _checkUserRoleAndNavigate();
      }
    } on firebase_auth.FirebaseAuthException catch (e) {
      String message = 'Errore durante l\'accesso';

      switch (e.code) {
        case 'user-not-found':
          message = 'Utente non trovato. Verifica l\'email o registrati.';
          break;
        case 'wrong-password':
          message = 'Password errata.';
          break;
        case 'invalid-email':
          message = 'Formato email non valido.';
          break;
        case 'user-disabled':
          message = 'Account disabilitato.';
          break;
        case 'invalid-credential':
          message = 'Credenziali non valide.';
          break;
      }

      if (mounted) {
        _showErrorMessage(message);
      }
    } catch (e) {
      if (mounted) {
        _showErrorMessage('❌ Errore durante l\'accesso: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // 📝 Registrazione con email
  Future<void> registerWithEmail() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      print('📝 Inizio registrazione...');

      final userCredential = await firebase_auth.FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      print('✅ Utente creato in Firebase: ${userCredential.user?.uid}');

      if (userCredential.user != null) {
        await userCredential.user!.updateDisplayName(
          '${_nomeController.text.trim()} ${_cognomeController.text.trim()}',
        );

        print('✅ Display name aggiornato');

        await syncUserWithSupabase(
          nome: _nomeController.text.trim(),
          cognome: _cognomeController.text.trim(),
          telefono: _telefonoController.text.trim(),
          email: _emailController.text.trim(),
        );

        // ✅ Registra su OneSignal
        await OneSignalPushService.loginUser(userCredential.user!.uid);

        if (mounted) {
          _showSuccessMessage('✅ Registrazione completata con successo!');
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const HomePage()),
                (route) => false,
          );
        }
      }
    } on firebase_auth.FirebaseAuthException catch (e) {
      String message = 'Errore durante la registrazione';

      switch (e.code) {
        case 'email-already-in-use':
          message = 'Email già registrata. Prova ad accedere.';
          break;
        case 'weak-password':
          message = 'Password troppo debole. Usa almeno 6 caratteri.';
          break;
        case 'invalid-email':
          message = 'Formato email non valido.';
          break;
      }

      print('❌ FirebaseAuthException: ${e.code} - $message');
      if (mounted) {
        _showErrorMessage(message);
      }
    } catch (e) {
      print('❌ Errore generico registrazione: $e');
      if (mounted) {
        _showErrorMessage('❌ Errore durante la registrazione: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1a1a1a),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 40),

              // Logo
              Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      spreadRadius: 5,
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.asset(
                    'assets/images/logo.jpg',
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: Colors.white,
                        child: const Icon(
                          Icons.content_cut,
                          size: 80,
                          color: Color(0xFF1a1a1a),
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 30),

              // Titolo
              const Text(
                'ArtDecò',
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 2,
                ),
              ),
              const Text(
                'Parrucchieri',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w300,
                  color: Colors.white70,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 8),

              // Sottotitolo
              Text(
                'Eleganza e stile per ogni occasione',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[400],
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 50),

              // Form di registrazione (condizionale)
              if (_showRegisterForm) _buildRegistrationForm(),

              // Pulsanti di login (condizionale)
              if (!_showRegisterForm) _buildLoginButtons(),

              const SizedBox(height: 20),

              // Toggle tra login e registrazione
              _buildToggleButton(),

              // ✅ Pulsante modalità ospite (solo nella schermata di login, non registrazione)
              if (!_showRegisterForm) ...[
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (context) => const HomePage()),
                          (route) => false,
                    );
                  },
                  child: const Text(
                    'Continua senza registrarti →',
                    style: TextStyle(
                      color: Colors.white38,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoginButtons() {
    return Column(
      children: [
        // Pulsante Google Sign-In
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton.icon(
            onPressed: _isLoading ? null : signInWithGoogle,
            icon: _isLoading
                ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.black87),
              ),
            )
                : Image.network(
              'https://developers.google.com/identity/images/g-logo.png',
              width: 20,
              height: 20,
              errorBuilder: (context, error, stackTrace) {
                return const Icon(Icons.login, size: 20, color: Color(0xFF1a1a1a));
              },
            ),
            label: Text(
              _isLoading ? 'Accesso in corso...' : 'Accedi con Google',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF1a1a1a),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 3,
            ),
          ),
        ),
        const SizedBox(height: 30),

        // Divider con "OPPURE"
        Row(
          children: [
            Expanded(child: Divider(color: Colors.grey[600])),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'OPPURE',
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Expanded(child: Divider(color: Colors.grey[600])),
          ],
        ),
        const SizedBox(height: 12),

// Pulsante Apple Sign-In (solo iOS)
        if (Platform.isIOS)
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : signInWithApple,
              icon: _isLoading
                  ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
                ),
              )
                  : const Icon(Icons.apple, size: 22, color: Colors.white),
              label: Text(
                _isLoading ? 'Accesso in corso...' : 'Accedi con Apple',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: Colors.white24),
                ),
                elevation: 3,
              ),
            ),
          ),

        const SizedBox(height: 30),

// Divider con "OPPURE"

        // Form di login con email/password
        Form(
          key: _loginFormKey,
          child: Column(
            children: [
              // Email
              TextFormField(
                controller: _loginEmailController,
                keyboardType: TextInputType.emailAddress,
                decoration: _inputDecoration(
                  labelText: 'Email',
                  prefixIcon: const Icon(Icons.email_outlined, color: Colors.white70),
                ),
                style: const TextStyle(color: Colors.white),
                validator: _emailValidator,
              ),
              const SizedBox(height: 16),

              // Password
              TextFormField(
                controller: _loginPasswordController,
                obscureText: true,
                decoration: _inputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock_outline, color: Colors.white70),
                ),
                style: const TextStyle(color: Colors.white),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'La password è richiesta';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // Pulsante Accedi
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : signInWithEmail,
                  style: _primaryButtonStyle(),
                  child: _isLoading
                      ? const CircularProgressIndicator(
                    color: Color(0xFF1a1a1a),
                    strokeWidth: 2,
                  )
                      : const Text(
                    'Accedi',
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
    );
  }

  Widget _buildRegistrationForm() {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          // Nome
          TextFormField(
            controller: _nomeController,
            decoration: _inputDecoration(
              labelText: 'Nome',
              prefixIcon: const Icon(Icons.person_outline, color: Colors.white70),
            ),
            style: const TextStyle(color: Colors.white),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Il nome è richiesto';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Cognome
          TextFormField(
            controller: _cognomeController,
            decoration: _inputDecoration(
              labelText: 'Cognome',
              prefixIcon: const Icon(Icons.person_outline, color: Colors.white70),
            ),
            style: const TextStyle(color: Colors.white),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Il cognome è richiesto';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Email
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: _inputDecoration(
              labelText: 'Email',
              prefixIcon: const Icon(Icons.email_outlined, color: Colors.white70),
            ),
            style: const TextStyle(color: Colors.white),
            validator: _emailValidator,
          ),
          const SizedBox(height: 16),

          // Telefono
          TextFormField(
            controller: _telefonoController,
            keyboardType: TextInputType.phone,
            decoration: _inputDecoration(
              labelText: 'Telefono',
              prefixIcon: const Icon(Icons.phone_outlined, color: Colors.white70),
            ),
            style: const TextStyle(color: Colors.white),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Il telefono è richiesto';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Password
          TextFormField(
            controller: _passwordController,
            obscureText: true,
            decoration: _inputDecoration(
              labelText: 'Password',
              prefixIcon: const Icon(Icons.lock_outline, color: Colors.white70),
            ),
            style: const TextStyle(color: Colors.white),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'La password è richiesta';
              }
              if (value.length < 6) {
                return 'La password deve essere di almeno 6 caratteri';
              }
              return null;
            },
          ),
          const SizedBox(height: 24),

          // Pulsante Registrati
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _isLoading ? null : registerWithEmail,
              style: _primaryButtonStyle(),
              child: _isLoading
                  ? const CircularProgressIndicator(
                color: Color(0xFF1a1a1a),
                strokeWidth: 2,
              )
                  : const Text(
                'Registrati',
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

  Widget _buildToggleButton() {
    return TextButton(
      onPressed: () {
        setState(() {
          _showRegisterForm = !_showRegisterForm;
          _formKey.currentState?.reset();
          _loginFormKey.currentState?.reset();
          _clearAllControllers();
        });
      },
      child: Text(
        _showRegisterForm
            ? 'Hai già un account? Accedi'
            : 'Non hai un account? Registrati',
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 16,
          decoration: TextDecoration.underline,
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String labelText,
    required Widget prefixIcon,
  }) {
    return InputDecoration(
      labelText: labelText,
      prefixIcon: prefixIcon,
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
    );
  }

  ButtonStyle _primaryButtonStyle() {
    return ElevatedButton.styleFrom(
      backgroundColor: Colors.white,
      foregroundColor: const Color(0xFF1a1a1a),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: 3,
    );
  }

  String? _emailValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'L\'email è richiesta';
    }
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
      return 'Formato email non valido';
    }
    return null;
  }

  void _clearAllControllers() {
    _loginEmailController.clear();
    _loginPasswordController.clear();
    _emailController.clear();
    _passwordController.clear();
    _nomeController.clear();
    _cognomeController.clear();
    _telefonoController.clear();
  }
}