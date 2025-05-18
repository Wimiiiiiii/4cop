import 'package:flutter/material.dart';
import 'package:fourcoop/pages/project_detail_page.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'create_project_form.dart';
import '../../widgets/drawer_menu.dart';

class MesProjets extends StatefulWidget {
  final Function(String, String)? onProjectSelected;
  final bool showAppBar;
  final bool showDrawer;
  final bool showFAB;
  final bool isTaskSelectionMode;

  const MesProjets({
    Key? key,
    this.onProjectSelected,
    this.showAppBar = true,
    this.showDrawer = true,
    this.showFAB = true,
    this.isTaskSelectionMode = false,
  }) : super(key: key);

  @override
  State<MesProjets> createState() => _MesProjetsState();
}

class _MesProjetsState extends State<MesProjets> {
  String _filterStatus = 'Tous';
  final List<String> _statusOptions = [
    'Tous',
    'En attente',
    'En cours',
    'Terminé',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(
        body: Center(
          child: Text("Utilisateur non connecté.", style: GoogleFonts.inter()),
        ),
      );
    }

    Widget bodyContent = Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            theme.colorScheme.background.withOpacity(0.3),
            theme.colorScheme.background,
          ],
          stops: [0, 0.3],
        ),
      ),
      child: _buildProjectsList(theme, user),
    );

    // Si c'est utilisé comme page autonome
    if (widget.showAppBar) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            widget.isTaskSelectionMode
                ? 'Sélectionner un projet'
                : 'Mes Projets',
            style: GoogleFonts.interTight(
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
          centerTitle: true,
          elevation: 0,
          flexibleSpace: Container(
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
          ),
          actions:
              widget.isTaskSelectionMode
                  ? []
                  : [
                    IconButton(
                      icon: const Icon(Icons.filter_list),
                      onPressed: () => _showFilterDialog(context),
                    ),
                  ],
        ),
        drawer: widget.showDrawer ? DrawerMenu() : null,
        body: bodyContent,
        floatingActionButton:
            widget.showFAB
                ? FloatingActionButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const CreateProjectForm(),
                      ),
                    );
                  },
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: Colors.white,
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.add),
                )
                : null,
      );
    }

    // Si c'est utilisé comme widget dans une autre page
    return bodyContent;
  }

  Widget _buildProjectsList(ThemeData theme, User user) {
    return StreamBuilder<QuerySnapshot>(
      stream:
          FirebaseFirestore.instance
              .collection('projets')
              .where('membres', arrayContains: user.email)
              .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.work_outline,
                  size: 48,
                  color: theme.colorScheme.onSurface.withOpacity(0.3),
                ),
                const SizedBox(height: 16),
                Text(
                  "Aucun projet trouvé",
                  style: GoogleFonts.inter(
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          );
        }

        final allProjects = snapshot.data!.docs;
        final filteredProjects =
            _filterStatus == 'Tous'
                ? allProjects
                : allProjects
                    .where(
                      (doc) => (doc.data() as Map)['status'] == _filterStatus,
                    )
                    .toList();

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceVariant,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.filter_alt,
                          size: 16,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _filterStatus,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${filteredProjects.length} projet(s)',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                itemCount: filteredProjects.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final projet = filteredProjects[index];
                  final data = projet.data() as Map<String, dynamic>;

                  final String title = data['titre'] ?? 'Sans titre';
                  final String status = data['status'] ?? 'Indéfini';
                  final String themeName = data['theme'] ?? '';
                  final String date = data['date'] ?? '';
                  final statusColor = _getStatusColor(status, theme);

                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Material(
                      borderRadius: BorderRadius.circular(16),
                      color: theme.colorScheme.surface,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () {
                          if (widget.isTaskSelectionMode &&
                              widget.onProjectSelected != null) {
                            widget.onProjectSelected!(projet.id, title);
                          } else {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (context) =>
                                        ProjectDetailPage(projetId: projet.id),
                              ),
                            );
                          }
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: statusColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: statusColor.withOpacity(0.3),
                                        width: 1,
                                      ),
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
                                      color: theme.colorScheme.onSurface
                                          .withOpacity(0.6),
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
                                  Icon(
                                    Icons.category,
                                    size: 16,
                                    color: theme.colorScheme.primary,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    themeName,
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      color: theme.colorScheme.onSurface
                                          .withOpacity(0.8),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
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
      builder:
          (context) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Filtrer par statut',
                    style: GoogleFonts.interTight(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ..._statusOptions.map((status) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () {
                            setState(() => _filterStatus = status);
                            Navigator.pop(context);
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 8,
                              horizontal: 8,
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color:
                                          _filterStatus == status
                                              ? theme.colorScheme.primary
                                              : theme.colorScheme.outline
                                                  .withOpacity(0.3),
                                      width: 2,
                                    ),
                                  ),
                                  child:
                                      _filterStatus == status
                                          ? Center(
                                            child: Container(
                                              width: 12,
                                              height: 12,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color:
                                                    theme.colorScheme.primary,
                                              ),
                                            ),
                                          )
                                          : null,
                                ),
                                const SizedBox(width: 16),
                                Text(status, style: GoogleFonts.inter()),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),
          ),
    );
  }
}
