import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/drawer_menu.dart';
import 'project_detail_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String searchQuery = '';
  String? selectedTheme;
  String? selectedCountry;
  String sortOption = 'date-desc';
  bool isFilterExpanded = false;

  final List<String> themes = [
    'Éducation',
    'Santé',
    'Environnement',
    'Développement',
    'Technologie'
  ];
  final List<String> countries = [
    'France',
    'Canada',
    'Sénégal',
    'Maroc',
    'Côte d\'Ivoire'
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Projets de Coopération',
          style: GoogleFonts.interTight(
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_alt),
            onPressed: () => setState(() => isFilterExpanded = !isFilterExpanded),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() {
              searchQuery = '';
              selectedTheme = null;
              selectedCountry = null;
            }),
          ),
        ],
      ),
      drawer:  DrawerMenu(),
      body: Column(
        children: [
          // Search and Filter Section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              children: [
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Rechercher un projet...',
                    hintStyle: GoogleFonts.inter(),
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: theme.colorScheme.surfaceVariant,
                    contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                  ),
                  onChanged: (value) => setState(() => searchQuery = value.toLowerCase()),
                ),
                if (isFilterExpanded) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                  Expanded(
                  child: DropdownButtonFormField<String>(
                    value: selectedTheme,
                    decoration: InputDecoration(
                      labelText: 'Thème',
                      labelStyle: GoogleFonts.inter(),
  border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('Tous les thèmes'),
                        ),
                        ...themes.map((theme) => DropdownMenuItem(
                          value: theme,
                          child: Text(theme),
                        )),
                      ],
                      onChanged: (value) => setState(() => selectedTheme = value),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: selectedCountry,
                      decoration: InputDecoration(
                        labelText: 'Pays',
                        labelStyle: GoogleFonts.inter(),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: Text('Tous les pays'),
                          ),
                          ...countries.map((country) => DropdownMenuItem(
                            value: country,
                            child: Text(country),
                          )),
                        ],
                        onChanged: (value) => setState(() => selectedCountry = value),
                      ),
                    ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: Text('Plus récents', style: GoogleFonts.inter()),
                          selected: sortOption == 'date-desc',
                          onSelected: (_) => setState(() => sortOption = 'date-desc'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ChoiceChip(
                          label: Text('Plus anciens', style: GoogleFonts.inter()),
                          selected: sortOption == 'date-asc',
                          onSelected: (_) => setState(() => sortOption = 'date-asc'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ChoiceChip(
                          label: Text('A-Z', style: GoogleFonts.inter()),
                          selected: sortOption == 'title-asc',
                          onSelected: (_) => setState(() => sortOption = 'title-asc'),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // Projects List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('projets')
                  .orderBy(
                sortOption == 'date-asc' ? 'createdAt' :
                sortOption == 'title-asc' ? 'titre' : 'createdAt',
                descending: sortOption == 'date-desc',
              )
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Erreur de chargement',
                      style: GoogleFonts.inter(),
                    ),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Text(
                      'Aucun projet trouvé',
                      style: GoogleFonts.inter(),
                    ),
                  );
                }

                final projets = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;

                  // Search filter
                  final title = data['titre']?.toString().toLowerCase() ?? '';
                  final matchesSearch = title.contains(searchQuery);

                  // Theme filter
                  final matchesTheme = selectedTheme == null ||
                      (data['theme']?.toString() == selectedTheme);

                  // Country filter
                  final matchesCountry = selectedCountry == null ||
                      (data['pays']?.toString() == selectedCountry);

                  return matchesSearch && matchesTheme && matchesCountry;
                }).toList();

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: projets.length,
                  itemBuilder: (context, index) {
                    final projet = projets[index];
                    final data = projet.data() as Map<String, dynamic>;

                    return Card(
                      elevation: 0,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
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
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  data['imageUrl'] ??
                                      'https://via.placeholder.com/80x80.png?text=Projet',
                                  width: 80,
                                  height: 80,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    width: 80,
                                    height: 80,
                                    color: theme.colorScheme.surfaceVariant,
                                    child: const Icon(Icons.broken_image),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      data['titre'] ?? 'Sans titre',
                                      style: GoogleFonts.interTight(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      data['theme'] ?? 'Non spécifié',
                                      style: GoogleFonts.inter(
                                        color: theme.colorScheme.primary,
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      data['resume'] ?? 'Pas de résumé',
                                      style: GoogleFonts.inter(
                                        fontSize: 13,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.chevron_right,
                                color: theme.colorScheme.onSurface.withOpacity(0.5),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}