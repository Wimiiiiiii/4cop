import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fourcoop/pages/group_detail_page.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fourcoop/pages/user_profile_page.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'package:url_launcher/url_launcher.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

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
  final FirebaseStorage _storage = FirebaseStorage.instance;
  bool _isUploading = false;
  final int _maxFileSize = 10 * 1024 * 1024; // 10MB max
  final List<String> _allowedExtensions = [
    'pdf',
    'doc',
    'docx',
    'jpg',
    'jpeg',
    'png',
    'txt',
    'xlsx',
    'xls',
    'pptx',
    'ppt',
  ];

  @override
  void initState() {
    super.initState();
    _loadChatType();
    _requestPermissions();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });
  }

  Future<void> _loadChatType() async {
    final chatDoc =
        await FirebaseFirestore.instance
            .collection('chats')
            .doc(widget.chatId)
            .get();
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
    final chatRef = FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId);
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
      await chatRef.update({
        'lastMessage': message,
        'lastMessageTime': FieldValue.serverTimestamp(),
      });
      _messageController.clear();
      _scrollToBottom();
    } catch (e) {
      print('Erreur lors de l\'envoi du message: $e');
    }
  }

  void _navigateToProfile(String userId) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => UserProfilePage(userId: userId)),
    );
  }

  Future<void> _pickAndUploadFile() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? file = await picker.pickMedia();
      if (file == null) return;
      final fileSize = await file.length();
      if (fileSize > _maxFileSize) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Le fichier est trop volumineux. Maximum: 10MB'),
          ),
        );
        return;
      }
      setState(() => _isUploading = true);
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${file.name}';
      final ref = _storage.ref().child('chat_files/${widget.chatId}/$fileName');
      final uploadTask = await ref.putFile(
        File(file.path),
        SettableMetadata(contentType: file.mimeType),
      );
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .collection('messages')
          .add({
            'text': 'Fichier: ${file.name}',
            'fileUrl': downloadUrl,
            'fileName': file.name,
            'fileType': file.mimeType?.split('/').last,
            'fileSize': fileSize,
            'senderId': FirebaseAuth.instance.currentUser!.uid,
            'timestamp': FieldValue.serverTimestamp(),
          });
      setState(() => _isUploading = false);
    } catch (e) {
      setState(() => _isUploading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erreur lors de l\'upload: $e')));
    }
  }

  Future<void> _requestPermissions() async {
    await Permission.storage.request();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title:
            widget.isGroup
                ? FutureBuilder<DocumentSnapshot>(
                  future:
                      FirebaseFirestore.instance
                          .collection('chats')
                          .doc(widget.chatId)
                          .get(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData)
                      return Text('Groupe', style: GoogleFonts.interTight());
                    final data = snapshot.data!.data() as Map<String, dynamic>?;
                    return InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (context) =>
                                    GroupDetailsPage(groupId: widget.chatId),
                          ),
                        );
                      },
                      child: Text(
                        data?['name'] ?? 'Groupe',
                        style: GoogleFonts.interTight(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    );
                  },
                )
                : FutureBuilder<DocumentSnapshot>(
                  future:
                      FirebaseFirestore.instance
                          .collection('users')
                          .doc(widget.otherUserId!)
                          .get(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData)
                      return Text(
                        'Discussion',
                        style: GoogleFonts.interTight(),
                      );
                    final data = snapshot.data!.data() as Map<String, dynamic>?;
                    return InkWell(
                      onTap: () => _navigateToProfile(widget.otherUserId!),
                      child: Text(
                        '${data?['prenom'] ?? ''} ${data?['nom'] ?? ''}'.trim(),
                        style: GoogleFonts.interTight(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
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
                stream:
                    FirebaseFirestore.instance
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
                              color: theme.colorScheme.onSurface.withOpacity(
                                0.6,
                              ),
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
                        alignment:
                            isMe ? Alignment.centerRight : Alignment.centerLeft,
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 4,
                          ),
                          child: _buildMessageBubble(msg),
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
                  IconButton(
                    icon: Icon(Icons.attach_file),
                    onPressed: _isUploading ? null : _pickAndUploadFile,
                    tooltip: 'Joindre un fichier',
                  ),
                  SizedBox(width: 8),
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
                  if (_isUploading)
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8.0),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  else
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: theme.colorScheme.primary,
                      ),
                      child: IconButton(
                        icon: Icon(
                          Icons.send,
                          color: theme.colorScheme.onPrimary,
                        ),
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

  Widget _buildMessageBubble(DocumentSnapshot message) {
    final data = message.data() as Map<String, dynamic>;
    final isMe = data['senderId'] == FirebaseAuth.instance.currentUser!.uid;
    final messageWidget =
        data['fileUrl'] != null
            ? _buildFileMessage(
              data['fileUrl'],
              data['fileName'],
              data['fileType'],
              data['fileSize'],
              isMe,
            )
            : _buildTextMessage(data['text'], isMe);

    return GestureDetector(
      onLongPress:
          isMe
              ? () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder:
                      (context) => AlertDialog(
                        title: Text('Supprimer ce message ?'),
                        content: Text('Cette action est irréversible.'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: Text('Annuler'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: Text(
                              'Supprimer',
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                );
                if (confirm == true) {
                  await message.reference.delete();
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('Message supprimé.')));
                }
              }
              : null,
      child: messageWidget,
    );
  }

  IconData _getFileIcon(String? fileType) {
    switch (fileType?.toLowerCase()) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'jpg':
      case 'jpeg':
      case 'png':
        return Icons.image;
      case 'txt':
        return Icons.text_snippet;
      default:
        return Icons.insert_drive_file;
    }
  }

  String _formatFileSize(int? bytes) {
    if (bytes == null) return '';
    if (bytes < 1024) return '$bytes o';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} Ko';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} Mo';
  }

  String _getFileTypeLabel(String? fileType) {
    switch (fileType?.toLowerCase()) {
      case 'pdf':
        return 'Document PDF';
      case 'doc':
      case 'docx':
        return 'Document';
      case 'jpg':
      case 'jpeg':
      case 'png':
        return 'Image';
      case 'txt':
        return 'Texte';
      default:
        return 'Fichier';
    }
  }

  Widget _buildFileMessage(
    String fileUrl,
    String fileName,
    String? fileType,
    int? fileSize,
    bool isMe,
  ) {
    final theme = Theme.of(context);
    final maxWidth = MediaQuery.of(context).size.width * 0.55;
    return InkWell(
      onTap: () => _launchFile(fileUrl),
      child: Container(
        margin: EdgeInsets.symmetric(vertical: 4),
        padding: EdgeInsets.all(12),
        constraints: BoxConstraints(maxWidth: maxWidth),
        decoration: BoxDecoration(
          color:
              isMe
                  ? theme.colorScheme.primary.withOpacity(0.1)
                  : theme.colorScheme.surfaceVariant,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.colorScheme.primary.withOpacity(0.2)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _getFileIcon(fileType),
                  color: theme.colorScheme.primary,
                  size: 32,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fileName,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Row(
                        children: [
                          Text(
                            _getFileTypeLabel(fileType),
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.onSurface.withOpacity(
                                0.6,
                              ),
                            ),
                          ),
                          if (fileSize != null) ...[
                            SizedBox(width: 8),
                            Text(
                              _formatFileSize(fileSize),
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.colorScheme.onSurface.withOpacity(
                                  0.6,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 8),
                Icon(Icons.download_rounded, color: theme.colorScheme.primary),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextMessage(String text, bool isMe) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color:
            isMe
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        text,
        style: GoogleFonts.inter(
          color:
              isMe
                  ? Colors.white
                  : Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  Future<void> _launchFile(String url) async {
    try {
      if (await canLaunch(url)) {
        await launch(url);
      } else {
        throw 'Impossible d\'ouvrir le fichier';
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de l\'ouverture du fichier: $e')),
      );
    }
  }

  Widget _buildAvatar(String userId) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(userId).get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return CircleAvatar(radius: 16, child: Icon(Icons.person));
        }
        final userData = snapshot.data!.data() as Map<String, dynamic>? ?? {};
        final photoUrl = userData['photoUrl'] as String?;
        return CircleAvatar(
          radius: 16,
          backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
          child: photoUrl == null ? Icon(Icons.person) : null,
        );
      },
    );
  }
}
