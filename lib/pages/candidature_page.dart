import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class CandidaturesPage extends StatelessWidget {
  final String projetId;

  const CandidaturesPage({super.key, required this.projetId});

  Future<void> _updateCandidatureStatus({
    required String candidatureId,
    required String candidatId,
    required String statut,
  }) async {
    final projetRef = FirebaseFirestore.instance.collection('projets').doc(projetId);
    final candidatureRef = projetRef.collection('candidatures').doc(candidatureId);

    await candidatureRef.update({'status': statut});

    if (statut == 'validé') {
    final membreRef = projetRef.collection('membres').doc(candidatId);

    final userDoc = await FirebaseFirestore.instance.collection('users').doc(candidatId).get();
    final email = userDoc.data()?['email'];

    await membreRef.set({
      'uid': candidatId,
      'joinedAt': FieldValue.serverTimestamp(),
      'role': 'membre',
      'email': email, 
    });

    if (email != null) {
      await projetRef.update({
        'membres': FieldValue.arrayUnion([email])
      });
    }
  }

  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Candidatures'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('projets')
            .doc(projetId)
            .collection('candidatures')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return const Center(child: Text('Aucune candidature reçue.'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              final candidatId = doc.id;
              final statut = data['status'] ?? 'en attente';

return FutureBuilder<DocumentSnapshot>(
  future: FirebaseFirestore.instance.collection('users').doc(candidatId).get(),
  builder: (context, userSnapshot) {
    if (userSnapshot.connectionState == ConnectionState.waiting) {
      return const Center(child: CircularProgressIndicator());
    }

    final userData = userSnapshot.data?.data() as Map<String, dynamic>?;

    final nom = userData?['nom'] ?? userData?['name'] ?? 'Nom inconnu';
    final email = userData?['email'] ?? 'Email inconnu';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(nom, style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 16)),
          const SizedBox(height: 4),
          Text(email, style: GoogleFonts.inter(fontSize: 14, color: Colors.grey[700])),
          const SizedBox(height: 6),
          Text('Statut: $statut', style: GoogleFonts.inter(fontSize: 14, color: Colors.grey[600])),
          const SizedBox(height: 12),
          if (statut == 'en attente') Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.check),
                  label: const Text('Valider'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () {
                    _updateCandidatureStatus(
                      candidatureId: doc.id,
                      candidatId: candidatId,
                      statut: 'validé',
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.close),
                  label: const Text('Refuser'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () {
                    _updateCandidatureStatus(
                      candidatureId: doc.id,
                      candidatId: candidatId,
                      statut: 'refusé',
                    );
                  },
                ),
              ),
            ],
          )
          else Text(
            statut == 'validé'
                ? 'Candidat déjà accepté.'
                : 'Candidature refusée.',
            style: GoogleFonts.inter(
              color: statut == 'validé' ? Colors.green : Colors.red,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  },
);

            },
          );
        },
      ),
    );
  }
}

