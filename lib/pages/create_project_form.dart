import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';

class CreateProjectForm extends StatefulWidget {
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
  final _contactController = TextEditingController();

  File? _imageFile;
  bool _isUploading = false;

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
    setState(() {
      _isUploading = true;
    });

    String? imageUrl;
    if (_imageFile != null) {
      imageUrl = await _uploadImage(_imageFile!);
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Utilisateur non connecté')),
      );
      return;
    }

    await FirebaseFirestore.instance.collection('projets').add({
      'titre': _titreController.text,
      'resume': _resumeController.text,
      'description': _descriptionController.text,
      'theme': _themeController.text,
      'pays': _paysController.text,
      'duree': _dureeController.text,
      'contact': _contactController.text,
      'createdBy': user.email,
      'createdAt': FieldValue.serverTimestamp(),
      'imageUrl': imageUrl ?? '',
    });

    setState(() {
      _isUploading = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Projet créé avec succès')),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Créer un Projet')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _titreController,
                decoration: InputDecoration(labelText: 'Titre du projet'),
                validator: (val) => val!.isEmpty ? 'Champ requis' : null,
              ),
              TextFormField(
                controller: _resumeController,
                decoration: InputDecoration(labelText: 'Résumé'),
                maxLines: 2,
              ),
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(labelText: 'Description détaillée'),
                maxLines: 4,
              ),
              TextFormField(
                controller: _themeController,
                decoration: InputDecoration(labelText: 'Thème'),
              ),
              TextFormField(
                controller: _paysController,
                decoration: InputDecoration(labelText: 'Pays'),
              ),
              TextFormField(
                controller: _dureeController,
                decoration: InputDecoration(labelText: 'Durée (ex: 3 mois)'),
              ),
              TextFormField(
                controller: _contactController,
                decoration: InputDecoration(labelText: 'Contact du porteur'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: _pickImage,
                    icon: Icon(Icons.photo),
                    label: Text('Ajouter une image'),
                  ),
                  const SizedBox(width: 10),
                  if (_imageFile != null) Text("Image sélectionnée"),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  ElevatedButton(
                    onPressed: () {/* Sauver comme brouillon */},
                    child: Text('Brouillon'),
                  ),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: _isUploading
                        ? null
                        : () {
                      if (_formKey.currentState!.validate()) {
                        _saveProject();
                      }
                    },
                    child: _isUploading
                        ? CircularProgressIndicator(color: Colors.white)
                        : Text('Valider'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
