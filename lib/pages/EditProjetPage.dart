import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';

class EditProjectPage extends StatefulWidget {
  final String projetId;
  final Map<String, dynamic> initialData;

  const EditProjectPage({
    super.key,
    required this.projetId,
    required this.initialData,
  });

  @override
  State<EditProjectPage> createState() => _EditProjectPageState();
}

class _EditProjectPageState extends State<EditProjectPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titreController;
  late TextEditingController _resumeController;
  late TextEditingController _descriptionController;
  late TextEditingController _themeController;
  late TextEditingController _paysController;
  late TextEditingController _dureeController;
  late TextEditingController _newMemberController;

  List<String> _membres = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _titreController = TextEditingController(text: widget.initialData['titre'] ?? '');
    _resumeController = TextEditingController(text: widget.initialData['resume'] ?? '');
    _descriptionController = TextEditingController(text: widget.initialData['description'] ?? '');
    _themeController = TextEditingController(text: widget.initialData['theme'] ?? '');
    _paysController = TextEditingController(text: widget.initialData['pays'] ?? '');
    _dureeController = TextEditingController(text: widget.initialData['duree'] ?? '');
    _newMemberController = TextEditingController();
    _membres = List<String>.from(widget.initialData['membres'] ?? []);
  }

  @override
  void dispose() {
    _titreController.dispose();
    _resumeController.dispose();
    _descriptionController.dispose();
    _themeController.dispose();
    _paysController.dispose();
    _dureeController.dispose();
    _newMemberController.dispose();
    super.dispose();
  }

  Future<void> _saveProject() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await FirebaseFirestore.instance
          .collection('projets')
          .doc(widget.projetId)
          .update({
        'titre': _titreController.text,
        'resume': _resumeController.text,
        'description': _descriptionController.text,
        'theme': _themeController.text,
        'pays': _paysController.text,
        'duree': _dureeController.text,
        'membres': _membres,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      Navigator.pop(context, {
        'status': 'success',
        'message': 'Projet mis à jour avec succès',
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de la mise à jour: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _addMember() {
    final email = _newMemberController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez entrer un email valide')),
      );
      return;
    }

    if (_membres.contains(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ce membre est déjà dans la liste')),
      );
      return;
    }

    setState(() {
      _membres.add(email);
      _newMemberController.clear();
    });
  }

  void _removeMember(String email) {
    setState(() {
      _membres.remove(email);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Modifier le projet',
          style: GoogleFonts.interTight(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _isLoading ? null : _saveProject,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: _titreController,
                      decoration: InputDecoration(
                        labelText: 'Titre*',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      validator: (value) =>
                          value!.isEmpty ? 'Ce champ est obligatoire' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _resumeController,
                      decoration: InputDecoration(
                        labelText: 'Résumé',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _descriptionController,
                      decoration: InputDecoration(
                        labelText: 'Description',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      maxLines: 5,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _themeController,
                            decoration: InputDecoration(
                              labelText: 'Thème',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _paysController,
                            decoration: InputDecoration(
                              labelText: 'Pays',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _dureeController,
                      decoration: InputDecoration(
                        labelText: 'Durée',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Membres du projet',
                      style: GoogleFonts.interTight(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _newMemberController,
                            decoration: InputDecoration(
                              labelText: 'Ajouter un membre par email',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            keyboardType: TextInputType.emailAddress,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add),
                          onPressed: _addMember,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ..._membres.map((email) => ListTile(
                          title: Text(email),
                          trailing: IconButton(
                            icon: const Icon(Icons.remove_circle_outline),
                            onPressed: () => _removeMember(email),
                          ),
                        )),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _saveProject,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Enregistrer les modifications',
                          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
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