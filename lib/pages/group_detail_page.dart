import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fourcoop/pages/project_detail_page.dart';
import 'package:fourcoop/pages/user_profile_page.dart';
import 'package:google_fonts/google_fonts.dart';

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
      if (group['participants'] != null && group['participants'] is List) {
        _membersData = Future.wait(
          (group['participants'] as List).map((userId) {
            return FirebaseFirestore.instance
                .collection('users')
                .doc(userId)
                .get()
                .then((snapshot) {
                  var data = snapshot.data() ?? {};
                  data['id'] = userId;
                  return data;
                });
          }).toList(), // 👈 ici tu fermes le .map et convertis en List
        ); // 👈 ici tu fermes le Future.wait
      }

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

  void _navigateToUserProfile(
    BuildContext context,
    Map<String, dynamic> userData,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UserProfilePage(userId: userData['id']),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: FutureBuilder<Map<String, dynamic>>(
          future: _groupData,
          builder: (context, snapshot) {
            return Text(
              snapshot.hasData
                  ? snapshot.data!['name'] ?? 'Détails du groupe'
                  : 'Détails du groupe',
              style: GoogleFonts.interTight(
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            );
          },
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
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Text('Aucune information sur le groupe');
        }

        final group = snapshot.data!;
        final createdAt =
            group['createdAt'] != null
                ? (group['createdAt'] as Timestamp).toDate().toLocal()
                : null;

        return Card(
          elevation: 3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  group['name'] ?? 'Groupe sans nom',
                  style: GoogleFonts.interTight(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      group['isGroup'] == true ? Icons.group : Icons.person,
                      color: Theme.of(context).colorScheme.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      group['isGroup'] == true
                          ? 'Groupe'
                          : 'Conversation privée',
                      style: GoogleFonts.interTight(
                        fontSize: 16,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
                if (createdAt != null) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        color: Theme.of(context).colorScheme.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Créé le ${createdAt.day}/${createdAt.month}/${createdAt.year}',
                        style: GoogleFonts.interTight(
                          fontSize: 16,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ],
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
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Text('Aucun membre dans ce groupe');
        }

        final members = snapshot.data!;

        return Card(
          elevation: 3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Membres (${members.length})',
                  style: GoogleFonts.interTight(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                ...members.map((member) {
                  final nom =
                      (member['nom'] ?? '').toString().isEmpty
                          ? null
                          : member['nom'];
                  final email = member['email'] ?? '';
                  final isDeleted =
                      member['deleted'] == true ||
                      (nom == null && (email == null || email == ''));
                  return InkWell(
                    onTap: () => _navigateToUserProfile(context, member),
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
                          CircleAvatar(
                            backgroundColor:
                                Theme.of(context).colorScheme.primaryContainer,
                            child: Icon(
                              Icons.person,
                              color:
                                  Theme.of(
                                    context,
                                  ).colorScheme.onPrimaryContainer,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isDeleted
                                      ? 'Utilisateur inexistant'
                                      : (nom ?? 'Utilisateur sans nom'),
                                  style: GoogleFonts.interTight(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  email,
                                  style: GoogleFonts.interTight(
                                    fontSize: 14,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface.withOpacity(0.6),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.chevron_right,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withOpacity(0.4),
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
      },
    );
  }

  Widget _buildProjectSection() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _groupData,
      builder: (context, groupSnapshot) {
        if (groupSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final groupData = groupSnapshot.data ?? {};
        final projectId = groupData['projetId'] as String?;

        if (projectId == null || projectId.isEmpty) {
          return const SizedBox();
        }

        return FutureBuilder<DocumentSnapshot>(
          future:
              FirebaseFirestore.instance
                  .collection('projets')
                  .doc(projectId)
                  .get(),
          builder: (context, projectSnapshot) {
            if (projectSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (!projectSnapshot.hasData || !projectSnapshot.data!.exists) {
              return const SizedBox();
            }

            final project =
                projectSnapshot.data!.data() as Map<String, dynamic>? ?? {};

            return InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (context) => ProjectDetailPage(projetId: projectId),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(16),
              child: Card(
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Projet lié',
                        style: GoogleFonts.interTight(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color:
                                  Theme.of(
                                    context,
                                  ).colorScheme.tertiaryContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.work,
                              color:
                                  Theme.of(
                                    context,
                                  ).colorScheme.onTertiaryContainer,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  project['titre'] ?? 'Projet sans nom',
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
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface.withOpacity(0.6),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.chevron_right,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withOpacity(0.4),
                          ),
                        ],
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
