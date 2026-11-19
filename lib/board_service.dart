class BoardService {
  // CREATE: Add a new message.
  Future<void> createMessage({
    required String text,
    required String authorUid,
    required String authorName,
  }) async {
    throw UnimplementedError();
  }

  // READ: Listen for messages in real time.
  Stream<List<Map<String, dynamic>>> watchMessages() {
    throw UnimplementedError();
  }

  // UPDATE: Edit an existing message.
  Future<void> updateMessage({
    required String messageId,
    required String text,
  }) async {
    throw UnimplementedError();
  }

  // DELETE: Delete an existing message.
  Future<void> deleteMessage({required String messageId}) async {
    throw UnimplementedError();
  }
}
