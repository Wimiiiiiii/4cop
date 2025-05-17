import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/shared_task_model.dart';

class SharedTaskRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Stream<List<SharedTask>> getTasksByProject(String projectId) {
    final user = _auth.currentUser;
    if (user == null) return Stream.value([]);
    final userId = user.uid;

    return _firestore
        .collection('sharedTasks')
        .where('projectId', isEqualTo: projectId)
        .orderBy('dueDate')
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .map((doc) => SharedTask.fromMap(doc.data(), doc.id))
                  .where(
                    (task) =>
                        task.isPublic ||
                        task.adminUserIds.contains(userId) ||
                        task.assignedUserIds.contains(userId),
                  )
                  .toList(),
        );
  }

  Future<String> addTask(SharedTask task) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Utilisateur non connecté');

    final taskData = task.toMap();
    if (!(taskData['adminUserIds'] as List).contains(user.uid)) {
      (taskData['adminUserIds'] as List).add(user.uid);
    }
    taskData['creatorId'] = user.uid;
    if (taskData['assignedUserIds'] == null) {
      taskData['assignedUserIds'] = [];
    }
    final docRef = await _firestore.collection('sharedTasks').add(taskData);
    return docRef.id;
  }

  Future<void> updateTask(SharedTask task) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Utilisateur non connecté');

    final taskDoc =
        await _firestore.collection('sharedTasks').doc(task.id).get();
    if (!taskDoc.exists) throw Exception('Tâche non trouvée');

    final taskData = taskDoc.data() as Map<String, dynamic>;
    if (!(taskData['adminUserIds'] as List<dynamic>).contains(user.uid)) {
      throw Exception('Seuls les admins de la tâche peuvent la modifier');
    }

    await _firestore
        .collection('sharedTasks')
        .doc(task.id)
        .update(task.toMap());
  }

  Future<void> deleteTask(String taskId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Utilisateur non connecté');

    final taskDoc =
        await _firestore.collection('sharedTasks').doc(taskId).get();
    if (!taskDoc.exists) throw Exception('Tâche non trouvée');

    final taskData = taskDoc.data() as Map<String, dynamic>;
    if (!(taskData['adminUserIds'] as List<dynamic>).contains(user.uid)) {
      throw Exception('Seuls les admins de la tâche peuvent la supprimer');
    }

    await _firestore.collection('sharedTasks').doc(taskId).delete();
  }

  Future<void> updateTaskStatus(String taskId, String newStatus) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Utilisateur non connecté');

    final taskDoc =
        await _firestore.collection('sharedTasks').doc(taskId).get();
    if (!taskDoc.exists) throw Exception('Tâche non trouvée');

    final taskData = taskDoc.data() as Map<String, dynamic>;
    if (!(taskData['adminUserIds'] as List<dynamic>).contains(user.uid) &&
        !(taskData['assignedUserIds'] as List<dynamic>).contains(user.uid)) {
      throw Exception('Vous n\'avez pas la permission de modifier cette tâche');
    }

    final updateData = {
      'status': newStatus,
      if (newStatus == 'Terminée') 'completedAt': Timestamp.now(),
    };

    await _firestore.collection('sharedTasks').doc(taskId).update(updateData);
  }

  Future<void> assignAdmins(String taskId, List<String> adminIds) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Utilisateur non connecté');

    final taskDoc =
        await _firestore.collection('sharedTasks').doc(taskId).get();
    if (!taskDoc.exists) throw Exception('Tâche non trouvée');

    final taskData = taskDoc.data() as Map<String, dynamic>;
    if (!(taskData['adminUserIds'] as List<dynamic>).contains(user.uid)) {
      throw Exception('Seuls les admins peuvent assigner d\'autres admins');
    }

    await _firestore.collection('sharedTasks').doc(taskId).update({
      'adminUserIds': adminIds,
    });
  }

  Future<void> assignUsers(String taskId, List<String> userIds) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Utilisateur non connecté');

    final taskDoc =
        await _firestore.collection('sharedTasks').doc(taskId).get();
    if (!taskDoc.exists) throw Exception('Tâche non trouvée');

    final taskData = taskDoc.data() as Map<String, dynamic>;
    if (!(taskData['adminUserIds'] as List<dynamic>).contains(user.uid)) {
      throw Exception('Seuls les admins peuvent assigner des utilisateurs');
    }

    await _firestore.collection('sharedTasks').doc(taskId).update({
      'assignedUserIds': userIds,
    });
  }

  Stream<List<SharedTask>> getUserTasks(String userId) {
    return _firestore
        .collection('sharedTasks')
        .where('assignedUserIds', arrayContains: userId)
        .orderBy('dueDate')
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .map((doc) => SharedTask.fromMap(doc.data(), doc.id))
                  .toList(),
        );
  }
}
