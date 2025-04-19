import 'package:flutter/material.dart';
import 'project_detail_page.dart';

class ProjectListPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final projets = [
      {'titre': 'Projet 1', 'resume': 'Résumé du projet 1'},
      {'titre': 'Projet 2', 'resume': 'Résumé du projet 2'},
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text('Projets'),
        actions: [
          IconButton(icon: Icon(Icons.message), onPressed: () {/* messagerie */}),
          IconButton(icon: Icon(Icons.account_circle), onPressed: () {/* compte */}),
        ],
      ),
      body: ListView.builder(
        itemCount: projets.length,
        itemBuilder: (context, index) {
          return ListTile(
            title: Text(projets[index]['titre']!),
            subtitle: Text(projets[index]['resume']!),
            trailing: IconButton(icon: Icon(Icons.star_border), onPressed: () {}),
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => ProjectDetailPage()));
            },
          );
        },
      ),
    );
  }
}
