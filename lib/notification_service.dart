import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class NotificationService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  // Run only when the user clicks Enable Notifications.
  Future<String> enableNotifications() async {
    final user = _auth.currentUser;

    if (user == null) {
      return 'Please sign in first.';
    }

    try {
      // STEP 1: Ask for notification permission.
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      // STEP 2: Respect the user's decision.
      if (settings.authorizationStatus != AuthorizationStatus.authorized) {
        return 'Notifications are off. You can enable them later.';
      }

      // STEP 3: Listen for the Firebase Installation ID.
      // Subscribe BEFORE calling register().
      final registrationFuture = _messaging.onRegistered.first.timeout(
        const Duration(seconds: 20),
      );

      // STEP 4: Register only after permission was granted.
      await _messaging.register();

      final installationId = await registrationFuture;

      if (installationId.isEmpty) {
        return 'Could not register notifications. Please try again.';
      }

      // STEP 5: Make sure the same user is still signed in.
      if (_auth.currentUser?.uid != user.uid) {
        return 'The signed-in user changed. Please try again.';
      }

      // STEP 6: Save the ID privately in Firestore.
      await _db
          .collection('users')
          .doc(user.uid)
          .collection('private')
          .doc('fcm')
          .set({
            'installationId': installationId,
            'updatedAt': FieldValue.serverTimestamp(),
          });

      return 'Notifications enabled successfully!';
    } catch (e) {
      return 'Could not enable notifications. Please try again.';
    }
  }
}
