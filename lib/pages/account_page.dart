import 'package:flutter/material.dart';

class AccountPage extends StatelessWidget {
  final String nom = "Teubo Melonou Jospin";
  final String email = "jospin@example.com";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Mon Compte')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Icon(Icons.account_circle, size: 100, color: Colors.grey),
            SizedBox(height: 16),
            Text(nom, style: Theme.of(context).textTheme.headlineSmall),
            SizedBox(height: 8),
            Text(email, style: Theme.of(context).textTheme.bodyMedium),
            SizedBox(height: 24),
            ListTile(
              leading: Icon(Icons.settings),
              title: Text('Paramètres du compte'),
              onTap: () {},
            ),
            ListTile(
              leading: Icon(Icons.logout),
              title: Text('Déconnexion'),
              onTap: () {
                // Action de déconnexion
              },
            ),
          ],
        ),
      ),
    );
  }
}
