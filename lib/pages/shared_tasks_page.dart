import 'package:flutter/material.dart';
import 'package:fourcoop/models/shared_task_model.dart';
import 'package:fourcoop/repository/shared_task_repository.dart';
import 'package:fourcoop/widgets/task_item.dart';
import 'package:fourcoop/widgets/add_edit_task_dialog.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:table_calendar/table_calendar.dart';
 
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
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  List<SharedTask> _tasks = [];
 
  @override
  void initState() {
    super.initState();
    _taskRepository = SharedTaskRepository();
    _selectedDay = _focusedDay;
    _initializeTasks();
  }
 
  void _initializeTasks() {
    _taskRepository.getTasksByProject(widget.projectId).listen((tasks) {
      if (mounted) {
        setState(() {
          _tasks = tasks;
        });
      }
    });
  }
 
  @override
  void dispose() {
    _taskRepository.dispose();
    super.dispose();
  }
 
  List<SharedTask> getTasksForDay(DateTime day) {
    return _tasks
        .where(
          (task) =>
              task.dueDate.year == day.year &&
              task.dueDate.month == day.month &&
              task.dueDate.day == day.day &&
              (_filterStatus == 'Tous' || task.status == _filterStatus),
        )
        .toList();
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
 
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tasksOfDay = getTasksForDay(_selectedDay ?? _focusedDay);
 
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
        child: Column(
          children: [
            TableCalendar(
              firstDay: DateTime.utc(2020, 1, 1),
              lastDay: DateTime.utc(2030, 12, 31),
              focusedDay: _focusedDay,
              selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
              eventLoader: getTasksForDay,
              onDaySelected: (selectedDay, focusedDay) {
                setState(() {
                  _selectedDay = selectedDay;
                  _focusedDay = focusedDay;
                });
              },
              calendarStyle: CalendarStyle(
                markerDecoration: BoxDecoration(
                  color: Colors.blue,
                  shape: BoxShape.circle,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child:
                  tasksOfDay.isEmpty
                      ? Center(
                        child: Text(
                          "Aucune tâche pour ce jour.",
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                      : ListView(
                        children:
                            tasksOfDay
                                .map(
                                  (task) => Card(
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    elevation: 2,
                                    child: ListTile(
                                      leading: Icon(
                                        task.isPublic
                                            ? Icons.public
                                            : Icons.lock,
                                        color:
                                            task.isPublic
                                                ? Colors.blue
                                                : Colors.redAccent,
                                      ),
                                      title: Text(
                                        task.title,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      subtitle: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          if (task.description.isNotEmpty)
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                top: 4.0,
                                              ),
                                              child: Text(
                                                task.description,
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                ),
                                              ),
                                            ),
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              top: 6.0,
                                            ),
                                            child: Row(
                                              children: [
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 2,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color:
                                                        task.status ==
                                                                'Terminée'
                                                            ? Colors.green
                                                            : (task.status ==
                                                                    'En cours'
                                                                ? Colors.orange
                                                                : Colors.grey),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          12,
                                                        ),
                                                  ),
                                                  child: Text(
                                                    task.status,
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Icon(
                                                  Icons.calendar_today,
                                                  size: 14,
                                                  color: Colors.blueGrey,
                                                ),
                                                const SizedBox(width: 2),
                                                Text(
                                                  "${task.dueDate.day}/${task.dueDate.month}/${task.dueDate.year}",
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.blueGrey,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: Icon(
                                              Icons.edit,
                                              color: Colors.orange,
                                            ),
                                            onPressed:
                                                () => _showEditTaskDialog(task),
                                          ),
                                          IconButton(
                                            icon: Icon(
                                              Icons.delete,
                                              color: Colors.red,
                                            ),
                                            onPressed:
                                                () => _showDeleteDialog(task),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                      ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddTaskDialog,
        child: const Icon(Icons.add),
        backgroundColor: theme.colorScheme.primary,
      ),
    );
  }
}
 