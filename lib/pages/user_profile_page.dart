import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fourcoop/pages/chat_page.dart';
import 'package:fourcoop/pages/project_detail_page.dart';

class UserProfilePage extends StatelessWidget {
  final String userId;

  const UserProfilePage({
    Key? key,
    required this.userId,
  }) : super(key: key);

  String _generateChatId(String userId1, String userId2) {
    final sorted = [userId1, userId2]..sort();
    return '${sorted[0]}_${sorted[1]}';
  }

  Widget _buildInfoRow(IconData icon, String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: Colors.blue),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value ?? 'Non spécifié',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil Utilisateur'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          if (currentUser == null) return;

          if (userId == currentUser.uid) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Vous ne pouvez pas vous envoyer un message à vous-même")),
            );
            return;
          }

          final chatId = _generateChatId(currentUser.uid, userId);

          try {
            final chatDoc = await FirebaseFirestore.instance
                .collection('chats')
                .doc(chatId)
                .get();

            if (!chatDoc.exists) {
              await FirebaseFirestore.instance
                  .collection('chats')
                  .doc(chatId)
                  .set({
                    'participants': [currentUser.uid, userId],
                    'createdAt': FieldValue.serverTimestamp(),
                    'lastMessage': '',
                    'lastMessageTime': FieldValue.serverTimestamp(),
                  });
            }

           
            
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ChatPage(
                  chatId: chatId,
                  otherUserId: userId,
                ),
              ),
            );
          } catch (e) {
            
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("Erreur: ${e.toString()}")),
            );
          }
        },
        child: const Icon(Icons.message),
        backgroundColor: Theme.of(context).primaryColor,
        heroTag: 'userProfileChatButton',
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection('users').doc(userId).get(),
        builder: (context, userSnapshot) {
          if (userSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
            return const Center(child: Text('Profil non trouvé'));
          }

          final userData = userSnapshot.data!.data() as Map<String, dynamic>;
          final userEmail = userData['email'];

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 60,
                  backgroundImage: userData['photo_url'] != null 
                      ? NetworkImage(userData['photo_url']) 
                      : null,
                  child: userData['photo_url'] == null 
                      ? const Icon(Icons.person, size: 60) 
                      : null,
                ),
                const SizedBox(height: 20),
                Text(
                  '${userData['prenom'] ?? ''} ${userData['nom'] ?? ''}',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                if (userData['domaine'] != null)
                  Text(
                    userData['domaine'],
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                const SizedBox(height: 30),
                
                Card(
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _buildInfoRow(Icons.location_on, 'Pays', userData['pays']),
                        const Divider(),
                        _buildInfoRow(Icons.school, 'École', userData['ecole']),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                if (userData['competences'] != null && 
                    (userData['competences'] as List).isNotEmpty)
                  Card(
                    elevation: 3,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Compétences',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: (userData['competences'] as List)
                                .map<Widget>((skill) => Chip(
                                      label: Text(skill.toString()),
                                    ))
                                .toList(),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 20),

                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('projets')
                      .where('contact', isEqualTo: userEmail)
                      .snapshots(),
                  builder: (context, createdProjectsSnapshot) {
                    if (createdProjectsSnapshot.connectionState == ConnectionState.waiting) {
                      return const SizedBox.shrink();
                    }

                    if (createdProjectsSnapshot.hasError) {
                      return const Text('Erreur de chargement des projets');
                    }

                    final createdProjects = createdProjectsSnapshot.data?.docs ?? [];

                    if (createdProjects.isEmpty) {
                      return const SizedBox.shrink();
                    }

                    return Card(
                      elevation: 3,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Projets Créés',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Column(
                              children: createdProjects.map((project) {
                                return ListTile(
                                  title: Text(project['titre'] ?? 'Titre non spécifié'),
                                  subtitle: Text(project['description'] ?? ''),
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => ProjectDetailPage(projetId: project.id),
                                      ),
                                    );
                                  },
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 20),

                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('projets')
                      .where('membres', arrayContains: userEmail)
                      .snapshots(),
                  builder: (context, allProjectsSnapshot) {
                    if (allProjectsSnapshot.connectionState == ConnectionState.waiting) {
                      return const SizedBox.shrink();
                    }

                    if (allProjectsSnapshot.hasError) {
                      return const Text('Erreur de chargement des projets');
                    }

                    final allProjects = allProjectsSnapshot.data?.docs ?? [];
                    final memberProjects = allProjects.where((project) => 
                        project['contact'] != userEmail).toList();

                    if (memberProjects.isEmpty) {
                      return const SizedBox.shrink();
                    }

                    return Card(
                      elevation: 3,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Projets en tant que Membre',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Column(
                              children: memberProjects.map((project) {
                                return ListTile(
                                  title: Text(project['titre'] ?? 'Titre non spécifié'),
                                  subtitle: Text(project['description'] ?? ''),
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => ProjectDetailPage(projetId: project.id),
                                      ),
                                    );
                                  },
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}