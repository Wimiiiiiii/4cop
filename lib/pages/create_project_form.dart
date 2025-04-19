import 'package:flutter/material.dart';

class CreateProjectForm extends StatefulWidget {
  @override
  _CreateProjectFormState createState() => _CreateProjectFormState();
}

class _CreateProjectFormState extends State<CreateProjectForm> {
  final _formKey = GlobalKey<FormState>();
  final _titreController = TextEditingController();
  final _resumeController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Créer un Projet')),
      body: Padding(
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
                maxLines: 3,
              ),
              Spacer(),
              Row(
                children: [
                  ElevatedButton(onPressed: () {/* Brouillon */}, child: Text('Brouillon')),
                  Spacer(),
                  ElevatedButton(
                    onPressed: () {
                      if (_formKey.currentState!.validate()) {
                        // Sauvegarde ici
                      }
                    },
                    child: Text('Valider'),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}
