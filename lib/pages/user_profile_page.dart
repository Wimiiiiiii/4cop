import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fourcoop/pages/chat_page.dart';
import 'package:fourcoop/pages/project_detail_page.dart';
import 'package:google_fonts/google_fonts.dart';

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

  Widget _buildInfoRow(IconData icon, String label, String? value, BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Theme.of(context).colorScheme.onPrimaryContainer),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.interTight(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value ?? 'Non spécifié',
                style: GoogleFonts.interTight(
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

  Widget _buildProjectSection(String title, List<QueryDocumentSnapshot> projects, BuildContext context) {
    if (projects.isEmpty) return const SizedBox();

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: GoogleFonts.interTight(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ...projects.map((project) {
              return InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ProjectDetailPage(projetId: project.id),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.tertiaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.work,
                          color: Theme.of(context).colorScheme.onTertiaryContainer,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              project['titre'] ?? 'Titre non spécifié',
                              style: GoogleFonts.interTight(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              project['description'] ?? '',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.interTight(
                                fontSize: 14,
                                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right,
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Profil Utilisateur',
          style: GoogleFonts.interTight(
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                theme.colorScheme.primary,
                theme.colorScheme.error,
                theme.colorScheme.tertiary,
              ],
              stops: [0, 0.5, 1],
              begin: AlignmentDirectional(-1, -1),
              end: AlignmentDirectional(1, 1),
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          if (currentUser == null) return;

          if (userId == currentUser.uid) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  "Vous ne pouvez pas vous envoyer un message à vous-même",
                  style: GoogleFonts.interTight(),
                ),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
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
                    'timestamp': FieldValue.serverTimestamp(),
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
              SnackBar(
                content: Text(
                  "Erreur: ${e.toString()}",
                  style: GoogleFonts.interTight(),
                ),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            );
          }
        },
        child: const Icon(Icons.message),
        backgroundColor: theme.colorScheme.primary,
        heroTag: 'userProfileChatButton',
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection('users').doc(userId).get(),
        builder: (context, userSnapshot) {
          if (userSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
            return Center(
              child: Text(
                'Profil non trouvé',
                style: GoogleFonts.interTight(),
              ),
            );
          }

          final userData = userSnapshot.data!.data() as Map<String, dynamic>;
          final userEmail = userData['email'];

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Profile Header
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: theme.colorScheme.primaryContainer,
                        backgroundImage: userData['photo_url'] != null 
                            ? NetworkImage(userData['photo_url']) 
                            : null,
                        child: userData['photo_url'] == null 
                            ? Icon(
                                Icons.person,
                                size: 50,
                                color: theme.colorScheme.onPrimaryContainer,
                              ) 
                            : null,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '${userData['prenom'] ?? ''} ${userData['nom'] ?? ''}',
                        style: GoogleFonts.interTight(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      if (userData['domaine'] != null)
                        Text(
                          userData['domaine'],
                          style: GoogleFonts.interTight(
                            fontSize: 16,
                            color: theme.colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // User Info
                Card(
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _buildInfoRow(Icons.location_on, 'Pays', userData['pays'], context),
                        const Divider(height: 16),
                        _buildInfoRow(Icons.school, 'École', userData['ecole'], context),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Skills
                if (userData['competences'] != null && 
                    (userData['competences'] as List).isNotEmpty)
                  Card(
                    elevation: 3,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Compétences',
                            style: GoogleFonts.interTight(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: (userData['competences'] as List)
                                .map<Widget>((skill) => Chip(
                                      label: Text(
                                        skill.toString(),
                                        style: GoogleFonts.interTight(),
                                      ),
                                      backgroundColor: theme.colorScheme.surfaceVariant,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ))
                                .toList(),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Projects
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('projets')
                      .where('contact', isEqualTo: userEmail)
                      .snapshots(),
                  builder: (context, createdProjectsSnapshot) {
                    if (createdProjectsSnapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (createdProjectsSnapshot.hasError) {
                      return Text(
                        'Erreur de chargement des projets',
                        style: GoogleFonts.interTight(),
                      );
                    }

                    final createdProjects = createdProjectsSnapshot.data?.docs ?? [];
                    return _buildProjectSection('Projets Créés', createdProjects, context);
                  },
                ),

                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('projets')
                      .where('membres', arrayContains: userEmail)
                      .snapshots(),
                  builder: (context, allProjectsSnapshot) {
                    if (allProjectsSnapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (allProjectsSnapshot.hasError) {
                      return Text(
                        'Erreur de chargement des projets',
                        style: GoogleFonts.interTight(),
                      );
                    }

                    final allProjects = allProjectsSnapshot.data?.docs ?? [];
                    final memberProjects = allProjects.where((project) => 
                        project['contact'] != userEmail).toList();

                    return _buildProjectSection('Projets en tant que Membre', memberProjects, context);
                  },
                ),
                const SizedBox(height: 80), // Space for FAB
              ],
            ),
          );
        },
      ),
    );
  }
}