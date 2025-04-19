import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ProjectDetailPage extends StatelessWidget {
  final String projetId;

  const ProjectDetailPage({super.key, required this.projetId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Détails du projet')),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection('projets').doc(projetId).get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('Projet introuvable.'));
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (data['imageUrl'] != null)
                  Image.network(data['imageUrl']),
                const SizedBox(height: 20),
                Text(
                  data['titre'] ?? 'Titre inconnu',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Text(data['resume'] ?? 'Pas de résumé'),
                const SizedBox(height: 20),
                const Text('Description complète :', style: TextStyle(fontSize: 18)),
                const SizedBox(height: 8),
                Text(data['description'] ?? 'Aucune description fournie.'),
              ],
            ),
          );
        },
      ),
    );
  }
}
