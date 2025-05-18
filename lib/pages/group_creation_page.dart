import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chat_page.dart';
import 'package:google_fonts/google_fonts.dart';

class GroupCreationPage extends StatefulWidget {
  final String currentUserId;
  final String projetId;

  const GroupCreationPage({
    Key? key,
    required this.currentUserId,
    required this.projetId,
  }) : super(key: key);

  @override
  _GroupCreationPageState createState() => _GroupCreationPageState();
}

class _GroupCreationPageState extends State<GroupCreationPage> {
  final TextEditingController _groupNameController = TextEditingController();
  List<String> selectedUserIds = [];

  void _createGroupChat() async {
    if (selectedUserIds.isEmpty || _groupNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            selectedUserIds.isEmpty
                ? "Veuillez sélectionner au moins un membre."
                : "Veuillez entrer un nom de groupe.",
            style: GoogleFonts.inter(),
          ),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }

    final newGroup = await FirebaseFirestore.instance.collection('chats').add({
      'name': _groupNameController.text.trim(),
      'projetId': widget.projetId,
      'participants': [widget.currentUserId, ...selectedUserIds],
      'isGroup': true,
      'createdAt': FieldValue.serverTimestamp(),
      'timestamp': FieldValue.serverTimestamp(),
    });

    final groupId = newGroup.id;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatPage(chatId: groupId, isGroup: true),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Créer un groupe',
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
              stops: const [0, 0.5, 1],
              begin: AlignmentDirectional(-1, -1),
              end: AlignmentDirectional(1, 1),
            ),
          ),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              theme.colorScheme.background.withOpacity(0.3),
              theme.colorScheme.background,
            ],
            stops: const [0, 0.3],
          ),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _groupNameController,
                decoration: InputDecoration(
                  hintText: 'Nom du groupe',
                  hintStyle: GoogleFonts.inter(),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: theme.colorScheme.surface,
                ),
                style: GoogleFonts.inter(),
              ),
            ),
            Expanded(
              child: FutureBuilder<DocumentSnapshot>(
                future:
                    FirebaseFirestore.instance
                        .collection('projets')
                        .doc(widget.projetId)
                        .get(),
                builder: (context, projetSnapshot) {
                  if (!projetSnapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final projetData =
                      projetSnapshot.data!.data() as Map<String, dynamic>;
                  final List<dynamic> membresEmails =
                      projetData['membres'] ?? [];

                  return StreamBuilder<QuerySnapshot>(
                    stream:
                        FirebaseFirestore.instance
                            .collection('users')
                            .snapshots(),
                    builder: (context, userSnapshot) {
                      if (!userSnapshot.hasData)
                        return const Center(child: CircularProgressIndicator());

                      final users =
                          userSnapshot.data!.docs.where((doc) {
                            final data = doc.data() as Map<String, dynamic>;
                            final email = data['email'];
                            return email != null &&
                                membresEmails.contains(email) &&
                                doc.id != widget.currentUserId;
                          }).toList();

                      if (users.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.group_off,
                                size: 48,
                                color: theme.colorScheme.onSurface.withOpacity(
                                  0.3,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                "Aucun membre disponible pour ce projet.",
                                style: GoogleFonts.inter(
                                  color: theme.colorScheme.onSurface
                                      .withOpacity(0.6),
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      return ListView.builder(
                        itemCount: users.length,
                        itemBuilder: (context, index) {
                          final user = users[index];
                          final data = user.data() as Map<String, dynamic>;

                          final name = data['nom'] ?? 'Nom inconnu';
                          final prenom = data['prenom'] ?? '';
                          final email = data['email'] ?? '';

                          final isSelected = selectedUserIds.contains(user.id);

                          return Card(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 6,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: CheckboxListTile(
                              title: Text(
                                '$prenom $name',
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Text(
                                email,
                                style: GoogleFonts.inter(fontSize: 13),
                              ),
                              value: isSelected,
                              activeColor: theme.colorScheme.primary,
                              onChanged: (val) {
                                setState(() {
                                  if (val == true) {
                                    selectedUserIds.add(user.id);
                                  } else {
                                    selectedUserIds.remove(user.id);
                                  }
                                });
                              },
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _createGroupChat,
                  icon: const Icon(Icons.group_add),
                  label: Text(
                    'Créer le groupe',
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
