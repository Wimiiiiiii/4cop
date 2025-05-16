import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'pages/mes_projets.dart';
import 'pages/home_page.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({Key? key}) : super(key: key);

  @override
  _AuthPageState createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nomController = TextEditingController();
  final _prenomController = TextEditingController();
  final _telephoneController = TextEditingController();

  bool isLogin = true;
  bool isLoading = false;
  bool passwordVisibility = false;
  final _formKey = GlobalKey<FormState>();
  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nomController.dispose();
    _prenomController.dispose();
    _telephoneController.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  // Fonction de Reinitialisation des mots de passe
  void resetPassword() async {
    if (_emailController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Veuillez entrer votre email pour réinitialiser le mot de passe.')),
      );
      return;
    }

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: _emailController.text.trim());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Email de réinitialisation envoyé.')),
      );
    } on FirebaseAuthException catch (e) {
      String message = _getErrorMessage(e.code);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  // Authentification Classique
  Future<void> handleAuth() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => isLoading = true);

    try {
      UserCredential userCredential;

      if (isLogin) {
        userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
      } 
      else {
        userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );

        final user = userCredential.user;
        if (user != null) {
          await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
            'uid': user.uid,
            'nom': _nomController.text.trim(),
            'prenom': _prenomController.text.trim(),
            'telephone': _telephoneController.text.trim(),
            'email': user.email,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => HomePage()),
      );
    } on FirebaseAuthException catch (e) {
      String errorMessage = _getErrorMessage(e.code);
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage),
          ));
      } finally {
          setState(() => isLoading = false);
        }
  }
  
  String _getErrorMessage(String code) {
    switch (code) {
      case 'email-already-in-use': return "Cet email est déjà utilisé.";
      case 'user-not-found': return "Aucun utilisateur trouvé avec cet email.";
      case 'wrong-password': return "Mot de passe incorrect.";
      case 'invalid-email': return "Format d'email invalide.";
      case 'weak-password': return "Le mot de passe est trop faible.";
      default: return "Une erreur est survenue. Veuillez réessayer.";
    }
  }

  // Authentification par google
  Future<void> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();

      if (googleUser == null) return; // L'utilisateur a annulé

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await FirebaseAuth.instance.signInWithCredential(credential);

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => HomePage()),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur de connexion Google : ${e.toString()}")),
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: Scaffold(
        body: Column(
          children: [
          // Header with gradient
          Container(
          width: double.infinity,
          height: 300,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                theme.colorScheme.primary,
                theme.colorScheme.error,
                theme.colorScheme.tertiary,
              ],
              stops: [0, 0.5, 1],
              begin: AlignmentDirectional(-1, -1),
              end: AlignmentDirectional(1, 1),
            ),
          ),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0x00FFFFFF),
                  theme.colorScheme.background,
                ],
                stops: [0, 1],
                begin: AlignmentDirectional(0, -1),
                end: AlignmentDirectional(0, 1),
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo placeholder - replace with your image
              Image.asset(
                      'assets/images/4Cop.png',
                        width: 137.9,
                        height: 135.4,
                        fit: BoxFit.cover,
                      ),

                SizedBox(height: 12),
                Text(
                  isLogin ? 'Connexion' : 'Inscription',
                  style: GoogleFonts.interTight(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  isLogin
                      ? 'Connectez-vous à votre compte'
                      : 'Créez un nouveau compte',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Colors.white70,
                  ),

                ),
              ],
            ),
          ),
        ),
        // Form section
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                  if (!isLogin) ...[
              _buildTextField(
              controller: _nomController,
              label: 'Nom',
              isLast: false,
            ),
            SizedBox(height: 16),
            _buildTextField(
              controller: _prenomController,
              label: 'Prénom',
              isLast: false,
            ),
            SizedBox(height: 16),
            _buildTextField(
              controller: _telephoneController,
              label: 'Téléphone',
              keyboardType: TextInputType.phone,
              isLast: false,
            ),
            SizedBox(height: 16),
            ],
          _buildTextField(
          controller: _emailController,
          label: 'Email',
          focusNode: _emailFocusNode,
          keyboardType: TextInputType.emailAddress,
            isLast: false,
          ),
          SizedBox(height: 16),
          _buildTextField(
            controller: _passwordController,
            label: 'Mot de passe',
            focusNode: _passwordFocusNode,
            obscureText: !passwordVisibility,
            isLast: true,
            suffixIcon: IconButton(
              icon: Icon(
                passwordVisibility
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                color: theme.colorScheme.secondary,
              ),
              onPressed: () => setState(() => passwordVisibility = !passwordVisibility),
            ),
          ),

          // Bouton mot de passe oublié
          if (isLogin) ...[
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: resetPassword,
                child: Text(
                  'Mot de passe oublié ?',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: theme.colorScheme.secondary,
                  ),
                ),
              ),
            ),
            SizedBox(height: 8),
          ],

          SizedBox(height: 24),
            ElevatedButton(
              onPressed: isLoading ? null : handleAuth,
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                padding: EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: isLoading
                  ? CircularProgressIndicator(color: Colors.white)
                  : Text(
                isLogin ? 'Se connecter' : "S'inscrire",
                style: GoogleFonts.interTight(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            SizedBox(height: 16),
            TextButton(
              onPressed: () => setState(() {
                isLogin = !isLogin;
                if (isLogin) {
                  _nomController.clear();
                  _prenomController.clear();
                  _telephoneController.clear();
                }
              }),
              child: Text(
                isLogin ? "Créer un compte" : "J'ai déjà un compte",
                style: GoogleFonts.inter(
                  color: theme.colorScheme.primary,
                ),
              ),
            ),

            // Bouton google
            ElevatedButton.icon(
              icon: Image.asset(
                '../assets/images/google_logo.png', // Ton logo Google (ou icône Material)
                height: 24,
              ),
              label: Text(
                "Continuer avec Google",
                style: GoogleFonts.inter(fontWeight: FontWeight.bold),
              ),
              onPressed: isLoading ? null : signInWithGoogle,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black87,
                padding: EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
        ],
        ),
        ),
      ),
    ),
    ],
    ),
    ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    FocusNode? focusNode,
    TextInputType? keyboardType,
    bool obscureText = false,
    bool isLast = false,
    Widget? suffixIcon,
  }) {
    final theme = Theme.of(context);

    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      obscureText: obscureText,
      keyboardType: keyboardType,
      textInputAction: isLast ? TextInputAction.done : TextInputAction.next,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.inter(
          color: theme.colorScheme.secondary,
        ),
        filled: true,
        fillColor: theme.colorScheme.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: theme.colorScheme.outline,
            width: 2,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: theme.colorScheme.outline,
            width: 2,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: theme.colorScheme.primary,
            width: 2,
          ),
        ),
        contentPadding: EdgeInsets.all(16),
        suffixIcon: suffixIcon,
      ),
      style: GoogleFonts.inter(
        color: theme.colorScheme.onSurface,
      ),
      validator: (value) => value == null || value.isEmpty ? 'Ce champ est obligatoire' : null,
    );
  }
}