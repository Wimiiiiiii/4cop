import 'package:flutter/material.dart';

class MessagingPage extends StatelessWidget {
  final List<Map<String, String>> messages = [
    {"from": "Alice", "content": "Salut, t'as avancé sur le projet ?"},
    {"from": "Toi", "content": "Oui, j’ai fait la maquette."},
    {"from": "Bob", "content": "On peut avoir une réunion demain ?"},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Messagerie')),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final msg = messages[index];
                return ListTile(
                  title: Text(msg["from"] ?? ""),
                  subtitle: Text(msg["content"] ?? ""),
                  leading: CircleAvatar(child: Text(msg["from"]![0])),
                );
              },
            ),
          ),
          Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Row(
              children: [
                Expanded(child: TextField(decoration: InputDecoration(hintText: "Envoyer un message..."))),
                IconButton(onPressed: () {}, icon: Icon(Icons.send)),
              ],
            ),
          )
        ],
      ),
    );
  }
}
