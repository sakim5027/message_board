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

  // UPDATE
  Future<void> updateMessage({
    required String messageId,
    required String text,
  }) async {
    throw UnimplementedError();
  }

  // DELETE
  Future<void> deleteMessage({required String messageId}) async {
    throw UnimplementedError();
  }
}
