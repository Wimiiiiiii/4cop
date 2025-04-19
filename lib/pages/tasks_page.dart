import 'package:flutter/material.dart';

class TasksPage extends StatelessWidget {
  final List<Map<String, String>> tasks = [
    {"task": "Créer la maquette", "status": "Fait"},
    {"task": "Rédiger les specs", "status": "En cours"},
    {"task": "Coder l’interface", "status": "À faire"},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Tâches / Diagrammes')),
      body: ListView.builder(
        itemCount: tasks.length,
        itemBuilder: (context, index) {
          final task = tasks[index];
          return ListTile(
            leading: Icon(Icons.check_circle_outline),
            title: Text(task["task"] ?? ""),
            subtitle: Text("Statut : ${task["status"]}"),
            trailing: Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              // futur affichage de diagramme ou détail
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Ajouter une nouvelle tâche
        },
        child: Icon(Icons.add),
      ),
    );
  }
}
