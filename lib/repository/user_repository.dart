import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';


class UserRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> updateUser(UserModel user) async {
    await _firestore.collection('users').doc(user.uid).update(user.toMap());
  }

  Future<UserModel?> getUser(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    if (doc.exists) {
      return UserModel.fromMap(doc.data()!, doc.id);
    }
    return null;
  }
}