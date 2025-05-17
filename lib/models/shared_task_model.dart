import 'package:cloud_firestore/cloud_firestore.dart';

class SharedTask {
  final String id;
  final String projectId;
  final String title;
  final String description;
  final DateTime dueDate;
  final String status; // 'À faire', 'En cours', 'Terminée'
  final String creatorId;
  final List<String> adminUserIds; // Nouveaux admins de la tâche
  final List<String> assignedUserIds; // Exécutants
  final bool isPublic; // Visibilité
  final DateTime createdAt;
  final DateTime? completedAt;

  SharedTask({
    this.id = '',
    required this.projectId,
    required this.title,
    required this.description,
    required this.dueDate,
    this.status = 'À faire',
    required this.creatorId,
    required this.adminUserIds,
    required this.assignedUserIds,
    this.isPublic = false,
    required this.createdAt,
    this.completedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'projectId': projectId,
      'title': title,
      'description': description,
      'dueDate': Timestamp.fromDate(dueDate),
      'status': status,
      'creatorId': creatorId,
      'adminUserIds': adminUserIds,
      'assignedUserIds': assignedUserIds,
      'isPublic': isPublic,
      'createdAt': Timestamp.fromDate(createdAt),
      'completedAt':
          completedAt != null ? Timestamp.fromDate(completedAt!) : null,
    };
  }

  factory SharedTask.fromMap(Map<String, dynamic> map, String id) {
    return SharedTask(
      id: id,
      projectId: map['projectId'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      dueDate: (map['dueDate'] as Timestamp).toDate(),
      status: map['status'] ?? 'À faire',
      creatorId: map['creatorId'] ?? '',
      adminUserIds: List<String>.from(map['adminUserIds'] ?? []),
      assignedUserIds: List<String>.from(map['assignedUserIds'] ?? []),
      isPublic: map['isPublic'] ?? false,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      completedAt:
          map['completedAt'] != null
              ? (map['completedAt'] as Timestamp).toDate()
              : null,
    );
  }

  SharedTask copyWith({
    String? title,
    String? description,
    DateTime? dueDate,
    String? status,
    List<String>? adminUserIds,
    List<String>? assignedUserIds,
    bool? isPublic,
    DateTime? completedAt,
  }) {
    return SharedTask(
      id: id,
      projectId: projectId,
      title: title ?? this.title,
      description: description ?? this.description,
      dueDate: dueDate ?? this.dueDate,
      status: status ?? this.status,
      creatorId: creatorId,
      adminUserIds: adminUserIds ?? this.adminUserIds,
      assignedUserIds: assignedUserIds ?? this.assignedUserIds,
      isPublic: isPublic ?? this.isPublic,
      createdAt: createdAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }
}
