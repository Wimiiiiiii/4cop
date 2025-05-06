import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'chat_page.dart';

class UserSearchPage extends StatefulWidget {
  final String currentUserId;

  const UserSearchPage({super.key, required this.currentUserId});

  @override
  State<UserSearchPage> createState() => _UserSearchPageState();
}

class _UserSearchPageState extends State<UserSearchPage> {
  final TextEditingController _controller = TextEditingController();
  List<DocumentSnapshot> users = [];

  void _search(String query) async {
    final searchLower = query.toLowerCase().trim();

    if (searchLower.isEmpty) {
      setState(() => users = []);
      return;
    }

    final result = await FirebaseFirestore.instance
        .collection('users')
        .get();

    final filtered = result.docs.where((doc) {
      if (doc.id == widget.currentUserId) return false;

      final data = doc.data() as Map<String, dynamic>;
      final email = (data['email'] ?? '').toString().toLowerCase();
      final nom = (data['nom'] ?? '').toString().toLowerCase();
      final prenom = (data['prenom'] ?? '').toString().toLowerCase();

      return email.contains(searchLower) ||
             nom.contains(searchLower) ||
             prenom.contains(searchLower);
    }).toList();

    setState(() {
      users = filtered;
    });
  }

  void _startChat(DocumentSnapshot userDoc) async {
    final uid = userDoc.id;
    final currentUser = FirebaseAuth.instance.currentUser!;
    final chatId = currentUser.uid.compareTo(uid) < 0
        ? '${currentUser.uid}_$uid'
        : '${uid}_${currentUser.uid}';

    final chatRef = FirebaseFirestore.instance.collection('chats').doc(chatId);
    final exists = await chatRef.get();

    if (!exists.exists) {
      await chatRef.set({
        'participants': [currentUser.uid, uid],
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ChatPage(chatId: chatId, otherUserId: uid),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Rechercher un utilisateur',
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
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              theme.colorScheme.background.withOpacity(0.3),
              theme.colorScheme.background,
            ],
            stops: [0, 0.3],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              TextField(
                controller: _controller,
                onChanged: _search,
                decoration: InputDecoration(
                  hintText: 'Rechercher par nom, prénom ou email...',
                  hintStyle: GoogleFonts.inter(),
                  filled: true,
                  fillColor: theme.colorScheme.surfaceVariant,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  prefixIcon: Icon(Icons.search, color: theme.colorScheme.primary),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: users.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.search_off,
                              size: 48,
                              color: theme.colorScheme.onSurface.withOpacity(0.3),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Aucun utilisateur trouvé',
                              style: GoogleFonts.inter(
                                color: theme.colorScheme.onSurface.withOpacity(0.6),
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: users.length,
                        itemBuilder: (context, index) {
                          final user = users[index];
                          final data = user.data() as Map<String, dynamic>;
                          final email = data['email'] ?? '';
                          final name = data['nom'] ?? 'Utilisateur';
                          final prenom = data['prenom'] ?? '';
                          final photoUrl = data['photoUrl'];

                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surface,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              leading: Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: theme.colorScheme.primary.withOpacity(0.1),
                                  border: Border.all(
                                    color: theme.colorScheme.primary.withOpacity(0.3),
                                    width: 1,
                                  ),
                                ),
                                child: photoUrl != null 
                                    ? ClipOval(child: Image.network(photoUrl, fit: BoxFit.cover))
                                    : Icon(Icons.person, color: theme.colorScheme.primary),
                              ),
                              title: Text(
                                '$prenom $name',
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              subtitle: Text(
                                email,
                                style: GoogleFonts.inter(
                                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                                ),
                              ),
                              trailing: Icon(
                                Icons.chat,
                                color: theme.colorScheme.primary,
                              ),
                              onTap: () => _startChat(user),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}