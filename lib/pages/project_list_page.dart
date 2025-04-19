import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'project_detail_page.dart';

class ProjectListPage extends StatefulWidget {
  const ProjectListPage({super.key});

  @override
  State<ProjectListPage> createState() => _ProjectListPageState();
}

class _ProjectListPageState extends State<ProjectListPage> {
  String searchQuery = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Projets'),
        actions: [
          IconButton(icon: const Icon(Icons.message), onPressed: () {/* TODO: messagerie */}),
          IconButton(icon: const Icon(Icons.account_circle), onPressed: () {/* TODO: compte */}),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Rechercher un projet...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() {
                  searchQuery = value.toLowerCase();
                });
              },
            ),
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('projets').orderBy('createdAt', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text("Erreur de chargement des projets."));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("Aucun projet disponible."));
          }

          final filteredProjects = snapshot.data!.docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final titre = data['titre']?.toString().toLowerCase() ?? '';
            return titre.contains(searchQuery);
          }).toList();

          return ListView.builder(
            itemCount: filteredProjects.length,
            itemBuilder: (context, index) {
              final projet = filteredProjects[index];
              final data = projet.data() as Map<String, dynamic>;

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                elevation: 3,
                child: ListTile(
                  title: Text(data['titre'] ?? 'Titre inconnu'),
                  subtitle: Text(
                    data['resume'] ?? 'Pas de résumé',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.star_border),
                    onPressed: () {
                      // TODO: Ajouter aux favoris
                    },
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ProjectDetailPage(projetId: projet.id),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
