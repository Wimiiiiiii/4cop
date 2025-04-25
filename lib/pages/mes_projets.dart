import 'package:flutter/material.dart';
import 'package:fourcoop/pages/project_detail_page.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'create_project_form.dart';
import '../../widgets/drawer_menu.dart';

class MesProjets extends StatefulWidget {
  const MesProjets({Key? key}) : super(key: key);

  @override
  State<MesProjets> createState() => _MesProjetsState();
}

class _MesProjetsState extends State<MesProjets> {
  String _filterStatus = 'Tous';
  final List<String> _statusOptions = ['Tous', 'En attente', 'En cours', 'Terminé'];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text("Utilisateur non connecté.")),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Mes Projets', style: GoogleFonts.interTight(fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () => _showFilterDialog(context),
          ),
        ],
      ),
      drawer:  DrawerMenu(),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('projets')
            .where('members', arrayContains: user.email)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("Aucun projet trouvé."));
          }

          final allProjects = snapshot.data!.docs;
          final filteredProjects = _filterStatus == 'Tous'
              ? allProjects
              : allProjects.where((doc) => (doc.data() as Map)['status'] == _filterStatus).toList();

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Chip(
                      label: Text('Filtre: $_filterStatus', style: GoogleFonts.inter(fontSize: 12)),
                      backgroundColor: theme.colorScheme.surfaceVariant,
                    ),
                    const Spacer(),
                    Text(
                      '${filteredProjects.length} projet(s)',
                      style: GoogleFonts.inter(
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: filteredProjects.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final projet = filteredProjects[index];
                    final data = projet.data() as Map<String, dynamic>;

                    final String title = data['titre'] ?? 'Sans titre';
                    final String status = data['status'] ?? 'Indéfini';
                    final String themeName = data['theme'] ?? '';
                    final String date = data['date'] ?? '';
                    final double progress = (data['progress'] ?? 0).toDouble();
                    final statusColor = _getStatusColor(status, theme);

                    return Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: theme.colorScheme.outline.withOpacity(0.1),
                        ),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ProjectDetailPage(projetId: projet.id),
                            ),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: statusColor.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      status,
                                      style: GoogleFonts.inter(
                                        color: statusColor,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    date,
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                title,
                                style: GoogleFonts.interTight(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(Icons.category, size: 16, color: theme.colorScheme.primary),
                                  const SizedBox(width: 4),
                                  Text(
                                    themeName,
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      color: theme.colorScheme.onSurface.withOpacity(0.8),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(3),
                                child: LinearProgressIndicator(
                                  value: progress / 100,
                                  backgroundColor: theme.colorScheme.surfaceVariant,
                                  color: statusColor,
                                  minHeight: 6,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Align(
                                alignment: Alignment.centerRight,
                                child: Text(
                                  '${progress.toInt()}%',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CreateProjectForm()),
          );
        },
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.add),
      ),
    );
  }

  Color _getStatusColor(String? status, ThemeData theme) {
    switch (status) {
      case 'En attente':
        return theme.colorScheme.error;
      case 'En cours':
        return theme.colorScheme.primary;
      case 'Terminé':
        return theme.colorScheme.secondary;
      default:
        return theme.colorScheme.onSurface;
    }
  }

  void _showFilterDialog(BuildContext context) {
    final theme = Theme.of(context);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Filtrer par statut', style: GoogleFonts.interTight()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: _statusOptions.map((status) {
            return RadioListTile<String>(
              title: Text(status, style: GoogleFonts.inter()),
              value: status,
              groupValue: _filterStatus,
              onChanged: (value) {
                setState(() => _filterStatus = value!);
                Navigator.pop(context);
              },
              activeColor: theme.colorScheme.primary,
            );
          }).toList(),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}
