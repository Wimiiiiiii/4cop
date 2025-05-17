import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fourcoop/pages/project_detail_page.dart';
import 'package:fourcoop/pages/user_profile_page.dart';

class GroupDetailsPage extends StatefulWidget {
  final String groupId;

  const GroupDetailsPage({Key? key, required this.groupId}) : super(key: key);

  @override
  _GroupDetailsPageState createState() => _GroupDetailsPageState();
}

class _GroupDetailsPageState extends State<GroupDetailsPage> {
  late Future<Map<String, dynamic>> _groupData;
  late Future<List<Map<String, dynamic>>> _membersData = Future.value([]);
  late Future<Map<String, dynamic>> _projectData = Future.value({});

  @override
  void initState() {
    super.initState();
    _loadGroupData();
  }

  void _loadGroupData() {
    _groupData = FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.groupId)
        .get()
        .then((snapshot) => snapshot.data() ?? {});

    _groupData.then((group) {
      // Charger les données des membres
      if (group['participants'] != null && group['participants'] is List) {
        _membersData = Future.wait((group['participants'] as List).map((userId) {
          return FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .get()
              .then((snapshot) {
                var data = snapshot.data() ?? {};
                data['id'] = userId; // Ajouter l'ID à la donnée utilisateur
                return data;
              });
        }));
      }

      // Charger les données du projet
      if (group['projetId'] != null) {
        _projectData = FirebaseFirestore.instance
            .collection('projets')
            .doc(group['projetId'])
            .get()
            .then((snapshot) => snapshot.data() ?? {});
      }

      setState(() {});
    });
  }

  void _navigateToUserProfile(BuildContext context, Map<String, dynamic> userData) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UserProfilePage(userId: userData['id']),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: FutureBuilder<Map<String, dynamic>>(
          future: _groupData,
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              return Text(snapshot.data!['name'] ?? 'Détails du groupe');
            }
            return const Text('Détails du groupe');
          },
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildGroupInfo(),
            const SizedBox(height: 24),
            _buildMembersSection(),
            const SizedBox(height: 24),
            _buildProjectSection(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupInfo() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _groupData,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const CircularProgressIndicator();
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Text('Aucune information sur le groupe');
        }

        final group = snapshot.data!;
        final createdAt = group['createdAt'] != null 
            ? (group['createdAt'] as Timestamp).toDate().toLocal()
            : null;

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  group['name'] ?? 'Groupe sans nom',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                if (createdAt != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Créé le: ${createdAt.day}/${createdAt.month}/${createdAt.year}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  group['isGroup'] == true ? 'Groupe' : 'Conversation privée',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMembersSection() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _membersData,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const CircularProgressIndicator();
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Text('Aucun membre dans ce groupe');
        }

        final members = snapshot.data!;

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Membres (${members.length})',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                ...members.map((member) {
                  return InkWell(
                    onTap: () => _navigateToUserProfile(context, member),
                    child: ListTile(
                      leading: const CircleAvatar(
                        child: Icon(Icons.person),
                      ),
                      title: Text(member['nom'] ?? 'Utilisateur sans nom'),
                      subtitle: Text(member['email'] ?? ''),
                    ),
                  );
                }).toList(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildProjectSection() {
  return FutureBuilder<Map<String, dynamic>>(
    future: _groupData,
    builder: (context, groupSnapshot) {
      if (groupSnapshot.connectionState == ConnectionState.waiting) {
        return const CircularProgressIndicator();
      }

      final groupData = groupSnapshot.data ?? {};
      final projectId = groupData['projetId'] as String?;

      if (projectId == null || projectId.isEmpty) {
        return const SizedBox(); // Pas de projet lié
      }

      return FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance
            .collection('projets')
            .doc(projectId)
            .get(),
        builder: (context, projectSnapshot) {
          if (projectSnapshot.connectionState == ConnectionState.waiting) {
            return const CircularProgressIndicator();
          }

          if (!projectSnapshot.hasData || !projectSnapshot.data!.exists) {
            return const SizedBox(); // Le projet n'existe pas
          }

          final project = projectSnapshot.data!.data() as Map<String, dynamic>? ?? {};

          return InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ProjectDetailPage(projetId: projectId),
                ),
              );
            },
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Projet lié',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ListTile(
                      leading: const Icon(Icons.work),
                      title: Text(project['titre'] ?? 'Projet sans nom'),
                      subtitle: Text(project['description'] ?? ''),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );
}
}
