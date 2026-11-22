import 'package:cloud_firestore/cloud_firestore.dart';

import 'message.dart';

class BoardService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Generate one ID for each new message operation.
  String newMessageId() {
    return _db.collection('messages').doc().id;
  }

  // CREATE — Add a new message.
  Future<void> postMessage({
    required String messageId,
    required String authorUid,
    required String authorName,
    required String text,
  }) async {
    final cleanText = text.trim();

    // Reject invalid messages.
    if (cleanText.isEmpty) {
      throw Exception('Message cannot be empty.');
    }

    // Use the same document ID for every retry.
    final messageRef = _db.collection('messages').doc(messageId);

    await _db.runTransaction((transaction) async {
      // Check whether this message already exists.
      final snapshot = await transaction.get(messageRef);

      if (snapshot.exists) {
        final savedMessage = snapshot.data()!;

        // Avoid accidentally treating a different
        // message as the same operation.
        if (savedMessage['authorUid'] != authorUid ||
            savedMessage['authorName'] != authorName ||
            savedMessage['text'] != cleanText) {
          throw StateError('Message ID already used.');
        }

        // Message already exists. Do not create it again.
        return;
      }

      // Create the message only if it does not exist.
      transaction.set(messageRef, {
        'authorUid': authorUid,
        'authorName': authorName,
        'text': cleanText,
        'createdAt': FieldValue.serverTimestamp(),
        'editedAt': null,
      });
    });
  }

  // READ — Listen for messages in real time.
  Stream<List<Message>> messageBoard() {
    return _db.collection('messages').orderBy('createdAt').snapshots().map((
      snapshot,
    ) {
      //converts each Firestore document into a Message object
      return snapshot.docs.map((doc) {
        final data = doc.data();

        return Message(
          id: doc.id,
          text: data['text'] ?? '',
          authorUid: data['authorUid'] ?? '',
          authorName: data['authorName'] ?? '',
          createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
          editedAt: (data['editedAt'] as Timestamp?)?.toDate(),
        );
      }).toList();
    });
  }

  /// UPDATE — own message only (rules enforce it)
  Future<void> editMessage({
    required String messageId,
    required String newText,
  }) async {
    await _db.collection('messages').doc(messageId).update({
      'text': newText,
      'editedAt': FieldValue.serverTimestamp(),
    });
  }

  /// DELETE — own message only (rules enforce it)
  Future<void> deleteMessage({required String messageId}) async {
    await _db.collection('messages').doc(messageId).delete();
  }
}
