import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fourcoop/auth_page.dart';
import 'package:fourcoop/pages/account_page.dart';
import 'package:fourcoop/pages/home_page.dart';
import 'package:fourcoop/pages/inbox_page.dart';
import 'package:fourcoop/pages/mes_projets.dart';
import 'package:fourcoop/pages/shared_tasks_page.dart';
import 'package:fourcoop/pages/project_selection_page.dart';
import 'package:google_fonts/google_fonts.dart';

class DrawerMenu extends StatelessWidget {
  final User? user = FirebaseAuth.instance.currentUser;

  Future<void> _signOut(BuildContext context) async {
    try {
      await FirebaseAuth.instance.signOut();
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => AuthPage()),
        (route) => false,
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
    return FirebaseFirestore.instance.collection('users').doc(user!.uid).get();
  }

  void _navigateTo(BuildContext context, Widget page) {
    Navigator.pop(context);
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Drawer(
      width: MediaQuery.of(context).size.width * 0.8,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              theme.colorScheme.background,
              theme.colorScheme.surfaceVariant,
            ],
          ),
        ),
        child: Column(
          children: [
            // Header avec dégradé
            Container(
              height: 200,
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
              child: FutureBuilder<DocumentSnapshot>(
                future: _getUserData(),
                builder: (context, snapshot) {
                  final isLoading =
                      snapshot.connectionState == ConnectionState.waiting;
                  final hasError = snapshot.hasError;
                  final userData =
                      snapshot.data?.data() as Map<String, dynamic>?;

                  return Padding(
                    padding: const EdgeInsets.only(
                      left: 24,
                      bottom: 24,
                      right: 24,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2,
                                ),
                                image:
                                    userData?['photo_url'] != null
                                        ? DecorationImage(
                                          image: NetworkImage(
                                            userData!['photo_url']!,
                                          ),
                                          fit: BoxFit.cover,
                                        )
                                        : const DecorationImage(
                                          image: AssetImage(
                                            'assets/images/4Cop.png',
                                          ),
                                        ),
                              ),
                              child:
                                  userData?['photo_url'] == null
                                      ? Icon(
                                        Icons.person,
                                        size: 32,
                                        color: Colors.white,
                                      )
                                      : null,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isLoading
                                        ? 'Chargement...'
                                        : hasError
                                        ? 'Erreur de chargement'
                                        : '${userData?['prenom'] ?? ''} ${userData?['nom'] ?? ''}'
                                            .trim(),
                                    style: GoogleFonts.interTight(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    user?.email ?? 'Non connecté',
                                    style: GoogleFonts.inter(
                                      color: Colors.white.withOpacity(0.9),
                                      fontSize: 14,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // Menu items
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(top: 16),
                children: [
                  _buildDrawerItem(
                    context,
                    icon: Icons.dashboard_rounded,
                    title: 'Accueil',
                    page: HomePage(),
                  ),
                  _buildDrawerItem(
                    context,
                    icon: Icons.assignment_rounded,
                    title: 'Tâches partagées',
                    page: const ProjectSelectionPage(),
                  ),
                  _buildDrawerItem(
                    context,
                    icon: Icons.work_rounded,
                    title: 'Mes Projets',
                    page: MesProjets(),
                  ),
                  _buildDrawerItem(
                    context,
                    icon: Icons.email_rounded,
                    title: 'Messagerie',
                    page: InboxPage(),
                  ),
                  const Divider(
                    height: 24,
                    thickness: 1,
                    indent: 24,
                    endIndent: 24,
                    color: Colors.white24,
                  ),
                  _buildDrawerItem(
                    context,
                    icon: Icons.settings_rounded,
                    title: 'Paramètres',
                    page: AccountPage(),
                  ),
                ],
              ),
            ),

            // Bouton de déconnexion
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.error.withOpacity(0.9),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  onPressed: () => _signOut(context),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.logout, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Se déconnecter',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required Widget page,
  }) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.transparent,
      ),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: theme.colorScheme.primary),
        ),
        title: Text(
          title,
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w500,
            color: theme.colorScheme.onSurface,
          ),
        ),
        trailing: Icon(
          Icons.chevron_right,
          color: theme.colorScheme.onSurface.withOpacity(0.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 8),
        onTap: () => _navigateTo(context, page),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
