import 'package:flutter/material.dart';
import 'package:fourcoop/models/shared_task_model.dart';

class TaskItem extends StatelessWidget {
  final SharedTask task;
  final Function(String) onStatusChanged;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const TaskItem({
    Key? key,
    required this.task,
    required this.onStatusChanged,
    required this.onEdit,
    required this.onDelete,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCompleted = task.status == 'Terminée';

    return Card(
      margin: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: InkWell(
        onTap: onEdit,
        child: Padding(
          padding: EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      task.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        decoration: isCompleted ? TextDecoration.lineThrough : null,
                        color: isCompleted ? theme.textTheme.titleMedium?.color?.withOpacity(0.6) : null,
                      ),
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: onStatusChanged,
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'À faire',
                        child: Text('À faire'),
                      ),
                      PopupMenuItem(
                        value: 'En cours',
                        child: Text('En cours'),
                      ),
                      PopupMenuItem(
                        value: 'Terminée',
                        child: Text('Terminée'),
                      ),
                    ],
                    child: Chip(
                      label: Text(task.status),
                      backgroundColor: _getStatusColor(task.status, theme),
                    ),
                  ),
                ],
              ),
              if (task.description.isNotEmpty) ...[
                SizedBox(height: 8),
                Text(
                  task.description,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    decoration: isCompleted ? TextDecoration.lineThrough : null,
                    color: isCompleted ? theme.textTheme.bodyMedium?.color?.withOpacity(0.6) : null,
                  ),
                ),
              ],
              SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.calendar_today, size: 16, color: theme.colorScheme.onSurface.withOpacity(0.6)),
                      SizedBox(width: 4),
                      Text(
                        _formatDate(task.dueDate),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                      if (task.completedAt != null) ...[
                        SizedBox(width: 16),
                        Icon(Icons.check_circle, size: 16, color: theme.colorScheme.primary),
                        SizedBox(width: 4),
                        Text(
                          'Terminée le ${_formatDate(task.completedAt!)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ],
                  ),
                  IconButton(
                    icon: Icon(Icons.delete, size: 20),
                    onPressed: onDelete,
                    color: theme.colorScheme.error,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(String status, ThemeData theme) {
    switch (status) {
      case 'En cours':
        return theme.colorScheme.secondaryContainer;
      case 'Terminée':
        return theme.colorScheme.primaryContainer;
      default:
        return theme.colorScheme.surfaceVariant;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}