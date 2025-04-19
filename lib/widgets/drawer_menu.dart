import 'package:flutter/material.dart';
import '../pages/tasks_page.dart';
import '../pages/mes_projets.dart';
import 'package:fourcoop/pages/home_page.dart';

class DrawerMenu extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        children: [
          DrawerHeader(child: Text('Menu')),
          ListTile(
            title: Text('Tâches / Diagrammes'),
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => TasksPage()));
            },
          ),
          ListTile(
            title: Text('Mes Projets'),
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => HomePage()));
            },
          ),
          ListTile(
            title: Text('Paramètres'),
            onTap: () {
              // Aller aux paramètres
            },
          ),
        ],
      ),
    );
  }
}
