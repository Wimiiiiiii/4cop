import 'package:flutter/material.dart';
import 'package:fourcoop/models/shared_task_model.dart';
import 'package:fourcoop/repository/shared_task_repository.dart';
import 'package:fourcoop/widgets/task_item.dart';
import 'package:fourcoop/widgets/add_edit_task_dialog.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SharedTasksPage extends StatefulWidget {
  final String projectId;
  final String projectName;

  const SharedTasksPage({
    Key? key,
    required this.projectId,
    required this.projectName,
  }) : super(key: key);

  @override
  _SharedTasksPageState createState() => _SharedTasksPageState();
}

class _SharedTasksPageState extends State<SharedTasksPage> {
  late SharedTaskRepository _taskRepository;
  String _filterStatus = 'Tous';

  @override
  void initState() {
    super.initState();
    _taskRepository = SharedTaskRepository();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Tâches - ${widget.projectName}',
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
            icon: Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
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
            stops: const [0, 0.3],
          ),
        ),
        child: StreamBuilder<List<SharedTask>>(
          stream: _taskRepository.getTasksByProject(widget.projectId),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 48,
                      color: theme.colorScheme.error,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Erreur: ${snapshot.error}',
                      style: GoogleFonts.inter(
                        color: theme.colorScheme.onSurface,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final tasks = snapshot.data ?? [];
            final filteredTasks =
                _filterStatus == 'Tous'
                    ? tasks
                    : tasks
                        .where((task) => task.status == _filterStatus)
                        .toList();

            if (filteredTasks.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.task,
                      size: 48,
                      color: theme.colorScheme.onSurface.withOpacity(0.3),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Aucune tâche ${_filterStatus.toLowerCase()}',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Appuyez sur + pour en créer une',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: theme.colorScheme.onSurface.withOpacity(0.4),
                      ),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: filteredTasks.length,
              itemBuilder: (context, index) {
                final task = filteredTasks[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: TaskItem(
                    task: task,
                    onStatusChanged:
                        (newStatus) => _taskRepository.updateTaskStatus(
                          task.id,
                          newStatus,
                        ),
                    onEdit: () => _showEditTaskDialog(task),
                    onDelete: () => _showDeleteDialog(task),
                  ),
                );
              },
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddTaskDialog,
        child: const Icon(Icons.add),
        backgroundColor: theme.colorScheme.primary,
      ),
    );
  }

  void _showFilterDialog() {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(
              'Filtrer par statut',
              style: GoogleFonts.interTight(fontWeight: FontWeight.bold),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children:
                  ['Tous', 'À faire', 'En cours', 'Terminée']
                      .map(
                        (status) => RadioListTile<String>(
                          title: Text(status, style: GoogleFonts.inter()),
                          value: status,
                          groupValue: _filterStatus,
                          onChanged: (value) {
                            setState(() => _filterStatus = value!);
                            Navigator.pop(context);
                          },
                        ),
                      )
                      .toList(),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
    );
  }

  void _showAddTaskDialog() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vous devez être connecté pour créer une tâche'),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder:
          (context) => AddEditTaskDialog(
            projectId: widget.projectId,
            onSave: (task) => _taskRepository.addTask(task),
          ),
    );
  }

  void _showEditTaskDialog(SharedTask task) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vous devez être connecté pour modifier une tâche'),
        ),
      );
      return;
    }

    if (task.creatorId != user.uid &&
        !task.assignedUserIds.contains(user.uid)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Vous n\'avez pas la permission de modifier cette tâche',
          ),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder:
          (context) => AddEditTaskDialog(
            projectId: widget.projectId,
            task: task,
            onSave: (updatedTask) => _taskRepository.updateTask(updatedTask),
          ),
    );
  }

  void _showDeleteDialog(SharedTask task) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vous devez être connecté pour supprimer une tâche'),
        ),
      );
      return;
    }

    if (task.creatorId != user.uid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Seul le créateur peut supprimer cette tâche'),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(
              'Supprimer la tâche',
              style: GoogleFonts.interTight(fontWeight: FontWeight.bold),
            ),
            content: Text(
              'Voulez-vous vraiment supprimer "${task.title}"?',
              style: GoogleFonts.inter(),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Annuler', style: GoogleFonts.inter()),
              ),
              TextButton(
                onPressed: () {
                  _taskRepository.deleteTask(task.id);
                  Navigator.pop(context);
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
}
