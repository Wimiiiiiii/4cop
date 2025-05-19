import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:google_fonts/google_fonts.dart';

class CreateProjectForm extends StatefulWidget {
  const CreateProjectForm({Key? key}) : super(key: key);

  @override
  _CreateProjectFormState createState() => _CreateProjectFormState();
}

class _CreateProjectFormState extends State<CreateProjectForm> {
  final _formKey = GlobalKey<FormState>();
  final _titreController = TextEditingController();
  final _resumeController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _themeController = TextEditingController();
  final _paysController = TextEditingController();
  final _dureeController = TextEditingController();

  List<String> themes = [];
  List<String> countries = [];
  bool isLoadingFilters = true;

  File? _imageFile;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _loadThemesAndCountries();
  }

  Future<void> _loadThemesAndCountries() async {
    try {
      final themeSnap =
          await FirebaseFirestore.instance.collection('themes').get();
      final paysSnap =
          await FirebaseFirestore.instance.collection('pays').get();

      setState(() {
        themes =
            themeSnap.docs.map((doc) => doc['nom'].toString()).toSet().toList()
              ..sort();
        countries =
            paysSnap.docs.map((doc) => doc['nom'].toString()).toSet().toList()
              ..sort();
        isLoadingFilters = false;
      });
    } catch (e) {
      print('Erreur lors du chargement des filtres : $e');
      setState(() => isLoadingFilters = false);
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        _imageFile = File(picked.path);
      });
    }
  }

  Future<String?> _uploadImage(File image) async {
    try {
      final ref = FirebaseStorage.instance
          .ref()
          .child('projets_images')
          .child('${DateTime.now().millisecondsSinceEpoch}.jpg');
      await ref.putFile(image);
      return await ref.getDownloadURL();
    } catch (e) {
      print("Erreur lors de l'upload de l'image : $e");
      return null;
    }
  }

  Future<void> _saveProject() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isUploading = true);

    try {
      String? imageUrl;
      if (_imageFile != null) {
        imageUrl = await _uploadImage(_imageFile!);
      }

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Utilisateur non connecté');

      final projetRef = await FirebaseFirestore.instance
          .collection('projets')
          .add({
            'titre': _titreController.text.trim(),
            'resume': _resumeController.text.trim(),
            'description': _descriptionController.text.trim(),
            'statut':'En attente',
            'theme':
                _themeController.text.trim().isNotEmpty
                    ? _themeController.text.trim()
                    : 'Non spécifié',
            'pays':
                _paysController.text.trim().isNotEmpty
                    ? _paysController.text.trim()
                    : 'Non spécifié',
            'duree': _dureeController.text.trim(),
            
            'contact': user.email,
            'imageUrl': imageUrl ?? '',
            'proprietaire': user.uid,
            'membres': [user.email],
            'createdAt': FieldValue.serverTimestamp(),
          });

      await projetRef.collection('membres').doc(user.uid).set({
        'uid': user.uid,
        'email': user.email,
        'joinedAt': FieldValue.serverTimestamp(),
        'role': 'propriétaire',
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Projet créé avec succès'),
          backgroundColor: Theme.of(context).colorScheme.primary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: ${e.toString()}'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    } finally {
      setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            'Nouveau Projet',
            style: GoogleFonts.interTight(
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
          centerTitle: true,
          elevation: 0,
          flexibleSpace: Container(
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
          ),
        ),
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                theme.colorScheme.background.withOpacity(0.3),
                theme.colorScheme.background,
              ],
              stops: [0, 0.3],
            ),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  GestureDetector(
                    onTap: _pickImage,
                    child: Container(
                      height: 180,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceVariant,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                        image:
                            _imageFile != null
                                ? DecorationImage(
                                  image: FileImage(_imageFile!),
                                  fit: BoxFit.cover,
                                )
                                : null,
                      ),
                      child:
                          _imageFile == null
                              ? Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.add_photo_alternate,
                                    size: 48,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'Ajouter une image',
                                    style: GoogleFonts.inter(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              )
                              : null,
                    ),
                  ),
                  SizedBox(height: 24),
                  _buildTextField(
                    controller: _titreController,
                    label: 'Titre du projet*',
                    validator:
                        (val) =>
                            val!.isEmpty ? 'Ce champ est obligatoire' : null,
                  ),
                  SizedBox(height: 16),
                  _buildTextField(
                    controller: _resumeController,
                    label: 'Résumé',
                    maxLines: 3,
                  ),
                  SizedBox(height: 16),
                  _buildTextField(
                    controller: _descriptionController,
                    label: 'Description détaillée',
                    maxLines: 5,
                  ),
                  SizedBox(height: 16),
                  isLoadingFilters
                      ? Center(child: CircularProgressIndicator())
                      : DropdownButtonFormField<String>(
                        value:
                            _paysController.text.isNotEmpty
                                ? _paysController.text
                                : null,
                        decoration: _buildDropdownDecoration('Pays'),
                        items:
                            countries
                                .map(
                                  (pays) => DropdownMenuItem(
                                    value: pays,
                                    child: Text(pays),
                                  ),
                                )
                                .toList(),
                        onChanged:
                            (val) => setState(
                              () => _paysController.text = val ?? '',
                            ),
                      ),
                  SizedBox(height: 16),
                  isLoadingFilters
                      ? Center(child: CircularProgressIndicator())
                      : DropdownButtonFormField<String>(
                        value:
                            _themeController.text.isNotEmpty
                                ? _themeController.text
                                : null,
                        decoration: _buildDropdownDecoration('Thème'),
                        items:
                            themes
                                .map(
                                  (theme) => DropdownMenuItem(
                                    value: theme,
                                    child: Text(theme),
                                  ),
                                )
                                .toList(),
                        onChanged:
                            (val) => setState(
                              () => _themeController.text = val ?? '',
                            ),
                      ),
                  SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value:
                        _dureeController.text.isNotEmpty
                            ? _dureeController.text
                            : null,
                    decoration: _buildDropdownDecoration('Durée'),
                    items:
                        [
                              "Moins d'un mois",
                              ...List.generate(
                                12,
                                (index) => '${index + 1} mois',
                              ),
                            ]
                            .map(
                              (duree) => DropdownMenuItem(
                                value: duree,
                                child: Text(duree),
                              ),
                            )
                            .toList(),
                    onChanged:
                        (val) =>
                            setState(() => _dureeController.text = val ?? ''),
                  ),
                  SizedBox(height: 32),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            // Brouillon
                          },
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            side: BorderSide(color: theme.colorScheme.primary),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            'Enregistrer brouillon',
                            style: GoogleFonts.inter(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _isUploading ? null : _saveProject,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.colorScheme.primary,
                            padding: EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child:
                              _isUploading
                                  ? SizedBox(
                                    height: 24,
                                    width: 24,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                  : Text(
                                    'Publier le projet',
                                    style: GoogleFonts.interTight(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hintText,
    int? maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    final theme = Theme.of(context);
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        labelStyle: GoogleFonts.inter(
          color: theme.colorScheme.onSurface.withOpacity(0.6),
        ),
        hintStyle: GoogleFonts.inter(
          color: theme.colorScheme.onSurface.withOpacity(0.4),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: theme.colorScheme.outline, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: theme.colorScheme.outline, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
        ),
        filled: true,
        fillColor: theme.colorScheme.surface,
        contentPadding: EdgeInsets.all(16),
      ),
      style: GoogleFonts.inter(color: theme.colorScheme.onSurface),
    );
  }

  InputDecoration _buildDropdownDecoration(String label) {
    final theme = Theme.of(context);
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.inter(
        color: theme.colorScheme.onSurface.withOpacity(0.6),
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: theme.colorScheme.outline, width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: theme.colorScheme.outline, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
      ),
      filled: true,
      fillColor: theme.colorScheme.surface,
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    );
  }
}
