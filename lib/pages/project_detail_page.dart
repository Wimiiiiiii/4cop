import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fourcoop/pages/EditProjetPage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class ProjectDetailPage extends StatefulWidget {
  final String projetId;

  const ProjectDetailPage({super.key, required this.projetId});

  @override
  State<ProjectDetailPage> createState() => _ProjectDetailPageState();
}

class _ProjectDetailPageState extends State<ProjectDetailPage> {
  late final DocumentReference projetRef;
  final DateFormat dateFormat = DateFormat('dd MMM yyyy', 'fr_FR');

  @override
  void initState() {
    super.initState();
    projetRef = FirebaseFirestore.instance.collection('projets').doc(widget.projetId);
  }

  Future<void> _launchContact(String contactInfo) async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: contactInfo,
    );
    if (await canLaunchUrl(emailUri)) {
      await launchUrl(emailUri);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Impossible d\'ouvrir $contactInfo')),
      );
    }
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Détails du projet',
          style: GoogleFonts.interTight(fontWeight: FontWeight.bold),
        ),
        actions: [
          StreamBuilder<DocumentSnapshot>(
            stream: projetRef.snapshots(),
            builder: (context, snapshot) {
              final isFavorite = (snapshot.data?.data() as Map<String, dynamic>?)?['isFavorite'] ?? false;
              return IconButton(
                icon: Icon(
                  isFavorite ? Icons.favorite : Icons.favorite_border,
                  color: isFavorite ? Colors.red : null,
                ),
                onPressed: () => _toggleFavorite(isFavorite),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () => _shareProject(),
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: projetRef.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return Center(
              child: Text(
                'Projet non trouvé',
                style: GoogleFonts.inter(),
              ),
            );
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
          final imageUrl = data['imageUrl'] as String?;
          final contact = data['contact'] as String?;

          return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (imageUrl != null && imageUrl.isNotEmpty)
                _buildProjectImage(imageUrl, theme),
              if (imageUrl == null || imageUrl.isEmpty)
                _buildImagePlaceholder(theme),

              const SizedBox(height: 24),

              Text(
                data['titre'] ?? 'Titre non spécifié',
                style: GoogleFonts.interTight(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),

              _buildMetadataChips(data, createdAt, theme),
              const SizedBox(height: 16),

              _buildSectionTitle('Résumé'),
              const SizedBox(height: 8),
              Text(
                data['resume'] ?? 'Aucun résumé fourni',
                style: GoogleFonts.inter(fontSize: 15, height: 1.5),
              ),

              const SizedBox(height: 24),
              _buildSectionTitle('Description'),
              const SizedBox(height: 8),
              Text(
                data['description'] ?? 'Aucune description disponible',
                style: GoogleFonts.inter(fontSize: 15, height: 1.5),
              ),

              if (data['duree'] != null) ...[
                const SizedBox(height: 24),
                _buildSectionTitle('Durée'),
                const SizedBox(height: 8),
                Text(
                  data['duree'],
                  style: GoogleFonts.inter(fontSize: 15),
                ),
              ],

              if (contact != null && contact.isNotEmpty) ...[
                const SizedBox(height: 24),
                _buildSectionTitle('Contact'),
                const SizedBox(height: 8),
                _buildContactButton(contact, theme),
              ],

              const SizedBox(height: 32),
            ],
          ),
        );

        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _editProject(),
        backgroundColor: theme.colorScheme.primary,
        child: const Icon(Icons.edit, color: Colors.white),
      ),
    );
  }

  Widget _buildProjectImage(String imageUrl, ThemeData theme) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.network(
        imageUrl,
        width: double.infinity,
        height: 220,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildImagePlaceholder(theme),
      ),
    );
  }

  Widget _buildImagePlaceholder(ThemeData theme) {
    return Container(
      width: double.infinity,
      height: 220,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
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

  Widget _buildMetadataChips(Map<String, dynamic> data, DateTime? createdAt, ThemeData theme) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if ((data['theme'] as String?)?.isNotEmpty ?? false)
          Chip(
            label: Text(data['theme'] as String),
            backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
          ),
        if (data['pays'] != null)
          Chip(
            label: Text(data['pays']),
            backgroundColor: theme.colorScheme.secondary.withOpacity(0.1),
          ),
        if (createdAt != null)
          Chip(
            label: Text(dateFormat.format(createdAt)),
            backgroundColor: theme.colorScheme.surfaceVariant,
          ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.interTight(
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildContactButton(String contact, ThemeData theme) {
    return InkWell(
      onTap: () => _launchContact(contact),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceVariant,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.email, color: theme.colorScheme.primary),
            const SizedBox(width: 12),
            Text(
              contact,
              style: GoogleFonts.inter(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _shareProject() async {
    // Implémentez le partage selon vos besoins
    // Ex: utiliser le package share_plus
  }

 Future<void> _editProject() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Vous devez être connecté pour modifier ce projet')),
    );
    return;
  }

  try {
    final querySnapshot = await FirebaseFirestore.instance
        .collection('projets')
        .where('membres', arrayContains: user.email)
        .orderBy('createdAt', descending: true)
        .get();

    QueryDocumentSnapshot? projetDoc;
    for (final doc in querySnapshot.docs) {
      if (doc.id == widget.projetId) {
        projetDoc = doc;
        break;
      }
    }

    if (projetDoc == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Projet introuvable')),
      );
      return;
    }

    final projetData = projetDoc.data() as Map<String, dynamic>;
    final createdBy = projetData['createdBy'] as String?;

    if (createdBy != user.email) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seul le propriétaire peut modifier ce projet')),
      );
      return;
    }

    if (!mounted) return;

    final updatedProject = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => EditProjectPage(
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
      const SnackBar(content: Text("Une erreur s'est produite lors de l'édition.")),
    );
  }
}

}