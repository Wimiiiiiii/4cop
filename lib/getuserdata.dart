import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

Future<DocumentSnapshot<Map<String, dynamic>>> getUserData() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    throw Exception("Utilisateur non connecté.");
  }

  final doc = await FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .get();

  if (!doc.exists) {
    throw Exception("Données utilisateur non trouvées dans Firestore.");
  }

  return doc;
}
