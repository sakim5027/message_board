import 'package:cloud_firestore/cloud_firestore.dart';

import 'message.dart';

class BoardService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // CREATE — Add a new message.
  Future<void> postMessage({
    required String authorUid,
    required String authorName,
    required String text,
  }) async {
    // Do not allow an empty message.
    if (text.trim().isEmpty) {
      throw ArgumentError('Message cannot be empty.');
    }

    await _db.collection('messages').add({
      'authorUid': authorUid,
      'authorName': authorName,
      'text': text.trim(),
      'createdAt': FieldValue.serverTimestamp(),
      'editedAt': null,
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
