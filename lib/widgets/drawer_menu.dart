import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fourcoop/auth_page.dart';
import 'package:fourcoop/pages/account_page.dart';
import 'package:fourcoop/pages/home_page.dart';
import 'package:fourcoop/pages/mes_projets.dart';
import 'package:fourcoop/pages/tasks_page.dart';
import 'package:google_fonts/google_fonts.dart';

class DrawerMenu extends StatelessWidget {
  final User? user = FirebaseAuth.instance.currentUser;

  Future<void> _signOut(BuildContext context) async {
    try {
      await FirebaseAuth.instance.signOut();
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => AuthPage()),
          (route) => false, // supprime toutes les routes précédentes
        );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de la déconnexion: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<DocumentSnapshot> _getUserData() async {
    if (user == null) throw Exception('Utilisateur non connecté');
    return FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .get();
  }

  // Méthode pour naviguer en utilisant la classe directement
  void _navigateTo(BuildContext context, Widget page) {
    Navigator.pop(context); // Ferme le drawer
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => page),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Drawer(
      width: MediaQuery.of(context).size.width * 0.8,
      child: Column(
        children: [
          FutureBuilder<DocumentSnapshot>(
            future: _getUserData(),
            builder: (context, snapshot) {
              final isLoading = snapshot.connectionState == ConnectionState.waiting;
              final hasError = snapshot.hasError;
              final userData = snapshot.data?.data() as Map<String, dynamic>?;

              return UserAccountsDrawerHeader(
                margin: EdgeInsets.zero,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      theme.colorScheme.primary,
                      theme.colorScheme.primaryContainer,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                accountName: Text(
                  isLoading 
                    ? 'Chargement...'
                    : hasError
                      ? 'Erreur de chargement'
                      : userData?['nom'] ?? 'Nom inconnu',
                  style: GoogleFonts.interTight(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                accountEmail: Text(
                  user?.email ?? 'Non connecté',
                  style: GoogleFonts.inter(),
                ),
                currentAccountPicture: CircleAvatar(
                  backgroundColor: theme.colorScheme.surface,
                  backgroundImage: userData?['photo_url'] != null
                      ? NetworkImage(userData!['photo_url']!) as ImageProvider
                      : const AssetImage('assets/images/default_profile.jpg'),
                  child: userData?['photo_url'] == null
                      ? Icon(
                          Icons.person,
                          size: 40,
                          color: theme.colorScheme.onSurface,
                        )
                      : null,
                ),
              );
            },
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _buildDrawerItem(
                  context,
                  icon: Icons.dashboard,
                  title: 'Accueil',
                  page: HomePage(), // Utilisation directe de la classe
                ),
                _buildDrawerItem(
                  context,
                  icon: Icons.task,
                  title: 'Tâches & Diagrammes',
                  page: TasksPage(), // Utilisation directe de la classe
                ),
                _buildDrawerItem(
                  context,
                  icon: Icons.work,
                  title: 'Mes Projets',
                  page: MesProjets(), // Utilisation directe de la classe
                ),
                const Divider(height: 1),
                _buildDrawerItem(
                  context,
                  icon: Icons.settings,
                  title: 'Paramètres',
                  page: AccountPage(), // Utilisation directe de la classe
                ),
                

              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: theme.colorScheme.error,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () => _signOut(context),
                icon: const Icon(Icons.logout),
                label: Text(
                  'Se déconnecter',
                  style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required Widget page, // Maintenant on attend un Widget directement
  }) {
    final theme = Theme.of(context);

    return ListTile(
      leading: Icon(
        icon,
        color: theme.colorScheme.onSurface.withOpacity(0.8),
      ),
      title: Text(
        title,
        style: GoogleFonts.inter(
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: () => _navigateTo(context, page), // Utilisation de la méthode de navigation
      contentPadding: const EdgeInsets.symmetric(horizontal: 24),
    );
  }
}