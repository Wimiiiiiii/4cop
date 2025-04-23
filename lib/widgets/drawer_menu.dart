import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../auth_page.dart';
import '../getuserdata.dart';
import '../pages/account_page.dart';
import '../pages/tasks_page.dart';
import '../pages/mes_projets.dart';
import '../pages/home_page.dart';

class DrawerMenu extends StatelessWidget {
  final user = FirebaseAuth.instance.currentUser;

  void _signOut(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => AuthPage()),
    ); // Assure-toi que cette route existe
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: FutureBuilder<DocumentSnapshot>(
        future: getUserData(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(child: CircularProgressIndicator());
          }

          var userData = snapshot.data!.data() as Map<String, dynamic>;

          return Column(
            children: [
              UserAccountsDrawerHeader(
                accountName: Text(userData['nom'] ?? 'Nom inconnu'),
                accountEmail: Text(user?.email ?? 'Email inconnu'),
                currentAccountPicture: CircleAvatar(
                  backgroundColor: Colors.white,
                  backgroundImage: userData['photo_url'] != null
                      ? NetworkImage(userData['photo_url']!)
                      : AssetImage('assets/images/imagepardefaut.jpg'),
                  child: userData['photo_url'] == null
                      ? Icon(Icons.person, size: 40, color: Colors.grey)
                      : null,
                ),

                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blueAccent, Colors.lightBlue],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
              ListTile(
                
                leading: Icon(Icons.dashboard_customize),
                title: Text('Accueil'),
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => HomePage()));
                },
              ),
              ListTile(
                leading: Icon(Icons.task),
                title: Text('Tâches / Diagrammes'),
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => TasksPage()));
                },
              ),
              ListTile(
                leading: Icon(Icons.work),
                title: Text('Mes Projets'),
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => MesProjets()));
                },
              ),
              Divider(),
              ListTile(
                leading: Icon(Icons.settings),
                title: Text('Paramètres'),
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => AccountPage()));
                },
              ),
              Spacer(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    minimumSize: Size(double.infinity, 45),
                    backgroundColor: Colors.redAccent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => _signOut(context),
                  icon: Icon(Icons.logout),
                  label: Text('Se déconnecter'),
                ),
              )
            ],
          );
        },
      ),
    );
  }
}