import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class AccountPage extends StatefulWidget {
  const AccountPage({Key? key}) : super(key: key);

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  final User _user = FirebaseAuth.instance.currentUser!;
  final _formKey = GlobalKey<FormState>();
  final _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

  // Contrôleurs pour les champs de texte
  late TextEditingController _nameController;
  late TextEditingController _prenomController;
  late TextEditingController _domaineController;
  late TextEditingController _newCountryController;
  late TextEditingController _newSchoolController;
  late TextEditingController _newSkillController;


  // Données du profil
  String? _selectedCountry;
  String? _selectedSchool;
  List<String> _skills = [];
  String? _photoUrl;
  File? _imageFile;
  int _projectCount = 0;
  bool _isLoading = true;
  bool _isSaving = false;

  // Données pour les menus déroulants
  List<String> _countries = [];
  List<String> _schools = [];
  List<String> _availableSkills = [];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _prenomController = TextEditingController();
    _domaineController = TextEditingController();
    _newCountryController = TextEditingController();
    _newSchoolController = TextEditingController();
    _newSkillController = TextEditingController();

    _initializeData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _prenomController.dispose();
    _domaineController.dispose();
    _newCountryController.dispose();
    _newSchoolController.dispose();
    _newSkillController.dispose();

    super.dispose();
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
      // Initialisation des listes si nécessaire
      /**await Future.wait([
        _initializeList('pays', ['France', 'Belgique', 'Cameroun', 'Canada', 'Sénégal']),
        _initializeList('competences', ['Flutter', 'Laravel', 'Firebase', 'Python']),
        _initializeList('ecoles', ['ULB', 'UCLouvain', 'FPMS', 'ENSPY']),
      ]);**/

      // Chargement des listes
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

  Future<void> _initializeList(String collection, List<String> defaults) async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection(collection).get();
      if (snapshot.docs.isEmpty) {
        final batch = FirebaseFirestore.instance.batch();
        for (var item in defaults) {
          final docRef = FirebaseFirestore.instance.collection(collection).doc();
          batch.set(docRef, {'nom': item, 'createdAt': FieldValue.serverTimestamp()});
        }
        await batch.commit();
      }
    } catch (e) {
      debugPrint('Error initializing $collection: $e');
      rethrow;
    }
  }

  Future<List<String>> _getListFromFirebase(String collection) async {
  try {
    final snapshot = await FirebaseFirestore.instance.collection(collection).get();

    // On utilise un Set pour éliminer les doublons
    final uniqueItems = snapshot.docs
        .map((doc) => doc['nom'].toString().trim()) // On enlève les espaces
        .toSet(); // Supprime les doublons automatiquement

    return uniqueItems.toList()..sort(); // On trie si besoin
  } catch (e) {
    debugPrint('Error getting $collection list: $e');
    return [];
  }
}


  Future<void> _loadUserData() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('users').doc(_user.uid).get();
      
      if (snapshot.exists) {
        final data = snapshot.data()!;
        if (_countries.contains(data['pays'])) {
              _selectedCountry = data['pays'];
            } else {
              _selectedCountry = null;
            }
            if (_availableSkills.contains(data['competences'])) {
              _skills = data['competences'];
            } else {
              _skills = [];
            }

            if (_schools.contains(data['ecole'])) {
              _selectedSchool = data['ecole'];
            } else {
              _selectedSchool = null;
            }

        setState(() {
          _nameController.text = data['nom'] ?? '';
          _prenomController.text = data['prenom'] ?? '';
          _domaineController.text = data['domaine'] ?? '';
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
        final snapshot = await FirebaseFirestore.instance
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

      await FirebaseFirestore.instance.collection('users').doc(_user.uid).update({
        'nom': _nameController.text.trim(),
        'prenom': _prenomController.text.trim(),
        'domaine': _domaineController.text.trim(),
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

  Future<void> _addNewCountry() async {
    final newCountry = _newCountryController.text.trim();
    if (newCountry.isEmpty) return;

    try {
      // Ajoutez à Firestore
      await FirebaseFirestore.instance.collection('pays').add({
        'nom': newCountry,
        'createdBy': _user.uid,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Met à jour la liste locale
      setState(() {
        _countries.add(newCountry);
        _selectedCountry = newCountry;
        _newCountryController.clear();
      });
      
      _showSuccessSnackbar('Pays ajouté avec succès');
    } catch (e) {
      debugPrint('Error adding country: $e');
      _showErrorSnackbar('Erreur lors de l\'ajout du pays');
    }
  }
  Future<void> _addNewSkill() async {
  final newSkill = _newSkillController.text.trim();
  if (newSkill.isEmpty) return;

  try {
    // Ajout à Firestore
    await FirebaseFirestore.instance.collection('competences').add({
      'nom': newSkill,
      'createdBy': _user.uid,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Mise à jour de la liste locale
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
    final newSchool = _newSchoolController.text.trim();
    if (newSchool.isEmpty) return;

    try {
      // Ajoutez à Firestore
      await FirebaseFirestore.instance.collection('ecoles').add({
        'nom': newSchool,
        'createdBy': _user.uid,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Met à jour la liste locale
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
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showErrorSnackbar(String message) {
    _scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  Widget _buildProfileImage() {
    return GestureDetector(
      onTap: _pickImage,
      child: Stack(
        alignment: Alignment.bottomRight,
        children: [
          CircleAvatar(
            radius: 60,
            backgroundColor: const Color.fromARGB(255, 154, 111, 111),
            backgroundImage: _imageFile != null
                ? FileImage(_imageFile!)
                : _photoUrl != null
                    ? NetworkImage(_photoUrl!)
                    : const AssetImage('images/default_profile.png') as ImageProvider,
            child: _imageFile == null && _photoUrl == null
                ? const Icon(Icons.person, size: 60, color: Colors.grey)
                : null,
          ),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.edit, size: 20, color: Colors.black),
          ),
        ],
      ),
    );
  }

  Widget _buildSkillsChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: _skills.map((skill) => Chip(
        label: Text(skill),
        deleteIcon: const Icon(Icons.close, size: 16),
        onDeleted: () => setState(() => _skills.remove(skill)),
      )).toList(),
    );
  }

  Widget _buildCountryField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          value:  _countries.contains(_selectedCountry) ? _selectedCountry : null,
          items: _countries.toSet().toList()
          .map((String country) {
            return DropdownMenuItem<String>(
              value: country,
              child: Text(country),
            );
          }).toList(),
          onChanged: (value) => setState(() => _selectedCountry = value),
          decoration: const InputDecoration(
            labelText: "Pays",
            prefixIcon: Icon(Icons.location_on),
            border: OutlineInputBorder(),
          ),
          validator: (value) => value == null
              ? "Veuillez sélectionner un pays"
              : null,
          isExpanded: true,
          hint: const Text('Sélectionnez un pays'),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _newCountryController,
                decoration: const InputDecoration(
                  labelText: "Ou ajouter un nouveau pays",
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: _addNewCountry,
              tooltip: 'Ajouter ce pays',
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSchoolField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          value: _schools.contains(_selectedSchool) ? _selectedSchool : null,
          items: _schools.toSet().toList()
          .map((String school) {
            return DropdownMenuItem<String>(
              value: school,
              child: Text(school),
            );
          }).toList(),
          onChanged: (value) => setState(() => _selectedSchool = value),
          decoration: const InputDecoration(
            labelText: "École",
            prefixIcon: Icon(Icons.school),
            border: OutlineInputBorder(),
          ),
          isExpanded: true,
          hint: const Text('Sélectionnez une école'),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _newSchoolController,
                decoration: const InputDecoration(
                  labelText: "Ou ajouter une nouvelle école",
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: _addNewSchool,
              tooltip: 'Ajouter cette école',
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLoadingIndicator() {
    return const Center(
      child: CircularProgressIndicator(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldMessengerKey,
      appBar: AppBar(
        title: const Text("Mon Profil"),
        centerTitle: true,
        elevation: 0,
      ),
      body: _isLoading
          ? _buildLoadingIndicator()
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(child: _buildProfileImage()),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: "Nom",
                        prefixIcon: Icon(Icons.person),
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) => value?.trim().isEmpty ?? true
                          ? "Veuillez entrer votre nom"
                          : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _prenomController,
                      decoration: const InputDecoration(
                        labelText: "Prénom",
                        prefixIcon: Icon(Icons.person_outline),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildCountryField(),
                    const SizedBox(height: 16),
                    _buildSchoolField(),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _domaineController,
                      decoration: const InputDecoration(
                        labelText: "Domaine d'étude",
                        prefixIcon: Icon(Icons.work_outline),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text("Compétences:", style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    _buildSkillsChips(),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: "Ajouter une compétence",
                        prefixIcon: Icon(Icons.add_circle_outline),
                        border: OutlineInputBorder(),
                      ),
                      items: _availableSkills
                          .where((skill) => !_skills.contains(skill))
                          .map((skill) => DropdownMenuItem(
                                value: skill,
                                child: Text(skill),
                              ))
                          .toList(),
                      onChanged: (skill) {
                        if (skill != null) {
                          setState(() => _skills.add(skill));
                        }
                      },
                    ),
                    const SizedBox(height: 24),
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.folder_special, color: Colors.blue),
                        title: const Text("Projets"),
                        subtitle: Text("$_projectCount projet${_projectCount != 1 ? 's' : ''}"),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          // Navigation vers les projets
                        },
                      ),
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: _isSaving ? null : _saveChanges,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text("SAUVEGARDER LES MODIFICATIONS"),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}