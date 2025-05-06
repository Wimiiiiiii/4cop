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
      drawer: DrawerMenu(),
      body: Column(
        children: [
          // Search and Filter Section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: Offset(0, 4),
                ),
              ],
            ),
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
                AnimatedCrossFade(
                  duration: const Duration(milliseconds: 300),
                  crossFadeState: isFilterExpanded 
                      ? CrossFadeState.showFirst 
                      : CrossFadeState.showSecond,
                  firstChild: Column(
                    children: [
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                color: theme.colorScheme.surfaceVariant,
                              ),
                              child: DropdownButtonFormField<String>(
                                value: selectedTheme,
                                decoration: InputDecoration(
                                  labelText: 'Thème',
                                  labelStyle: GoogleFonts.inter(),
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(horizontal: 16),
                                ),
                                dropdownColor: theme.colorScheme.surfaceVariant,
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
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                color: theme.colorScheme.surfaceVariant,
                              ),
                              child: DropdownButtonFormField<String>(
                                value: selectedCountry,
                                decoration: InputDecoration(
                                  labelText: 'Pays',
                                  labelStyle: GoogleFonts.inter(),
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(horizontal: 16),
                                ),
                                dropdownColor: theme.colorScheme.surfaceVariant,
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
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            FilterChip(
                              label: 'Plus récents',
                              selected: sortOption == 'date-desc',
                              onSelected: () => setState(() => sortOption = 'date-desc'),
                            ),
                            const SizedBox(width: 8),
                            FilterChip(
                              label: 'Plus anciens',
                              selected: sortOption == 'date-asc',
                              onSelected: () => setState(() => sortOption = 'date-asc'),
                            ),
                            const SizedBox(width: 8),
                            FilterChip(
                              label: 'A-Z',
                              selected: sortOption == 'title-asc',
                              onSelected: () => setState(() => sortOption = 'title-asc'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  secondChild: Container(),
                ),
              ],
            ),
          ),

          // Projects List
          Expanded(
            child: Container(
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
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.search_off,
                            size: 48,
                            color: theme.colorScheme.onSurface.withOpacity(0.3),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Aucun projet trouvé',
                            style: GoogleFonts.inter(
                              color: theme.colorScheme.onSurface.withOpacity(0.6),
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  final projets = snapshot.data!.docs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final title = data['titre']?.toString().toLowerCase() ?? '';
                    final matchesSearch = title.contains(searchQuery);
                    final matchesTheme = selectedTheme == null ||
                        (data['theme']?.toString() == selectedTheme);
                    final matchesCountry = selectedCountry == null ||
                        (data['pays']?.toString() == selectedCountry);

                    return matchesSearch && matchesTheme && matchesCountry;
                  }).toList();

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    itemCount: projets.length,
                    itemBuilder: (context, index) {
                      final projet = projets[index];
                      final data = projet.data() as Map<String, dynamic>;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 10,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Material(
                          borderRadius: BorderRadius.circular(16),
                          color: theme.colorScheme.surface,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
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
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
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
                                        child: Icon(
                                          Icons.image_not_supported_outlined,
                                          color: theme.colorScheme.onSurface.withOpacity(0.3),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
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
                                        const SizedBox(height: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: theme.colorScheme.primary.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            data['theme'] ?? 'Non spécifié',
                                            style: GoogleFonts.inter(
                                              color: theme.colorScheme.primary,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          data['resume'] ?? 'Pas de résumé',
                                          style: GoogleFonts.inter(
                                            fontSize: 13,
                                            color: theme.colorScheme.onSurface.withOpacity(0.8),
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    Icons.chevron_right,
                                    color: theme.colorScheme.onSurface.withOpacity(0.3),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onSelected;

  const FilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ChoiceChip(
      label: Text(label, style: GoogleFonts.inter()),
      selected: selected,
      onSelected: (_) => onSelected(),
      labelPadding: const EdgeInsets.symmetric(horizontal: 12),
      backgroundColor: theme.colorScheme.surfaceVariant,
      selectedColor: theme.colorScheme.primaryContainer,
      labelStyle: TextStyle(
        color: selected 
            ? theme.colorScheme.onPrimaryContainer 
            : theme.colorScheme.onSurface,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }
}