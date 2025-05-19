import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fourcoop/pages/group_detail_page.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fourcoop/pages/user_profile_page.dart'; // Importez votre page de profil
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'package:url_launcher/url_launcher.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';

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
    'mp3',
    'm4a',
  ];
  final _audioRecorder = AudioRecorder();
  final _audioPlayer = AudioPlayer();
  final List<String> _allowedAudioFormats = ['m4a', 'mp3', 'wav', 'aac'];
  final int _maxAudioDuration = 300; // 5 minutes maximum
  bool _isRecording = false;
  String? _recordingPath;
  String? _currentlyPlayingMessageId;
  bool _isLoadingAudio = false;

  @override
  void initState() {
    super.initState();
    _loadChatType();
    _requestPermissions();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });
  }

  @override
  void dispose() {
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    super.dispose();
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
    await Permission.microphone.request();
    await Permission.storage.request();
  }

  Future<void> _startRecording() async {
    try {
      if (await Permission.microphone.request().isGranted) {
        final directory = await getTemporaryDirectory();
        _recordingPath =
            '${directory.path}/audio_message_${DateTime.now().millisecondsSinceEpoch}.m4a';

        await _audioRecorder.start(
          RecordConfig(
            encoder: AudioEncoder.aacLc,
            bitRate: 128000,
            sampleRate: 44100,
            numChannels: 1,
          ),
          path: _recordingPath!,
        );

        setState(() => _isRecording = true);

        // Vérifier la durée pendant l'enregistrement
        Timer.periodic(Duration(seconds: 1), (timer) async {
          if (_isRecording) {
            final duration = await _audioRecorder.getDuration();
            if (duration != null && duration.inSeconds >= _maxAudioDuration) {
              await _stopRecording();
              timer.cancel();
            }
          } else {
            timer.cancel();
          }
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors du démarrage de l\'enregistrement: $e'),
        ),
      );
    }
  }

  Future<void> _stopRecording() async {
    try {
      final path = await _audioRecorder.stop();
      setState(() => _isRecording = false);

      if (path != null) {
        final duration = await _getAudioDuration(path);
        if (duration > 0 && duration <= _maxAudioDuration) {
          await _uploadAudioMessage(path);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'La durée de l\'enregistrement doit être entre 1 et $_maxAudioDuration secondes',
              ),
            ),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de l\'arrêt de l\'enregistrement: $e'),
        ),
      );
    }
  }

  Future<void> _uploadAudioMessage(String audioPath) async {
    try {
      setState(() => _isUploading = true);

      final fileName = 'audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
      final ref = _storage.ref().child('chat_audio/${widget.chatId}/$fileName');

      final uploadTask = await ref.putFile(File(audioPath));
      final downloadUrl = await uploadTask.ref.getDownloadURL();

      final duration = await _getAudioDuration(audioPath);

      await FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .collection('messages')
          .add({
            'text': '🎤 Message vocal',
            'audioUrl': downloadUrl,
            'duration': duration,
            'senderId': currentUser!.uid,
            'timestamp': FieldValue.serverTimestamp(),
          });

      setState(() => _isUploading = false);
    } catch (e) {
      setState(() => _isUploading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de l\'upload du message vocal: $e'),
        ),
      );
    }
  }

  Future<int> _getAudioDuration(String path) async {
    try {
      final duration = await _audioPlayer.getDuration();
      return duration?.inSeconds ?? 0;
    } catch (e) {
      print('Erreur lors de la récupération de la durée: $e');
      return 0;
    }
  }

  Future<void> _playAudio(String audioUrl, String messageId) async {
    try {
      if (_currentlyPlayingMessageId == messageId) {
        await _audioPlayer.stop();
        setState(() {
          _currentlyPlayingMessageId = null;
          _isLoadingAudio = false;
        });
      } else {
        setState(() {
          _currentlyPlayingMessageId = messageId;
          _isLoadingAudio = true;
        });

        // Vérifier si l'URL est valide
        if (!audioUrl.startsWith('http')) {
          throw 'URL audio invalide';
        }

        // Précharger l'audio
        await _audioPlayer.setSourceUrl(audioUrl);

        setState(() => _isLoadingAudio = false);
        await _audioPlayer.resume();

        _audioPlayer.onPlayerComplete.listen((_) {
          setState(() {
            _currentlyPlayingMessageId = null;
            _isLoadingAudio = false;
          });
        });

        _audioPlayer.onPlayerError.listen((error) {
          setState(() {
            _currentlyPlayingMessageId = null;
            _isLoadingAudio = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur lors de la lecture: $error')),
          );
        });
      }
    } catch (e) {
      setState(() {
        _currentlyPlayingMessageId = null;
        _isLoadingAudio = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erreur lors de la lecture: $e')));
    }
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
                        // Navigation vers les détails du groupe si besoin
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
                          child: Column(
                            crossAxisAlignment:
                                isMe
                                    ? CrossAxisAlignment.end
                                    : CrossAxisAlignment.start,
                            children: [
                              if (isGroupChat && !isMe)
                                FutureBuilder<DocumentSnapshot>(
                                  future:
                                      FirebaseFirestore.instance
                                          .collection('users')
                                          .doc(msg['senderId'])
                                          .get(),
                                  builder: (context, snapshot) {
                                    if (!snapshot.hasData ||
                                        !snapshot.data!.exists) {
                                      return SizedBox.shrink();
                                    }
                                    final senderData =
                                        snapshot.data!.data()
                                            as Map<String, dynamic>? ??
                                        {};
                                    final senderName =
                                        senderData['prenom'] ?? 'Utilisateur';
                                    return Padding(
                                      padding: const EdgeInsets.only(
                                        left: 8,
                                        bottom: 2,
                                      ),
                                      child: InkWell(
                                        onTap:
                                            () => _navigateToProfile(
                                              msg['senderId'],
                                            ),
                                        child: Text(
                                          senderName,
                                          style: GoogleFonts.inter(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                            color: theme.colorScheme.onSurface
                                                .withOpacity(0.7),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              Container(
                                constraints: BoxConstraints(
                                  maxWidth:
                                      MediaQuery.of(context).size.width * 0.75,
                                ),
                                padding: EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color:
                                      isMe
                                          ? theme.colorScheme.primaryContainer
                                          : theme.colorScheme.surfaceVariant,
                                  borderRadius: BorderRadius.only(
                                    topLeft: Radius.circular(16),
                                    topRight: Radius.circular(16),
                                    bottomLeft:
                                        isMe
                                            ? Radius.circular(16)
                                            : Radius.circular(4),
                                    bottomRight:
                                        isMe
                                            ? Radius.circular(4)
                                            : Radius.circular(16),
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
                                    color:
                                        isMe
                                            ? theme
                                                .colorScheme
                                                .onPrimaryContainer
                                            : theme.colorScheme.onSurface,
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                child: Text(
                                  _formatTimestamp(msg['timestamp']),
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    color: theme.colorScheme.onSurface
                                        .withOpacity(0.5),
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
                  IconButton(
                    icon: Icon(Icons.attach_file),
                    onPressed: _isUploading ? null : _pickAndUploadFile,
                    tooltip: 'Joindre un fichier',
                  ),
                  GestureDetector(
                    onLongPressStart: (_) => _startRecording(),
                    onLongPressEnd: (_) => _stopRecording(),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color:
                            _isRecording
                                ? theme.colorScheme.error
                                : theme.colorScheme.primary,
                      ),
                      child: Icon(
                        _isRecording ? Icons.stop : Icons.mic,
                        color: Colors.white,
                      ),
                    ),
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
    final hasFile = data['fileUrl'] != null;
    final hasAudio = data['audioUrl'] != null;
    final isPlaying = _currentlyPlayingMessageId == message.id;

    return Container(
      margin: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isMe) _buildAvatar(data['senderId']),
          Flexible(
            child: Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color:
                    isMe
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (hasFile) ...[
                    InkWell(
                      onTap: () => _launchFile(data['fileUrl']),
                      child: Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _getFileIcon(data['fileType']),
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                data['fileName'] ?? 'Fichier',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.primary,
                                  decoration: TextDecoration.underline,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 8),
                  ],
                  if (hasAudio) ...[
                    _buildAudioMessage(
                      data['audioUrl'],
                      message.id,
                      data['duration'] ?? 0,
                    ),
                    SizedBox(height: 8),
                  ],
                  if (data['text'] != null &&
                      data['text'].toString().isNotEmpty)
                    Text(
                      data['text'],
                      style: TextStyle(
                        color:
                            isMe
                                ? Colors.white
                                : Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (isMe) _buildAvatar(data['senderId']),
        ],
      ),
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

  Widget _buildAudioMessage(String audioUrl, String messageId, int duration) {
    final isPlaying = _currentlyPlayingMessageId == messageId;
    final theme = Theme.of(context);

    return InkWell(
      onTap: () => _playAudio(audioUrl, messageId),
      child: Container(
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_isLoadingAudio && isPlaying)
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: theme.colorScheme.primary,
                ),
              )
            else
              Icon(
                isPlaying ? Icons.stop : Icons.play_arrow,
                color: theme.colorScheme.primary,
              ),
            SizedBox(width: 8),
            Text(
              '${duration}s',
              style: TextStyle(color: theme.colorScheme.primary),
            ),
          ],
        ),
      ),
    );
  }
}
