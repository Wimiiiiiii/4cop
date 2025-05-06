import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chat_page.dart';

class GroupCreationPage extends StatefulWidget {
  final String currentUserId; 

  const GroupCreationPage({Key? key, required this.currentUserId}) : super(key: key);  // Constructor avec currentUserId

  @override
  _GroupCreationPageState createState() => _GroupCreationPageState();
}

class _GroupCreationPageState extends State<GroupCreationPage> {
  final TextEditingController _groupNameController = TextEditingController();
  List<String> selectedUserIds = [];

void _createGroupChat() async {
  if (selectedUserIds.isEmpty || _groupNameController.text.trim().isEmpty) return;

  // Création du groupe
  final newGroup = await FirebaseFirestore.instance.collection('chats').add({
    'name': _groupNameController.text.trim(),
    'participants': [widget.currentUserId, ...selectedUserIds],
    'isGroup': true,
    'createdAt': FieldValue.serverTimestamp(),
  });

  final groupId = newGroup.id;

  // Aller vers la page de chat du groupe
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => ChatPage(
      chatId: groupId,
      isGroup: true,
      ),
    ),
  );
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Créer un groupe')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _groupNameController,
              decoration: InputDecoration(
                hintText: 'Nom du groupe',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('users').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return Center(child: CircularProgressIndicator());

                final users = snapshot.data!.docs.where((doc) => doc.id != widget.currentUserId).toList(); // Utilisation de widget.currentUserId

                return ListView.builder(
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    final user = users[index];
                    final data = user.data() as Map<String, dynamic>;
                    final name = data['nom'] ?? 'Utilisateur';
                    final email = data['email'] ?? '';

                    final isSelected = selectedUserIds.contains(user.id);

                    return CheckboxListTile(
                      title: Text(name),
                      subtitle: Text(email),
                      value: isSelected,
                      onChanged: (val) {
                        setState(() {
                          if (val == true) {
                            selectedUserIds.add(user.id);
                          } else {
                            selectedUserIds.remove(user.id);
                          }
                        });
                      },
                    );
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: ElevatedButton.icon(
              onPressed: _createGroupChat,
              icon: Icon(Icons.group_add),
              label: Text('Créer le groupe'),
            ),
          ),
        ],
      ),
    );
  }
}
