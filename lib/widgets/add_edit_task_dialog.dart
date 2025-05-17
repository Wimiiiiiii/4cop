import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fourcoop/models/shared_task_model.dart';

class AddEditTaskDialog extends StatefulWidget {
  final String projectId;
  final SharedTask? task;
  final Function(SharedTask) onSave;

  const AddEditTaskDialog({
    Key? key,
    required this.projectId,
    this.task,
    required this.onSave,
  }) : super(key: key);

  @override
  _AddEditTaskDialogState createState() => _AddEditTaskDialogState();
}

class _AddEditTaskDialogState extends State<AddEditTaskDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late DateTime _dueDate;
  late String _status;
  late List<String> _assignedUserIds;
  late List<String> _adminUserIds;
  bool _isPublic = false;
  List<Map<String, dynamic>> _projectMembers = [];
  bool _loadingMembers = true;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.task?.title ?? '');
    _descriptionController = TextEditingController(
      text: widget.task?.description ?? '',
    );
    _dueDate = widget.task?.dueDate ?? DateTime.now().add(Duration(days: 1));
    _status = widget.task?.status ?? 'À faire';
    _assignedUserIds = widget.task?.assignedUserIds ?? [];
    _adminUserIds = widget.task?.adminUserIds ?? [];
    _isPublic = widget.task?.isPublic ?? false;
    _fetchProjectMembers();
  }

  Future<void> _fetchProjectMembers() async {
    final projectDoc =
        await FirebaseFirestore.instance
            .collection('projets')
            .doc(widget.projectId)
            .get();
    final data = projectDoc.data() as Map<String, dynamic>?;
    if (data == null) return;
    final membres = (data['membres'] as List<dynamic>);
    final List<Map<String, dynamic>> membersList = [];
    for (final email in membres) {
      final userQuery =
          await FirebaseFirestore.instance
              .collection('users')
              .where('email', isEqualTo: email)
              .get();
      if (userQuery.docs.isNotEmpty) {
        final userData = userQuery.docs.first.data();
        membersList.add({
          'uid': userQuery.docs.first.id,
          'email': userData['email'],
          'nom': userData['nom'] ?? '',
          'prenom': userData['prenom'] ?? '',
        });
      }
    }
    setState(() {
      _projectMembers = membersList;
      _loadingMembers = false;
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return AlertDialog(
      title: Text(
        widget.task == null ? 'Ajouter une tâche' : 'Modifier la tâche',
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(labelText: 'Titre *'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Veuillez entrer un titre';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(labelText: 'Description'),
                maxLines: 3,
              ),
              SizedBox(height: 16),
              ListTile(
                title: Text('Échéance'),
                subtitle: Text(_formatDate(_dueDate)),
                trailing: Icon(Icons.calendar_today),
                onTap: () => _selectDueDate(context),
              ),
              SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _status,
                items:
                    ['À faire', 'En cours', 'Terminée']
                        .map(
                          (status) => DropdownMenuItem(
                            value: status,
                            child: Text(status),
                          ),
                        )
                        .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _status = value);
                  }
                },
                decoration: InputDecoration(labelText: 'Statut'),
              ),
              SizedBox(height: 16),
              _loadingMembers
                  ? CircularProgressIndicator()
                  : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Admins de la tâche',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Wrap(
                        children:
                            _projectMembers.map((member) {
                              final isSelected = _adminUserIds.contains(
                                member['uid'],
                              );
                              return FilterChip(
                                label: Text(
                                  '${member['prenom']} ${member['nom']}',
                                ),
                                selected: isSelected,
                                onSelected: (selected) {
                                  setState(() {
                                    if (selected) {
                                      _adminUserIds.add(member['uid']);
                                    } else {
                                      _adminUserIds.remove(member['uid']);
                                    }
                                  });
                                },
                              );
                            }).toList(),
                      ),
                      SizedBox(height: 12),
                      Text(
                        'Exécutants (assignés)',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Wrap(
                        children:
                            _projectMembers.map((member) {
                              final isSelected = _assignedUserIds.contains(
                                member['uid'],
                              );
                              return FilterChip(
                                label: Text(
                                  '${member['prenom']} ${member['nom']}',
                                ),
                                selected: isSelected,
                                onSelected: (selected) {
                                  setState(() {
                                    if (selected) {
                                      _assignedUserIds.add(member['uid']);
                                    } else {
                                      _assignedUserIds.remove(member['uid']);
                                    }
                                  });
                                },
                              );
                            }).toList(),
                      ),
                      SizedBox(height: 12),
                      Row(
                        children: [
                          Switch(
                            value: _isPublic,
                            onChanged: (val) {
                              setState(() => _isPublic = val);
                            },
                          ),
                          Text(_isPublic ? 'Tâche publique' : 'Tâche privée'),
                        ],
                      ),
                    ],
                  ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Annuler'),
        ),
        ElevatedButton(onPressed: _saveTask, child: Text('Enregistrer')),
      ],
    );
  }

  Future<void> _selectDueDate(BuildContext context) async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _dueDate,
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );

    if (pickedDate != null) {
      setState(() => _dueDate = pickedDate);
    }
  }

  Future<void> _saveTask() async {
    if (_formKey.currentState!.validate()) {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      if (!_adminUserIds.contains(user.uid)) {
        _adminUserIds.add(user.uid); // Le créateur est toujours admin
      }
      final task = SharedTask(
        id: widget.task?.id ?? '',
        projectId: widget.projectId,
        title: _titleController.text,
        description: _descriptionController.text,
        dueDate: _dueDate,
        status: _status,
        creatorId: widget.task?.creatorId ?? user.uid,
        adminUserIds: _adminUserIds,
        assignedUserIds: _assignedUserIds,
        isPublic: _isPublic,
        createdAt: widget.task?.createdAt ?? DateTime.now(),
        completedAt: _status == 'Terminée' ? DateTime.now() : null,
      );
      try {
        await widget.onSave(task);
        Navigator.pop(context);
      } catch (e) {
        String message = "Erreur lors de la création de la tâche.";
        if (e.toString().contains('permission')) {
          message =
              "Vous n'avez pas l'autorisation d'ajouter une tâche à ce projet.";
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.red),
        );
      }
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
