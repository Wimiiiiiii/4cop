import 'package:flutter/material.dart';
import 'project_list_page.dart';
import 'create_project_form.dart';
import '../../widgets/drawer_menu.dart';

class HomePage extends StatelessWidget {
  final List<String> projets = ['Mon projet 1', 'Mon projet 2'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Mes Projets')),
      drawer: DrawerMenu(),
      body: ListView.builder(
        itemCount: projets.length,
        itemBuilder: (context, index) {
          return ListTile(
            title: Text(projets[index]),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => ProjectListPage()),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => CreateProjectForm()));
        },
        child: Icon(Icons.add),
        tooltip: 'Créer un projet',
      ),
    );
  }
}
