class Message {
  final String id;
  final String text;
  final String authorUid;
  final String authorName;
  final DateTime? createdAt;
  final DateTime? editedAt;

  Message({
    required this.id,
    required this.text,
    required this.authorUid,
    required this.authorName,
    required this.createdAt,
    required this.editedAt,
  });
}
