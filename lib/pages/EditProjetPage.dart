import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';

class EditProjectPage extends StatefulWidget {
  final String projetId;
  final Map<String, dynamic> initialData;

  const EditProjectPage({
    super.key,
    required this.projetId,
    required this.initialData,
  });

  @override
  State<EditProjectPage> createState() => _EditProjectPageState();
}

class _EditProjectPageState extends State<EditProjectPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titreController;
  late TextEditingController _resumeController;
  late TextEditingController _descriptionController;
  late TextEditingController _themeController;
  late TextEditingController _paysController;
  late TextEditingController _dureeController;
  late TextEditingController _newMemberController;
  late TextEditingController _statutController;
  final List<String> _statutOptions = [
    'En attente',
    'En cours',
    'Terminé',
    'Suspendu',
  ];

  List<String> _membres = [];
  bool _isLoading = false;
  List<String> _themeOptions = [];
  List<String> _paysOptions = [];
  final List<String> _dureeOptions = [
    "Moins d'un mois",
    ...List.generate(12, (index) => '${index + 1} mois'),
    "1 an",
    "Autre",
  ];
  bool _isLoadingFilters = true;
  List<Map<String, dynamic>> _userSuggestions = [];
  String _searchMember = '';
  bool _isSearchingUser = false;

  @override
  void initState() {
    super.initState();
    _titreController = TextEditingController(
      text: widget.initialData['titre'] ?? '',
    );
    _statutController = TextEditingController(
      text: widget.initialData['statut'] ?? 'En attente',
    );

    _resumeController = TextEditingController(
      text: widget.initialData['resume'] ?? '',
    );
    _descriptionController = TextEditingController(
      text: widget.initialData['description'] ?? '',
    );
    _themeController = TextEditingController(
      text: widget.initialData['theme'] ?? '',
    );
    _paysController = TextEditingController(
      text: widget.initialData['pays'] ?? '',
    );
    _dureeController = TextEditingController(
      text: widget.initialData['duree'] ?? '',
    );
    _newMemberController = TextEditingController();
    _membres = List<String>.from(widget.initialData['membres'] ?? []);
    _loadThemesAndCountries();
  }

  @override
  void dispose() {
    _titreController.dispose();
    _resumeController.dispose();
    _descriptionController.dispose();
    _themeController.dispose();
    _paysController.dispose();
    _dureeController.dispose();
    _newMemberController.dispose();
    _statutController.dispose();

    super.dispose();
  }

  Future<void> _saveProject() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await FirebaseFirestore.instance
          .collection('projets')
          .doc(widget.projetId)
          .update({
            'titre': _titreController.text,
            'resume': _resumeController.text,
            'statut': _statutController.text,
            'description': _descriptionController.text,
            'theme': _themeController.text,
            'pays': _paysController.text,
            'duree': _dureeController.text,
            'membres': _membres,
            'updatedAt': FieldValue.serverTimestamp(),
          });

      Navigator.pop(context, {
        'status': 'success',
        'message': 'Projet mis à jour avec succès',
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de la mise à jour: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _addMember() async {
    final email = _newMemberController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Veuillez entrer un email valide',
            style: GoogleFonts.inter(),
          ),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }

    if (_membres.contains(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Ce membre est déjà dans la liste',
            style: GoogleFonts.inter(),
          ),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }

    final userSnap =
        await FirebaseFirestore.instance
            .collection('users')
            .where('email', isEqualTo: email)
            .limit(1)
            .get();

    if (userSnap.docs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Aucun utilisateur trouvé avec cet email',
            style: GoogleFonts.inter(),
          ),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }

    setState(() {
      _membres.add(email);
      _newMemberController.clear();
      _userSuggestions = [];
    });
  }

  void _removeMember(String email) async {
    setState(() {
      _membres.remove(email);
    });
    // Retirer le membre des groupes de discussion liés à ce projet
    final chats =
        await FirebaseFirestore.instance
            .collection('chats')
            .where('projetId', isEqualTo: widget.projetId)
            .get();
    for (final chat in chats.docs) {
      final participants = List.from(chat['participants'] ?? []);
      if (participants.contains(email)) {
        participants.remove(email);
        await chat.reference.update({'participants': participants});
      }
    }
  }

  Future<void> _loadThemesAndCountries() async {
    try {
      final themeSnap =
          await FirebaseFirestore.instance.collection('themes').get();
      final paysSnap =
          await FirebaseFirestore.instance.collection('pays').get();

      setState(() {
        _themeOptions =
            themeSnap.docs.map((doc) => doc['nom'].toString()).toSet().toList()
              ..sort();
        _paysOptions =
            paysSnap.docs.map((doc) => doc['nom'].toString()).toSet().toList()
              ..sort();
        _isLoadingFilters = false;
      });
    } catch (e) {
      setState(() => _isLoadingFilters = false);
    }
  }

  Future<void> _searchUsers(String query) async {
    setState(() {
      _isSearchingUser = true;
      _userSuggestions = [];
    });

    if (query.trim().isEmpty) {
      setState(() {
        _isSearchingUser = false;
        _userSuggestions = [];
      });
      return;
    }

    final result = await FirebaseFirestore.instance.collection('users').get();

    final filtered =
        result.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final email = (data['email'] ?? '').toString().toLowerCase();
          final nom = (data['nom'] ?? '').toString().toLowerCase();
          final prenom = (data['prenom'] ?? '').toString().toLowerCase();
          final searchLower = query.toLowerCase();
          return email.contains(searchLower) ||
              nom.contains(searchLower) ||
              prenom.contains(searchLower);
        }).toList();

    setState(() {
      _userSuggestions =
          filtered.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return {
              'email': data['email'],
              'nom': data['nom'] ?? '',
              'prenom': data['prenom'] ?? '',
            };
          }).toList();
      _isSearchingUser = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Modifier le projet',
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
              stops: const [0, 0.5, 1],
              begin: AlignmentDirectional(-1, -1),
              end: AlignmentDirectional(1, 1),
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _isLoading ? null : _saveProject,
          ),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      theme.colorScheme.background.withOpacity(0.3),
                      theme.colorScheme.background,
                    ],
                    stops: const [0, 0.3],
                  ),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextFormField(
                          controller: _titreController,
                          decoration: InputDecoration(
                            labelText: 'Titre*',
                            labelStyle: GoogleFonts.inter(),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: theme.colorScheme.surface,
                          ),
                          style: GoogleFonts.inter(),
                          validator:
                              (value) =>
                                  value!.isEmpty
                                      ? 'Ce champ est obligatoire'
                                      : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _resumeController,
                          decoration: InputDecoration(
                            labelText: 'Résumé',
                            labelStyle: GoogleFonts.inter(),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: theme.colorScheme.surface,
                          ),
                          style: GoogleFonts.inter(),
                          maxLines: 3,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _descriptionController,
                          decoration: InputDecoration(
                            labelText: 'Description',
                            labelStyle: GoogleFonts.inter(),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: theme.colorScheme.surface,
                          ),
                          style: GoogleFonts.inter(),
                          maxLines: 5,
                        ),
                        const SizedBox(height: 16),
                        _isLoadingFilters
                            ? Center(child: CircularProgressIndicator())
                            : Column(
                              children: [
                                DropdownButtonFormField<String>(
                                  value:
                                      _themeController.text.isNotEmpty
                                          ? _themeController.text
                                          : null,
                                  items:
                                      _themeOptions
                                          .map(
                                            (theme) => DropdownMenuItem(
                                              value: theme,
                                              child: Text(
                                                theme,
                                                style: GoogleFonts.inter(),
                                              ),
                                            ),
                                          )
                                          .toList(),
                                  onChanged: (val) {
                                    setState(
                                      () => _themeController.text = val ?? '',
                                    );
                                  },
                                  decoration: InputDecoration(
                                    labelText: 'Thème',
                                    labelStyle: GoogleFonts.inter(),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    filled: true,
                                    fillColor: theme.colorScheme.surface,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                DropdownButtonFormField<String>(
                                  value:
                                      _paysController.text.isNotEmpty
                                          ? _paysController.text
                                          : null,
                                  items:
                                      _paysOptions
                                          .map(
                                            (pays) => DropdownMenuItem(
                                              value: pays,
                                              child: Text(
                                                pays,
                                                style: GoogleFonts.inter(),
                                              ),
                                            ),
                                          )
                                          .toList(),
                                  onChanged: (val) {
                                    setState(
                                      () => _paysController.text = val ?? '',
                                    );
                                  },
                                  decoration: InputDecoration(
                                    labelText: 'Pays',
                                    labelStyle: GoogleFonts.inter(),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    filled: true,
                                    fillColor: theme.colorScheme.surface,
                                  ),
                                ),
                              ],
                            ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value:
                              _dureeController.text.isNotEmpty
                                  ? _dureeController.text
                                  : null,
                          items:
                              _dureeOptions
                                  .map(
                                    (duree) => DropdownMenuItem(
                                      value: duree,
                                      child: Text(
                                        duree,
                                        style: GoogleFonts.inter(),
                                      ),
                                    ),
                                  )
                                  .toList(),
                          onChanged: (val) {
                            setState(() => _dureeController.text = val ?? '');
                          },
                          decoration: InputDecoration(
                            labelText: 'Durée',
                            labelStyle: GoogleFonts.inter(),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: theme.colorScheme.surface,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Membres du projet',
                          style: GoogleFonts.interTight(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Ajouter un membre par email ou nom',
                          style: GoogleFonts.interTight(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _newMemberController,
                          decoration: InputDecoration(
                            labelText: 'Rechercher un membre',
                            labelStyle: GoogleFonts.inter(),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: theme.colorScheme.surface,
                            suffixIcon:
                                _isSearchingUser
                                    ? Padding(
                                      padding: const EdgeInsets.all(12.0),
                                      child: SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      ),
                                    )
                                    : Icon(
                                      Icons.search,
                                      color: theme.colorScheme.primary,
                                    ),
                          ),
                          style: GoogleFonts.inter(),
                          onChanged: (val) => _searchUsers(val),
                        ),
                        if (_userSuggestions.isNotEmpty)
                          Container(
                            constraints: BoxConstraints(maxHeight: 200),
                            child: ListView.builder(
                              shrinkWrap: true,
                              itemCount: _userSuggestions.length,
                              itemBuilder: (context, index) {
                                final user = _userSuggestions[index];
                                final email = user['email'];
                                final nom = user['nom'];
                                final prenom = user['prenom'];
                                final alreadyAdded = _membres.contains(email);
                                return ListTile(
                                  title: Text(
                                    '$prenom $nom',
                                    style: GoogleFonts.inter(),
                                  ),
                                  subtitle: Text(
                                    email,
                                    style: GoogleFonts.inter(fontSize: 13),
                                  ),
                                  trailing:
                                      alreadyAdded
                                          ? Icon(
                                            Icons.check,
                                            color: theme.colorScheme.primary,
                                          )
                                          : IconButton(
                                            icon: Icon(
                                              Icons.add,
                                              color: theme.colorScheme.primary,
                                            ),
                                            onPressed: () {
                                              if (!alreadyAdded) {
                                                setState(() {
                                                  _membres.add(email);
                                                  _newMemberController.clear();
                                                  _userSuggestions = [];
                                                });
                                              }
                                            },
                                          ),
                                );
                              },
                            ),
                          ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: _statutController.text,
                          items:
                              _statutOptions.map((String statut) {
                                return DropdownMenuItem<String>(
                                  value: statut,
                                  child: Text(
                                    statut,
                                    style: GoogleFonts.inter(),
                                  ),
                                );
                              }).toSet().toList(),
                          onChanged: (value) {
                            setState(() {
                              _statutController.text = value!;
                            });
                          },
                          decoration: InputDecoration(
                            labelText: 'Statut du projet*',
                            labelStyle: GoogleFonts.inter(),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: theme.colorScheme.surface,
                          ),
                          validator:
                              (value) =>
                                  value == null || value.isEmpty
                                      ? 'Ce champ est obligatoire'
                                      : null,
                        ),

                        const SizedBox(height: 8),
                        ..._membres.map(
                          (email) => Card(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ListTile(
                              title: Text(email, style: GoogleFonts.inter()),
                              trailing: IconButton(
                                icon: const Icon(Icons.remove_circle_outline),
                                onPressed: () => _removeMember(email),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _saveProject,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: theme.colorScheme.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              'Enregistrer les modifications',
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
    );
  }
}
