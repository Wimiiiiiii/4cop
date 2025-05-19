import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/drawer_menu.dart';
import 'project_detail_page.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
  List<String> themes = [];
  List<String> countries = [];
  bool isLoadingFilters = true;
  bool showFavoritesOnly = false;
  List<String> favoriteProjects = [];

  @override
  void initState() {
    super.initState();
    _loadFilterData();
    _loadFavorites();
  }

  Future<void> _loadFilterData() async {
    final countrySnapshot =
        await FirebaseFirestore.instance.collection('pays').get();
    final themeSnapshot =
        await FirebaseFirestore.instance.collection('themes').get();
    print(themeSnapshot);

    setState(() {
      themes =
          themeSnapshot.docs
              .map((doc) => doc['nom']?.toString() ?? '')
              .toList();

      countries =
          countrySnapshot.docs
              .map((doc) => doc['nom']?.toString() ?? '')
              .toSet()
              .toList();

      isLoadingFilters = false;
    });
  }

  Future<void> _loadFavorites() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userDoc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();

      setState(() {
        favoriteProjects = List<String>.from(userDoc.data()?['favoris'] ?? []);
      });
    }
  }

  Future<void> _toggleFavorite(String projectId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() {
      if (favoriteProjects.contains(projectId)) {
        favoriteProjects.remove(projectId);
      } else {
        favoriteProjects.add(projectId);
      }
    });

    await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
      'favoris': favoriteProjects,
    });
  }

  bool _matchesSearchQuery(Map<String, dynamic> data, String query) {
    if (query.isEmpty) return true;
    final searchableFields = [
      data['titre']?.toString().toLowerCase() ?? '',
      data['resume']?.toString().toLowerCase() ?? '',
      data['description']?.toString().toLowerCase() ?? '',
      data['theme']?.toString().toLowerCase() ?? '',
      data['pays']?.toString().toLowerCase() ?? '',
      data['competences']?.toString().toLowerCase() ?? '',
    ];
    return searchableFields.any((field) => field.contains(query));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (isLoadingFilters) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

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
          builder:
              (context) => IconButton(
                icon: const Icon(Icons.menu),
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              showFavoritesOnly ? Icons.star : Icons.star_border,
              color: showFavoritesOnly ? Colors.amber : Colors.white,
            ),
            onPressed: () {
              setState(() {
                showFavoritesOnly = !showFavoritesOnly;
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.filter_alt),
            onPressed:
                () => setState(() => isFilterExpanded = !isFilterExpanded),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed:
                () => setState(() {
                  searchQuery = '';
                  selectedTheme = null;
                  selectedCountry = null;
                  showFavoritesOnly = false;
                }),
          ),
        ],
      ),
      drawer: DrawerMenu(),
      body: Column(
        children: [
          // Search and Filters
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Rechercher un projet...',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: theme.colorScheme.surfaceVariant,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged:
                      (value) =>
                          setState(() => searchQuery = value.toLowerCase()),
                ),
                AnimatedCrossFade(
                  duration: const Duration(milliseconds: 300),
                  crossFadeState:
                      isFilterExpanded
                          ? CrossFadeState.showFirst
                          : CrossFadeState.showSecond,
                  firstChild: Column(
                    children: [
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: selectedTheme,
                              isExpanded: true,
                              decoration: InputDecoration(
                                labelText: 'Thème',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              items: [
                                const DropdownMenuItem(
                                  value: null,
                                  child: Text('Tous les thèmes'),
                                ),
                                ...themes.map(
                                  (theme) => DropdownMenuItem(
                                    value: theme,
                                    child: Text(theme),
                                  ),
                                ),
                              ],
                              onChanged:
                                  (value) =>
                                      setState(() => selectedTheme = value),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: selectedCountry,
                              isExpanded: true,
                              decoration: InputDecoration(
                                labelText: 'Pays',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              items: [
                                const DropdownMenuItem(
                                  value: null,
                                  child: Text('Tous les pays'),
                                ),
                                ...countries.map(
                                  (country) => DropdownMenuItem(
                                    value: country,
                                    child: Text(country),
                                  ),
                                ),
                              ],
                              onChanged:
                                  (value) =>
                                      setState(() => selectedCountry = value),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          CustomFilterChip(
                            label: 'Plus récents',
                            selected: sortOption == 'date-desc',
                            onSelected:
                                () => setState(() => sortOption = 'date-desc'),
                          ),
                          const SizedBox(width: 8),
                          CustomFilterChip(
                            label: 'Plus anciens',
                            selected: sortOption == 'date-asc',
                            onSelected:
                                () => setState(() => sortOption = 'date-asc'),
                          ),
                          const SizedBox(width: 8),
                          CustomFilterChip(
                            label: 'A-Z',
                            selected: sortOption == 'title-asc',
                            onSelected:
                                () => setState(() => sortOption = 'title-asc'),
                          ),
                        ],
                      ),
                    ],
                  ),
                  secondChild: Container(),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream:
                  FirebaseFirestore.instance
                      .collection('projets')
                      .orderBy(
                        sortOption == 'title-asc' ? 'titre' : 'createdAt',
                        descending: sortOption == 'date-desc',
                      )
                      .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(
                    child: Text('Erreur de chargement des projets'),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final projets =
                    snapshot.data!.docs.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final matchesSearch = _matchesSearchQuery(
                        data,
                        searchQuery,
                      );
                      final matchesTheme =
                          selectedTheme == null ||
                          data['theme'] == selectedTheme;
                      final matchesCountry =
                          selectedCountry == null ||
                          data['pays'] == selectedCountry;
                      final matchesFavorites =
                          !showFavoritesOnly ||
                          favoriteProjects.contains(doc.id);
                      final statut = (data['statut'] ?? '').toString().trim();
                      final isVisible =
                          statut != 'Terminé' && statut != 'Suspendu';
                      return matchesSearch &&
                          matchesTheme &&
                          matchesCountry &&
                          matchesFavorites &&
                          isVisible;
                    }).toList();

                if (projets.isEmpty) {
                  return const Center(child: Text('Aucun projet trouvé'));
                }

                return ListView.builder(
                  itemCount: projets.length,
                  padding: const EdgeInsets.all(16),
                  itemBuilder: (context, index) {
                    final data = projets[index].data() as Map<String, dynamic>;

                    return Card(
                      elevation: 3,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      margin: const EdgeInsets.only(bottom: 16),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (context) => ProjectDetailPage(
                                    projetId: projets[index].id,
                                  ),
                            ),
                          );
                        },
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceVariant,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: data['imageUrl'] != null
                                ? Image.network(
                                    data['imageUrl']!,
                                    width: 80,
                                    height: 80,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => _buildImagePlaceholder(theme),
                                  )
                                : _buildImagePlaceholder(theme),
                          ),
                        ),
                        title: Text(
                          data['titre'] ?? 'Sans titre',
                          style: GoogleFonts.interTight(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(
                              data['resume'] ?? '',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text('Thème : ${data['theme'] ?? 'Non spécifié'}'),
                            Text('Pays : ${data['pays'] ?? 'Non spécifié'}'),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(
                                favoriteProjects.contains(projets[index].id)
                                    ? Icons.star
                                    : Icons.star_border,
                                color:
                                    favoriteProjects.contains(projets[index].id)
                                        ? Colors.amber
                                        : theme.colorScheme.onSurface
                                            .withOpacity(0.6),
                              ),
                              onPressed:
                                  () => _toggleFavorite(projets[index].id),
                            ),
                            const Icon(Icons.chevron_right),
                          ],
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

  Widget _buildImagePlaceholder(ThemeData theme) {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.image_outlined,
            size: 24,
            color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
          ),
          const SizedBox(height: 4),
          Text(
            'Photo',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }
}

class CustomFilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onSelected;

  const CustomFilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
    );
  }
}
