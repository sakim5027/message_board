import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UserRecordService {
  // Save a new user's information to Firestore.
  Future<void> saveUserRecord(
    User user, {
    required String firstName,
    required String lastName,
    required String role,
  }) async {
    await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
      'uid': user.uid,
      'firstName': firstName,
      'lastName': lastName,
      'role': role,
      'registrationDateTime': FieldValue.serverTimestamp(),
    });
  }

  // Check whether this user already has a Firestore record.
  Future<bool> userRecordExists(String uid) async {
    final document = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get(const GetOptions(source: Source.server));

    return document.exists;
  }

  // Listen for changes to the user's Firestore profile.
  Stream<DocumentSnapshot<Map<String, dynamic>>> watchUserRecord(User user) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .snapshots();
  }
}
