import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class AccountPage extends StatefulWidget {
  @override
  _AccountPageState createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  final user = FirebaseAuth.instance.currentUser!;
  final _formKey = GlobalKey<FormState>();
  TextEditingController _nameController = TextEditingController();
  String? _photoUrl;
  File? _imageFile;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    var snapshot = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    var data = snapshot.data()!;
    setState(() {
      _nameController.text = data['nom'] ?? '';
      _photoUrl = data['photo_url'];
    });
  }

  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  Future<String?> _uploadImage(File image) async {
    try {
      final ref = FirebaseStorage.instance.ref().child('profile_pictures').child('${user.uid}.jpg');
      await ref.putFile(image);
      return await ref.getDownloadURL();
    } catch (e) {
      print("Erreur d'upload: $e");
      return null;
    }
  }

  Future<void> _saveChanges() async {
    if (_formKey.currentState!.validate()) {
      String? newPhotoUrl = _photoUrl;
      if (_imageFile != null) {
        newPhotoUrl = await _uploadImage(_imageFile!);
      }

      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'nom': _nameController.text,
        'photo_url': newPhotoUrl,
      });

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Profil mis à jour")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Paramètres du profil")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              GestureDetector(
                onTap: _pickImage,
                child: CircleAvatar(
                  radius: 50,
                  backgroundImage: _imageFile != null
                      ? FileImage(_imageFile!)
                      : _photoUrl != null
                      ? NetworkImage(_photoUrl!) as ImageProvider
                      : AssetImage('images/4Cop.png'),
                  child: Align(
                    alignment: Alignment.bottomRight,
                    child: CircleAvatar(
                      backgroundColor: Colors.white,
                      radius: 16,
                      child: Icon(Icons.edit, size: 18, color: Colors.black),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 20),
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(labelText: "Nom"),
                validator: (value) => value == null || value.isEmpty ? "Entrez un nom" : null,
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: _saveChanges,
                child: Text("Enregistrer"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
