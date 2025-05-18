import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:fourcoop/auth_page.dart';

class AccountPage extends StatefulWidget {
  const AccountPage({Key? key}) : super(key: key);

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  final User _user = FirebaseAuth.instance.currentUser!;
  final _formKey = GlobalKey<FormState>();
  final _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

  late TextEditingController _nameController;
  late TextEditingController _prenomController;
  late TextEditingController _newCountryController;
  late TextEditingController _newSchoolController;
  late TextEditingController _newSkillController;

  String? _selectedCountry;
  String? _selectedSchool;
  List<String> _skills = [];
  String? _photoUrl;
  File? _imageFile;
  int _projectCount = 0;
  bool _isLoading = true;
  bool _isSaving = false;

  List<String> _countries = [];
  List<String> _schools = [];
  List<String> _availableSkills = [];

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _initializeData();
  }

  void _initializeControllers() {
    _nameController = TextEditingController();
    _prenomController = TextEditingController();
    _newCountryController = TextEditingController();
    _newSchoolController = TextEditingController();
    _newSkillController = TextEditingController();
  }

  Future<void> _initializeData() async {
    try {
      await Future.wait([
        _loadDropdownData(),
        _loadUserData(),
        _loadProjectCount(),
      ]);
    } catch (e) {
      _showErrorSnackbar('Erreur lors du chargement des données');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadDropdownData() async {
    try {
      final results = await Future.wait([
        _getListFromFirebase('pays'),
        _getListFromFirebase('competences'),
        _getListFromFirebase('ecoles'),
      ]);

      setState(() {
        _countries = results[0];
        _availableSkills = results[1];
        _schools = results[2];
      });
    } catch (e) {
      debugPrint('Error loading dropdown data: $e');
      _showErrorSnackbar('Erreur de chargement des listes');
    }
  }

  Future<List<String>> _getListFromFirebase(String collection) async {
    try {
      final snapshot =
          await FirebaseFirestore.instance.collection(collection).get();
      final uniqueItems =
          snapshot.docs.map((doc) => doc['nom'].toString().trim()).toSet();
      return uniqueItems.toList()..sort();
    } catch (e) {
      debugPrint('Error getting $collection list: $e');
      return [];
    }
  }

  Future<void> _loadUserData() async {
    try {
      final snapshot =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(_user.uid)
              .get();

      if (snapshot.exists) {
        final data = snapshot.data()!;
        setState(() {
          _nameController.text = data['nom'] ?? '';
          _prenomController.text = data['prenom'] ?? '';
          _selectedCountry = data['pays'] ?? '';
          _selectedSchool = data['ecole'] ?? '';
          _skills = List<String>.from(data['competences'] ?? []);
          _photoUrl = data['photo_url'];
        });
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
      _showErrorSnackbar('Erreur de chargement du profil');
    }
  }

  Future<void> _loadProjectCount() async {
    try {
      if (_user.email != null) {
        final snapshot =
            await FirebaseFirestore.instance
                .collection('projets')
                .where('membres', arrayContains: _user.email!)
                .get();
        setState(() => _projectCount = snapshot.docs.length);
      }
    } catch (e) {
      debugPrint('Error loading project count: $e');
    }
  }

  Future<void> _pickImage() async {
    try {
      final pickedFile = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
        maxWidth: 800,
      );
      if (pickedFile != null) {
        setState(() => _imageFile = File(pickedFile.path));
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
      _showErrorSnackbar('Erreur lors de la sélection de l\'image');
    }
  }

  Future<String?> _uploadImage(File image) async {
    try {
      final ref = FirebaseStorage.instance
          .ref()
          .child('profile_pictures')
          .child('${_user.uid}.jpg');
      await ref.putFile(image);
      return await ref.getDownloadURL();
    } catch (e) {
      debugPrint("Erreur d'upload: $e");
      _showErrorSnackbar('Erreur lors de l\'upload de l\'image');
      return null;
    }
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      String? newPhotoUrl = _photoUrl;
      if (_imageFile != null) {
        newPhotoUrl = await _uploadImage(_imageFile!);
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(_user.uid)
          .update({
            'nom': _nameController.text.trim(),
            'prenom': _prenomController.text.trim(),
            'pays': _selectedCountry,
            'ecole': _selectedSchool,
            'competences': _skills,
            'photo_url': newPhotoUrl,
            'last_update': FieldValue.serverTimestamp(),
          });

      _showSuccessSnackbar('Profil mis à jour avec succès');
    } catch (e) {
      debugPrint('Error saving changes: $e');
      _showErrorSnackbar('Erreur lors de la mise à jour du profil');
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Future<void> _addNewSkill() async {
    final newSkill = _newSkillController.text.trim().toUpperCase();
    if (newSkill.isEmpty) return;

    try {
      await FirebaseFirestore.instance.collection('competences').add({
        'nom': newSkill,
        'createdBy': _user.uid,
        'createdAt': FieldValue.serverTimestamp(),
      });

      setState(() {
        _availableSkills.add(newSkill);
        _skills.add(newSkill);
        _newSkillController.clear();
      });

      _showSuccessSnackbar('Compétence ajoutée avec succès');
    } catch (e) {
      debugPrint('Erreur lors de l\'ajout de la compétence: $e');
      _showErrorSnackbar('Erreur lors de l\'ajout de la compétence');
    }
  }

  Future<void> _addNewSchool() async {
    final newSchool = _newSchoolController.text.trim().toUpperCase();
    if (newSchool.isEmpty) return;

    try {
      await FirebaseFirestore.instance.collection('ecoles').add({
        'nom': newSchool,
        'createdBy': _user.uid,
        'createdAt': FieldValue.serverTimestamp(),
      });

      setState(() {
        _schools.add(newSchool);
        _selectedSchool = newSchool;
        _newSchoolController.clear();
      });

      _showSuccessSnackbar('École ajoutée avec succès');
    } catch (e) {
      debugPrint('Error adding school: $e');
      _showErrorSnackbar('Erreur lors de l\'ajout de l\'école');
    }
  }

  void _showSuccessSnackbar(String message) {
    _scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  void _showErrorSnackbar(String message) {
    _scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ScaffoldMessenger(
      key: _scaffoldMessengerKey,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            'Mon Profil',
            style: GoogleFonts.interTight(
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
          centerTitle: true,
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  theme.colorScheme.primary,
                  theme.colorScheme.error,
                  theme.colorScheme.tertiary,
                ],
                stops: const [0, 0.5, 1],
                begin: AlignmentDirectional(-1, -1),
                end: AlignmentDirectional(1, 1),
              ),
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _isSaving ? null : _saveChanges,
              tooltip: 'Enregistrer',
            ),
          ],
        ),
        body:
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        // Profile Picture Section
                        // Dans la méthode build, partie Profile Picture Section
                        Center(
                          child: Stack(
                            children: [
                              Container(
                                // Suppression de la parenthèse ouvrante en trop
                                width: 120,
                                height: 120,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: theme.colorScheme.primary,
                                    width: 3,
                                  ),
                                ),
                                child: ClipOval(
                                  child:
                                      _imageFile != null
                                          ? Image.file(
                                            _imageFile!,
                                            fit: BoxFit.cover,
                                          )
                                          : (_photoUrl != null
                                              ? Image.network(
                                                _photoUrl!,
                                                fit: BoxFit.cover,
                                              )
                                              : Icon(
                                                Icons.person,
                                                size: 60,
                                                color: theme
                                                    .colorScheme
                                                    .onSurface
                                                    .withOpacity(0.6),
                                              )),
                                ),
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: GestureDetector(
                                  onTap: _pickImage,
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.primary,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.camera_alt,
                                      size: 20,
                                      color: theme.colorScheme.onPrimary,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Personal Info Section
                        _buildSection(
                          context,
                          title: 'Informations Personnelles',
                          children: [
                            TextFormField(
                              controller: _nameController,
                              decoration: InputDecoration(
                                labelText: 'Nom',
                                prefixIcon: Icon(
                                  Icons.person,
                                  color: theme.colorScheme.primary,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              validator:
                                  (value) =>
                                      value!.isEmpty ? 'Champ requis' : null,
                              style: GoogleFonts.interTight(),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _prenomController,
                              decoration: InputDecoration(
                                labelText: 'Prénom',
                                prefixIcon: Icon(
                                  Icons.person_outline,
                                  color: theme.colorScheme.primary,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              validator:
                                  (value) =>
                                      value!.isEmpty ? 'Champ requis' : null,
                              style: GoogleFonts.interTight(),
                            ),
                          ],
                        ),

                        // Location & Education Section
                        _buildSection(
                          context,
                          title: 'Localisation et Formation',
                          children: [
                            _buildCountryField(context),
                            const SizedBox(height: 16),
                            _buildSchoolField(context),
                          ],
                        ),

                        // Skills Section
                        _buildSection(
                          context,
                          title: 'Compétences',
                          children: [
                            if (_skills.isNotEmpty) ...[
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children:
                                    _skills
                                        .map(
                                          (skill) => Chip(
                                            label: Text(
                                              skill,
                                              style: GoogleFonts.interTight(),
                                            ),
                                            deleteIcon: Icon(
                                              Icons.close,
                                              size: 16,
                                              color: theme.colorScheme.error,
                                            ),
                                            onDeleted:
                                                () => setState(
                                                  () => _skills.remove(skill),
                                                ),
                                            backgroundColor:
                                                theme
                                                    .colorScheme
                                                    .primaryContainer,
                                          ),
                                        )
                                        .toList(),
                              ),
                              const SizedBox(height: 16),
                            ],
                            Row(
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    hint: Text(
                                      'Sélectionnez une compétence',
                                      style: GoogleFonts.interTight(),
                                    ),
                                    items:
                                        _availableSkills
                                            .map(
                                              (e) => DropdownMenuItem(
                                                value: e,
                                                child: Text(
                                                  e,
                                                  style:
                                                      GoogleFonts.interTight(),
                                                ),
                                              ),
                                            )
                                            .toList(),
                                    onChanged: (value) {
                                      if (value != null &&
                                          !_skills.contains(value)) {
                                        setState(() => _skills.add(value));
                                      }
                                    },
                                    decoration: InputDecoration(
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _newSkillController,
                                    decoration: InputDecoration(
                                      labelText:
                                          'Ajouter une nouvelle compétence',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    style: GoogleFonts.interTight(),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: Icon(Icons.add_circle),
                                  color: theme.colorScheme.primary,
                                  onPressed: _addNewSkill,
                                  tooltip: 'Ajouter cette compétence',
                                ),
                              ],
                            ),
                          ],
                        ),

                        // Statistics Section
                        _buildSection(
                          context,
                          title: 'Statistiques',
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _buildStatisticItem(
                                  context,
                                  icon: Icons.work,
                                  value: _projectCount.toString(),
                                  label: 'Projets',
                                ),
                              ],
                            ),
                          ],
                        ),

                        const SizedBox(height: 24),

                        // Save Button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isSaving ? null : _saveChanges,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              backgroundColor: theme.colorScheme.primary,
                            ),
                            child:
                                _isSaving
                                    ? CircularProgressIndicator(
                                      color: theme.colorScheme.onPrimary,
                                    )
                                    : Text(
                                      'SAUVEGARDER LES MODIFICATIONS',
                                      style: GoogleFonts.interTight(
                                        fontWeight: FontWeight.bold,
                                        color: theme.colorScheme.onPrimary,
                                      ),
                                    ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Bouton de suppression de compte
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.delete, color: Colors.white),
                            label: Text(
                              'Supprimer mon compte',
                              style: GoogleFonts.interTight(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  Theme.of(context).colorScheme.error,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed:
                                _isSaving
                                    ? null
                                    : () async {
                                      final confirm = await showDialog<bool>(
                                        context: context,
                                        builder:
                                            (context) => AlertDialog(
                                              title: const Text(
                                                'Supprimer le compte',
                                              ),
                                              content: const Text(
                                                'Êtes-vous sûr de vouloir supprimer définitivement votre compte ? Cette action est irréversible.',
                                              ),
                                              actions: [
                                                TextButton(
                                                  onPressed:
                                                      () => Navigator.pop(
                                                        context,
                                                        false,
                                                      ),
                                                  child: const Text('Annuler'),
                                                ),
                                                TextButton(
                                                  onPressed:
                                                      () => Navigator.pop(
                                                        context,
                                                        true,
                                                      ),
                                                  child: const Text(
                                                    'Supprimer',
                                                    style: TextStyle(
                                                      color: Colors.red,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                      );
                                      if (confirm == true) {
                                        setState(() => _isSaving = true);
                                        try {
                                          await FirebaseFirestore.instance
                                              .collection('users')
                                              .doc(_user.uid)
                                              .delete();
                                          await _user.delete();
                                          await FirebaseAuth.instance.signOut();
                                          if (mounted) {
                                            Navigator.pushAndRemoveUntil(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) => AuthPage(),
                                              ),
                                              (route) => false,
                                            );
                                          }
                                        } catch (e) {
                                          _showErrorSnackbar(
                                            'Erreur lors de la suppression du compte : $e',
                                          );
                                        } finally {
                                          setState(() => _isSaving = false);
                                        }
                                      }
                                    },
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required List<Widget> children,
  }) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: GoogleFonts.interTight(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildCountryField(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          value:
              _countries.contains(_selectedCountry) ? _selectedCountry : null,
          items:
              _countries
                  .map(
                    (String country) => DropdownMenuItem<String>(
                      value: country,
                      child: Text(country, style: GoogleFonts.interTight()),
                    ),
                  )
                  .toList(),
          onChanged: (value) => setState(() => _selectedCountry = value),
          decoration: InputDecoration(
            labelText: "Pays",
            labelStyle: GoogleFonts.interTight(),
            prefixIcon: Icon(
              Icons.location_on,
              color: Theme.of(context).colorScheme.primary,
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          validator:
              (value) => value == null ? "Veuillez sélectionner un pays" : null,
          isExpanded: true,
          hint: Text('Sélectionnez un pays', style: GoogleFonts.interTight()),
        ),
      ],
    );
  }

  Widget _buildSchoolField(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          value: _schools.contains(_selectedSchool) ? _selectedSchool : null,
          items:
              _schools
                  .map(
                    (String school) => DropdownMenuItem<String>(
                      value: school,
                      child: Text(school, style: GoogleFonts.interTight()),
                    ),
                  )
                  .toList(),
          onChanged: (value) => setState(() => _selectedSchool = value),
          decoration: InputDecoration(
            labelText: "École",
            labelStyle: GoogleFonts.interTight(),
            prefixIcon: Icon(
              Icons.school,
              color: Theme.of(context).colorScheme.primary,
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          isExpanded: true,
          hint: Text('Sélectionnez une école', style: GoogleFonts.interTight()),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _newSchoolController,
                decoration: InputDecoration(
                  labelText: "Ou ajouter une nouvelle école",
                  labelStyle: GoogleFonts.interTight(),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                style: GoogleFonts.interTight(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: Icon(Icons.add),
              color: Theme.of(context).colorScheme.primary,
              onPressed: _addNewSchool,
              tooltip: 'Ajouter cette école',
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatisticItem(
    BuildContext context, {
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            size: 24,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: GoogleFonts.interTight(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.interTight(
            fontSize: 14,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
          ),
        ),
      ],
    );
  }
}
