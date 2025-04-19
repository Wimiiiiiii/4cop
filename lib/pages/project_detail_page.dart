import 'package:flutter/material.dart';

class ProjectDetailPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Détails du Projet')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text('Description complète du projet', style: Theme.of(context).textTheme.titleLarge),
            SizedBox(height: 20),
            Text('Détails, tâches, diagrammes...'),
            Spacer(),
            ElevatedButton.icon(
              onPressed: () {
                // Aller vers messagerie
              },
              icon: Icon(Icons.message),
              label: Text("Messagerie"),
            ),
          ],
        ),
      ),
    );
  }
}
