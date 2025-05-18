import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:fourcoop/pages/EditProjetPage.dart';
import 'package:fourcoop/pages/candidature_page.dart';
import 'package:fourcoop/pages/chat_page.dart';
import 'package:fourcoop/pages/group_creation_page.dart';
import 'package:fourcoop/pages/user_profile_page.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';

class ProjectDetailPage extends StatefulWidget {
  final String projetId;

  const ProjectDetailPage({super.key, required this.projetId});

  @override
  State<ProjectDetailPage> createState() => _ProjectDetailPageState();
}

class _ProjectDetailPageState extends State<ProjectDetailPage> {
  bool hasSubmitted = false;
  late final DocumentReference projetRef;
  final DateFormat dateFormat = DateFormat('dd MMM yyyy', 'fr_FR');
  bool _isMenuOpen = false;

  @override
  void initState() {
    super.initState();
    projetRef = FirebaseFirestore.instance
        .collection('projets')
        .doc(widget.projetId);
    checkIfAlreadySubmitted();
  }

  Future<void> checkIfAlreadySubmitted() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc =
          await FirebaseFirestore.instance
              .collection('projets')
              .doc(widget.projetId)
              .collection('candidatures')
              .doc(user.uid)
              .get();
      if (doc.exists) {
        setState(() {
          hasSubmitted = true;
        });
      }
    }
  }

  Future<void> _goToUserProfile(String email) async {
    try {
      final querySnapshot =
          await FirebaseFirestore.instance
              .collection('users')
              .where('email', isEqualTo: email)
              .limit(1)
              .get();

      if (querySnapshot.docs.isNotEmpty) {
        final userId = querySnapshot.docs.first.id;

        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => UserProfilePage(userId: userId)),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Utilisateur non trouvé pour cet e-mail')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erreur : ${e.toString()}')));
    }
  }

  Future<void> submitCandidature() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance
          .collection('projets')
          .doc(widget.projetId)
          .collection('candidatures')
          .doc(user.uid)
          .set({
            'email': user.email,
            'status': 'en attente',
            'submittedAt': FieldValue.serverTimestamp(),
          });
      setState(() {
        hasSubmitted = true;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Candidature soumise')));
    }
  }

  void _startNewGroup() {
    final user = FirebaseAuth.instance.currentUser;
    setState(() => _isMenuOpen = false);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => GroupCreationPage(
              currentUserId: user!.uid,
              projetId: widget.projetId,
            ),
      ),
    );
  }

  Future<void> _toggleFavorite(bool isFavorite) async {
    try {
      await projetRef.update({'isFavorite': !isFavorite});
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de la mise à jour: $e')),
      );
    }
  }

  Future<void> _deleteProject() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final projetDoc = await projetRef.get();
    final data = projetDoc.data() as Map<String, dynamic>;

    if (data['proprietaire'] != currentUser.uid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Seul le créateur peut supprimer ce projet'),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(
              'Supprimer le projet',
              style: GoogleFonts.interTight(fontWeight: FontWeight.bold),
            ),
            content: Text(
              'Êtes-vous sûr de vouloir supprimer ce projet ? Cette action est irréversible.',
              style: GoogleFonts.inter(),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Annuler', style: GoogleFonts.inter()),
              ),
              TextButton(
                onPressed: () async {
                  try {
                    // Supprimer les sous-collections d'abord
                    await _deleteSubcollections();
                    // Supprimer le projet
                    await projetRef.delete();
                    if (!mounted) return;
                    Navigator.pop(context); // Ferme la boîte de dialogue
                    Navigator.pop(context); // Retourne à la page précédente
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Projet supprimé avec succès'),
                      ),
                    );
                  } catch (e) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Erreur lors de la suppression: $e'),
                      ),
                    );
                  }
                },
                child: Text(
                  'Supprimer',
                  style: GoogleFonts.inter(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ),
            ],
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
    );
  }

  Future<void> _deleteSubcollections() async {
    // Supprimer les candidatures
    final candidatures = await projetRef.collection('candidatures').get();
    for (var doc in candidatures.docs) {
      await doc.reference.delete();
    }
    final membres = await projetRef.collection('membres').get();
    for (var doc in membres.docs) {
      await doc.reference.delete();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Détails du projet',
          style: GoogleFonts.interTight(
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
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
        actions: [
          StreamBuilder<DocumentSnapshot>(
            stream: projetRef.snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const SizedBox.shrink();

              final data = snapshot.data!.data() as Map<String, dynamic>;
              final currentUser = FirebaseAuth.instance.currentUser;
              final isOwner =
                  currentUser != null &&
                  data['proprietaire'] == currentUser.uid;
              final isFavorite = data['isFavorite'] ?? false;

              return Row(
                children: [
                  if (isOwner)
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.white),
                      onPressed: _deleteProject,
                    ),
                  IconButton(
                    icon: Icon(
                      isFavorite ? Icons.favorite : Icons.favorite_border,
                      color: isFavorite ? Colors.red : Colors.white,
                    ),
                    onPressed: () => _toggleFavorite(isFavorite),
                  ),
                  IconButton(
                    icon: const Icon(Icons.share, color: Colors.white),
                    onPressed: () => _shareProject(),
                  ),
                ],
              );
            },
          ),
        ],
      ),
      body: Container(
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
        child: StreamBuilder<DocumentSnapshot>(
          stream: projetRef.snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (!snapshot.hasData || !snapshot.data!.exists) {
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
                      'Projet non trouvé',
                      style: GoogleFonts.inter(
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              );
            }

            final data = snapshot.data!.data() as Map<String, dynamic>;
            final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
            final imageUrl = data['imageUrl'] as String?;
            final contact = data['contact'] as String?;
            final currentUser = FirebaseAuth.instance.currentUser;
            final isOwner =
                currentUser != null && data['proprietaire'] == currentUser.uid;

            return Stack(
              children: [
                SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Image du projet
                      Container(
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
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child:
                              imageUrl != null && imageUrl.isNotEmpty
                                  ? Image.network(
                                    imageUrl,
                                    width: double.infinity,
                                    height: 220,
                                    fit: BoxFit.cover,
                                    errorBuilder:
                                        (_, __, ___) =>
                                            _buildImagePlaceholder(theme),
                                  )
                                  : _buildImagePlaceholder(theme),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Titre et métadonnées
                      Text(
                        data['titre'] ?? 'Titre non spécifié',
                        style: GoogleFonts.interTight(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),

                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if ((data['theme'] as String?)?.isNotEmpty ?? false)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary.withOpacity(
                                  0.1,
                                ),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: theme.colorScheme.primary.withOpacity(
                                    0.3,
                                  ),
                                ),
                              ),
                              child: Text(
                                data['theme'] as String,
                                style: GoogleFonts.inter(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          if (data['pays'] != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.secondary.withOpacity(
                                  0.1,
                                ),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: theme.colorScheme.secondary
                                      .withOpacity(0.3),
                                ),
                              ),
                              child: Text(
                                data['pays'],
                                style: GoogleFonts.inter(
                                  color: theme.colorScheme.secondary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          if (createdAt != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surfaceVariant,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                dateFormat.format(createdAt),
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Résumé
                      _buildSectionTitle('Résumé'),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Text(
                          data['resume'] ?? 'Aucun résumé fourni',
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            height: 1.5,
                            color: theme.colorScheme.onSurface.withOpacity(0.8),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Description
                      _buildSectionTitle('Description'),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Text(
                          data['description'] ??
                              'Aucune description disponible',
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            height: 1.5,
                            color: theme.colorScheme.onSurface.withOpacity(0.8),
                          ),
                        ),
                      ),

                      if (data['duree'] != null) ...[
                        const SizedBox(height: 24),
                        _buildSectionTitle('Durée'),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Text(
                            data['duree'],
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              color: theme.colorScheme.onSurface.withOpacity(
                                0.8,
                              ),
                            ),
                          ),
                        ),
                      ],

                      if (contact != null && contact.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        _buildSectionTitle('Contact'),
                        const SizedBox(height: 12),
                        InkWell(
                          onTap: () => _goToUserProfile(contact),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surface,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.email,
                                  color: theme.colorScheme.primary,
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Text(
                                    contact,
                                    style: GoogleFonts.inter(
                                      color: theme.colorScheme.primary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                Icon(
                                  Icons.chevron_right,
                                  color: theme.colorScheme.onSurface
                                      .withOpacity(0.3),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],

                      if (isOwner) ...[
                        // Section Candidatures
                        const SizedBox(height: 24),
                        _buildSectionTitle('Candidatures'),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Consultez les candidatures reçues.",
                                style: GoogleFonts.inter(
                                  fontSize: 15,
                                  color: theme.colorScheme.onSurface
                                      .withOpacity(0.8),
                                ),
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: theme.colorScheme.primary,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  icon: const Icon(
                                    Icons.assignment_ind,
                                    color: Colors.white,
                                  ),
                                  label: const Text(
                                    'Voir les candidatures',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder:
                                            (_) => CandidaturesPage(
                                              projetId: widget.projetId,
                                            ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      if (!isOwner) ...[
                        const SizedBox(height: 24),
                        _buildSectionTitle('Actions'),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  backgroundColor: Theme.of(context).cardColor,
                                ),
                                onPressed: () async {
                                  final String ownerId = data['proprietaire'];
                                  final String userId = currentUser!.uid;

                                  // Debug
                                  print("OwnerID: $ownerId | UserID: $userId");

                                  if (ownerId == userId) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          "Vous ne pouvez pas vous envoyer un message à vous-même",
                                        ),
                                      ),
                                    );
                                    return;
                                  }

                                  final chatId = _generateChatId(
                                    userId,
                                    ownerId,
                                  );
                                  print("Generated ChatID: $chatId");

                                  try {
                                    final chatDoc =
                                        await FirebaseFirestore.instance
                                            .collection('chats')
                                            .doc(chatId)
                                            .get();

                                    if (!chatDoc.exists) {
                                      print("Création d'un nouveau chat...");
                                      await FirebaseFirestore.instance
                                          .collection('chats')
                                          .doc(chatId)
                                          .set({
                                            'participants': [userId, ownerId],
                                            'createdAt':
                                                FieldValue.serverTimestamp(),
                                            'lastSeen_${currentUser.uid}':
                                                FieldValue.serverTimestamp(),
                                            'lastSeen_$ownerId':
                                                FieldValue.serverTimestamp(),
                                            'timestamp':
                                                FieldValue.serverTimestamp(),
                                          });
                                    }

                                    if (!mounted) return;

                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder:
                                            (_) => ChatPage(
                                              chatId: chatId,
                                              otherUserId: ownerId,
                                            ),
                                      ),
                                    );
                                  } catch (e) {
                                    print("Erreur chat: $e");
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          "Erreur: ${e.toString()}",
                                        ),
                                      ),
                                    );
                                  }
                                },
                                icon: const Icon(Icons.chat),
                                label: const Text('Contacter'),
                              ),
                            ),

                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed:
                                    hasSubmitted ? null : submitCandidature,
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  backgroundColor:
                                      hasSubmitted
                                          ? Colors.grey
                                          : Theme.of(context).cardColor,
                                ),
                                child: Text(
                                  hasSubmitted ? 'Déjà postulé' : 'Postuler',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],

                      const SizedBox(height: 100),
                    ],
                  ),
                ),

                if (isOwner)
                  Positioned(
                    bottom: 24,
                    right: 24,
                    child: SpeedDial(
                      icon: Icons.add,
                      activeIcon: Icons.close,
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: Colors.white,
                      children: [
                        SpeedDialChild(
                          child: const Icon(Icons.edit),
                          backgroundColor: theme.colorScheme.secondary,
                          label: 'Modifier le projet',
                          labelStyle: GoogleFonts.inter(),
                          onTap: () => _editProject(),
                        ),
                        SpeedDialChild(
                          child: const Icon(Icons.group_add),
                          backgroundColor: theme.colorScheme.tertiary,
                          label: 'Créer un groupe',
                          labelStyle: GoogleFonts.inter(),
                          onTap:
                              () =>
                                  _startNewGroup(), // définie dans ton code déjà
                        ),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildImagePlaceholder(ThemeData theme) {
    return Container(
      width: double.infinity,
      height: 220,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Icon(
          Icons.photo_camera,
          size: 48,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.interTight(fontSize: 20, fontWeight: FontWeight.bold),
    );
  }

  String _generateChatId(String userId1, String userId2) {
    final sorted = [userId1, userId2]..sort();
    return '${sorted[0]}_${sorted[1]}';
  }

  Future<void> _shareProject() async {
    try {
      final projetDoc =
          await FirebaseFirestore.instance
              .collection('projets')
              .doc(widget.projetId)
              .get();

      if (!projetDoc.exists) return;

      final data = projetDoc.data() as Map<String, dynamic>;
      final titre = data['titre'] ?? 'Un projet FourCoop';
      final resume = data['resume'] ?? 'Découvrez ce projet intéressant';
      final theme = data['theme'] ?? '';
      final pays = data['pays'] ?? '';

      final message = """
  🚀 $titre

  ${theme.isNotEmpty ? '📌 Thème: $theme\n' : ''}${pays.isNotEmpty ? '🌍 Pays: $pays\n' : ''}
  $resume

  Téléchargez l'application FourCoop pour en savoir plus !
  """;

      await Share.share(message, subject: 'Découvrez ce projet FourCoop');
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erreur lors du partage: $e')));
    }
  }

  Future<void> _editProject() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vous devez être connecté pour modifier ce projet'),
        ),
      );
      return;
    }

    try {
      final querySnapshot =
          await FirebaseFirestore.instance
              .collection('projets')
              .orderBy('createdAt', descending: true)
              .get();

      QueryDocumentSnapshot? projetDoc;
      for (final doc in querySnapshot.docs) {
        if (doc.id == widget.projetId) {
          projetDoc = doc;
          break;
        }
      }

      final projetData = projetDoc?.data() as Map<String, dynamic>;
      final createdBy = projetData['proprietaire'] as String?;

      if (createdBy != user.uid) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Seul le propriétaire peut modifier ce projet'),
          ),
        );
        return;
      }
      if (projetDoc == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Projet introuvable')));
        return;
      }

      if (!mounted) return;

      final updatedProject = await Navigator.push<Map<String, dynamic>>(
        context,
        MaterialPageRoute(
          builder:
              (_) => EditProjectPage(
                projetId: widget.projetId,
                initialData: projetData,
              ),
        ),
      );

      if (updatedProject != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Projet mis à jour avec succès')),
        );
      }
    } catch (e) {
      debugPrint('Erreur lors de la modification : $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Une erreur s'est produite lors de l'édition."),
        ),
      );
    }
  }
}
