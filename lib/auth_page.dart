import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'home_page.dart';

class AuthPage extends StatefulWidget {
  @override
  _AuthPageState createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nomController = TextEditingController();
  final _prenomController = TextEditingController();
  final _telephoneController = TextEditingController();
  bool isLogin = true;
  bool isLoading = false;

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
      } else {
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
      String errorMessage;

      switch (e.code) {
        case 'email-already-in-use':
          errorMessage = "Cet email est déjà utilisé.";
          break;
        case 'user-not-found':
          errorMessage = "Aucun utilisateur trouvé avec cet email.";
          break;
        case 'wrong-password':
          errorMessage = "Mot de passe incorrect.";
          break;
        case 'invalid-email':
          errorMessage = "Format d'email invalide.";
          break;
        case 'weak-password':
          errorMessage = "Le mot de passe est trop faible.";
          break;
        default:
          errorMessage = "Une erreur est survenue. Veuillez réessayer.";
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
      );
    }  catch (e, stacktrace) {
  print("Erreur inattendue: $e");
  print("Stacktrace: $stacktrace");

  ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(
  content: Text("Erreur: $e"),
  backgroundColor: Colors.red,
  ),
  );
}
finally {
      setState(() => isLoading = false);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nomController.dispose();
    _prenomController.dispose();
    _telephoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(isLogin ? 'Connexion' : 'Inscription')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              if (!isLogin) ...[
                _buildTextField(_nomController, 'Nom'),
                _buildTextField(_prenomController, 'Prénom'),
                _buildTextField(_telephoneController, 'Téléphone', keyboardType: TextInputType.phone),
              ],
              _buildTextField(_emailController, 'Email', keyboardType: TextInputType.emailAddress),
              _buildTextField(_passwordController, 'Mot de passe', obscureText: true),
              const SizedBox(height: 20),
              isLoading
                  ? CircularProgressIndicator()
                  : ElevatedButton(
                onPressed: handleAuth,
                child: Text(isLogin ? 'Se connecter' : "S'inscrire"),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    isLogin = !isLogin;
                    if (isLogin) {
                      _nomController.clear();
                      _prenomController.clear();
                      _telephoneController.clear();
                    }
                  });
                },
                child: Text(isLogin ? "Créer un compte" : "J'ai déjà un compte"),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label,
      {bool obscureText = false, TextInputType keyboardType = TextInputType.text}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(labelText: label, border: OutlineInputBorder()),
        obscureText: obscureText,
        keyboardType: keyboardType,
        validator: (value) => value == null || value.trim().isEmpty ? 'Champ obligatoire' : null,
      ),
    );
  }
}
