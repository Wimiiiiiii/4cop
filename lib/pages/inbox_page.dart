import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'chat_page.dart';
import 'user_search_page.dart';

class InboxPage extends StatefulWidget {
  @override
  _InboxPageState createState() => _InboxPageState();
}

class _InboxPageState extends State<InboxPage> {
  final currentUser = FirebaseAuth.instance.currentUser!;
  String searchQuery = '';

  Future<void> deleteChat(String chatId) async {
    final chatRef = FirebaseFirestore.instance.collection('chats').doc(chatId);
    final messages = await chatRef.collection('messages').get();
    for (final doc in messages.docs) {
      await doc.reference.delete();
    }
    await chatRef.delete();
  }

  void _startNewChat() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UserSearchPage(currentUserId: currentUser.uid),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Messagerie',
          style: GoogleFonts.interTight(
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        elevation: 0,
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
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(80),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Rechercher une conversation...',
                hintStyle: GoogleFonts.inter(),
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: theme.colorScheme.surfaceVariant,
                contentPadding: EdgeInsets.symmetric(
                  vertical: 0,
                  horizontal: 16,
                ),
              ),
              onChanged:
                  (value) => setState(() => searchQuery = value.toLowerCase()),
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
        child: StreamBuilder<QuerySnapshot>(
          stream:
              FirebaseFirestore.instance
                  .collection('chats')
                  .where('participants', arrayContains: currentUser.uid)
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(
                child: CircularProgressIndicator(
                  color: theme.colorScheme.primary,
                ),
              );
            }
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.chat_bubble_outline,
                      size: 48,
                      color: theme.colorScheme.onSurface.withOpacity(0.3),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "Aucune conversation",
                      style: GoogleFonts.inter(
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              );
            }

            final chats = snapshot.data!.docs;

            return ListView.builder(
              padding: EdgeInsets.symmetric(vertical: 8),
              itemCount: chats.length,
              itemBuilder: (context, index) {
                final chat = chats[index];
                final chatId = chat.id;
                final chatData = chat.data() as Map<String, dynamic>;
                final participants = List<String>.from(
                  chatData['participants'],
                );
                final isGroup = chatData['isGroup'] == true;

                if (isGroup) {
                  final groupName = chatData['name'] ?? 'Groupe';
                  return _buildChatTile(
                    chatId: chatId,
                    title: groupName,
                    isGroup: true,
                    subtitleStream:
                        FirebaseFirestore.instance
                            .collection('chats')
                            .doc(chatId)
                            .collection('messages')
                            .orderBy('timestamp', descending: true)
                            .limit(1)
                            .snapshots(),
                    onTap: () {
                      FirebaseFirestore.instance
                          .collection('chats')
                          .doc(chatId)
                          .update({
                            'lastSeen_${currentUser.uid}':
                                FieldValue.serverTimestamp(),
                          });
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (_) => ChatPage(chatId: chatId, isGroup: true),
                        ),
                      );
                    },
                    onDelete: () => deleteChat(chatId),
                  );
                } else {
                  final otherUid = participants.firstWhere(
                    (uid) => uid != currentUser.uid,
                  );
                  return FutureBuilder<DocumentSnapshot>(
                    future:
                        FirebaseFirestore.instance
                            .collection('users')
                            .doc(otherUid)
                            .get(),
                    builder: (context, userSnapshot) {
                      if (!userSnapshot.hasData || !userSnapshot.data!.exists)
                        return SizedBox.shrink();
                      final userData =
                          userSnapshot.data!.data() as Map<String, dynamic>? ??
                          {};
                      final nom = (userData['nom'] ?? '').toLowerCase();
                      final prenom = (userData['prenom'] ?? '').toLowerCase();
                      final email = (userData['email'] ?? '').toLowerCase();
                      final data = chat.data() as Map<String, dynamic>? ?? {};
                      final isGroup = data['isGroup'] == true;
                      final groupName =
                          (data['name'] ?? '').toString().toLowerCase();

                      if (searchQuery.isNotEmpty) {
                        if (isGroup) {
                          if (!groupName.contains(searchQuery))
                            return SizedBox.shrink();
                        } else {
                          if (!nom.contains(searchQuery) &&
                              !prenom.contains(searchQuery) &&
                              !email.contains(searchQuery)) {
                            return SizedBox.shrink();
                          }
                        }
                      }

                      return _buildChatTile(
                        chatId: chatId,
                        title: userData['nom'] ?? 'Utilisateur',
                        isGroup: false,
                        subtitleStream:
                            FirebaseFirestore.instance
                                .collection('chats')
                                .doc(chatId)
                                .collection('messages')
                                .orderBy('timestamp', descending: true)
                                .limit(1)
                                .snapshots(),
                        onTap: () {
                          FirebaseFirestore.instance
                              .collection('chats')
                              .doc(chatId)
                              .update({
                                'lastSeen_${currentUser.uid}':
                                    FieldValue.serverTimestamp(),
                              });
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (_) => ChatPage(
                                    chatId: chatId,
                                    otherUserId: otherUid,
                                    isGroup: false,
                                  ),
                            ),
                          );
                        },
                        onDelete: () => deleteChat(chatId),
                      );
                    },
                  );
                }
              },
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _startNewChat,
        icon: Icon(Icons.add, color: theme.colorScheme.onPrimary),
        label: Text(
          'Nouveau chat',
          style: GoogleFonts.inter(color: theme.colorScheme.onPrimary),
        ),
        backgroundColor: theme.colorScheme.primary,
        elevation: 4,
      ),
    );
  }

  Widget _buildChatTile({
    required String chatId,
    required String title,
    required bool isGroup,
    required Stream<QuerySnapshot> subtitleStream,
    required VoidCallback onTap,
    required VoidCallback onDelete,
  }) {
    final theme = Theme.of(context);

    return StreamBuilder<QuerySnapshot>(
      stream: subtitleStream,
      builder: (context, msgSnapshot) {
        String subtitle = 'Appuyez pour discuter';
        bool hasUnread = false;

        if (msgSnapshot.hasData && msgSnapshot.data!.docs.isNotEmpty) {
          final lastMessage = msgSnapshot.data!.docs.first;
          subtitle = lastMessage['text'] ?? '';

          // Vérification des messages non lus
          if (lastMessage['senderId'] != currentUser.uid) {
            final lastSeenField = 'lastSeen_${currentUser.uid}';
            hasUnread =
                true; // Par défaut, on considère le message comme non lu

            // Vérification du lastSeen
            FirebaseFirestore.instance
                .collection('chats')
                .doc(chatId)
                .get()
                .then((doc) {
                  final lastSeen = doc.data()?[lastSeenField] as Timestamp?;
                  final messageTime = lastMessage['timestamp'] as Timestamp?;

                  if (lastSeen != null && messageTime != null) {
                    hasUnread = messageTime.toDate().isAfter(lastSeen.toDate());
                  }
                });
          }
        }

        return Container(
          margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: theme.colorScheme.surface,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            borderRadius: BorderRadius.circular(16),
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                // Mise à jour du lastSeen avant la navigation
                FirebaseFirestore.instance
                    .collection('chats')
                    .doc(chatId)
                    .update({
                      'lastSeen_${currentUser.uid}':
                          FieldValue.serverTimestamp(),
                    });
                onTap();
              },
              onLongPress: () async {
                final confirm = await showDialog(
                  context: context,
                  builder:
                      (_) => AlertDialog(
                        title: Text(
                          'Supprimer cette conversation ?',
                          style: GoogleFonts.inter(),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: Text(
                              'Annuler',
                              style: GoogleFonts.inter(
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: Text(
                              'Supprimer',
                              style: GoogleFonts.inter(
                                color: theme.colorScheme.error,
                              ),
                            ),
                          ),
                        ],
                      ),
                );
                if (confirm == true) {
                  onDelete();
                }
              },
              child: Padding(
                padding: EdgeInsets.all(12),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color:
                            isGroup
                                ? theme.colorScheme.tertiaryContainer
                                : theme.colorScheme.secondaryContainer,
                      ),
                      child: Icon(
                        isGroup ? Icons.group : Icons.person,
                        color:
                            isGroup
                                ? theme.colorScheme.onTertiaryContainer
                                : theme.colorScheme.onSecondaryContainer,
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: GoogleFonts.interTight(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            subtitle,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: theme.colorScheme.onSurface.withOpacity(
                                0.7,
                              ),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    if (hasUnread)
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: theme.colorScheme.error,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
