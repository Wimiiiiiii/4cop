import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ChatPage extends StatefulWidget {
  final String chatId;
  final String? otherUserId;
  final bool isGroup;

  const ChatPage({
    Key? key,
    required this.chatId,
    this.otherUserId,
    this.isGroup = false,
  }) : super(key: key);

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final currentUser = FirebaseAuth.instance.currentUser;
  bool isGroupChat = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadChatType();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });
  }

  Future<void> _loadChatType() async {
    final chatDoc = await FirebaseFirestore.instance.collection('chats').doc(widget.chatId).get();
    final data = chatDoc.data() as Map<String, dynamic>? ?? {};
    setState(() {
      isGroupChat = data['isGroup'] == true;
    });
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    final chatRef = FirebaseFirestore.instance.collection('chats').doc(widget.chatId);
  
    try {
      final chatSnapshot = await chatRef.get();
      if (!chatSnapshot.exists && !widget.isGroup) {
        await chatRef.set({
          'participants': [currentUser!.uid, widget.otherUserId],
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      await chatRef.collection('messages').add({
        'text': message,
        'senderId': currentUser!.uid,
        if (!widget.isGroup) 'receiverId': widget.otherUserId,
        'timestamp': FieldValue.serverTimestamp(),
      });

      await FirebaseFirestore.instance.collection('chats').doc(widget.chatId).update({
        'timestamp': FieldValue.serverTimestamp(),
      });


      _messageController.clear();
      _scrollToBottom();
    } catch (e) {
      print('Erreur lors de l\'envoi du message: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: widget.isGroup
            ? FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance.collection('chats').doc(widget.chatId).get(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return Text('Groupe', style: GoogleFonts.interTight());
                  final data = snapshot.data!.data() as Map<String, dynamic>?;
                  return Text(
                    data?['name'] ?? 'Groupe',
                    style: GoogleFonts.interTight(fontWeight: FontWeight.bold),
                  );
                },
              )
            : FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance.collection('users').doc(widget.otherUserId!).get(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return Text('Discussion', style: GoogleFonts.interTight());
                  final data = snapshot.data!.data() as Map<String, dynamic>?;
                  return Text(
                    data?['nom'] ?? 'Utilisateur',
                    style: GoogleFonts.interTight(fontWeight: FontWeight.bold),
                  );
                },
              ),
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
        elevation: 0,
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
        child: Column(
          children: [
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('chats')
                    .doc(widget.chatId)
                    .collection('messages')
                    .orderBy('timestamp', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return Center(
                      child: CircularProgressIndicator(
                        color: theme.colorScheme.primary,
                      ),
                    );
                  }

                  final messages = snapshot.data!.docs;

                  if (messages.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.forum_outlined,
                            size: 48,
                            color: theme.colorScheme.onSurface.withOpacity(0.3),
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Envoyez votre premier message',
                            style: GoogleFonts.inter(
                              color: theme.colorScheme.onSurface.withOpacity(0.6),
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    controller: _scrollController,
                    reverse: true,
                    padding: EdgeInsets.symmetric(vertical: 8),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final msg = messages[index];
                      final isMe = msg['senderId'] == currentUser!.uid;

                      return Align(
                        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          child: Column(
                            crossAxisAlignment:
                                isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                            children: [
                              if (isGroupChat && !isMe)
                                FutureBuilder<DocumentSnapshot>(
                                  future: FirebaseFirestore.instance
                                      .collection('users')
                                      .doc(msg['senderId'])
                                      .get(),
                                  builder: (context, snapshot) {
                                    if (!snapshot.hasData || !snapshot.data!.exists) {
                                      return SizedBox.shrink();
                                    }
                                    final senderData =
                                        snapshot.data!.data() as Map<String, dynamic>? ?? {};
                                    final senderName = senderData['prenom'] ?? 'Utilisateur';
                                    return Padding(
                                      padding: const EdgeInsets.only(left: 8, bottom: 2),
                                      child: Text(
                                        senderName,
                                        style: GoogleFonts.inter(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                          color: theme.colorScheme.onSurface.withOpacity(0.7),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              Container(
                                constraints: BoxConstraints(
                                  maxWidth: MediaQuery.of(context).size.width * 0.75,
                                ),
                                padding: EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isMe
                                      ? theme.colorScheme.primaryContainer
                                      : theme.colorScheme.surfaceVariant,
                                  borderRadius: BorderRadius.only(
                                    topLeft: Radius.circular(16),
                                    topRight: Radius.circular(16),
                                    bottomLeft: isMe ? Radius.circular(16) : Radius.circular(4),
                                    bottomRight: isMe ? Radius.circular(4) : Radius.circular(16),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.05),
                                      blurRadius: 6,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Text(
                                  msg['text'],
                                  style: GoogleFonts.inter(
                                    color: isMe
                                        ? theme.colorScheme.onPrimaryContainer
                                        : theme.colorScheme.onSurface,
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                child: Text(
                                  _formatTimestamp(msg['timestamp']),
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    color: theme.colorScheme.onSurface.withOpacity(0.5),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            Divider(height: 1, color: theme.colorScheme.surfaceVariant),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: theme.colorScheme.surface,
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceVariant,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: TextField(
                          controller: _messageController,
                          decoration: InputDecoration(
                            hintText: 'Écrivez un message...',
                            hintStyle: GoogleFonts.inter(),
                            border: InputBorder.none,
                          ),
                          onSubmitted: (_) => _sendMessage(),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: theme.colorScheme.primary,
                    ),
                    child: IconButton(
                      icon: Icon(Icons.send, color: theme.colorScheme.onPrimary),
                      onPressed: _sendMessage,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final date = timestamp.toDate();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(date.year, date.month, date.day);

    if (messageDate == today) {
      return '${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } else if (messageDate == today.subtract(Duration(days: 1))) {
      return 'Hier ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } else {
      return '${date.day}/${date.month} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    }
  }
}