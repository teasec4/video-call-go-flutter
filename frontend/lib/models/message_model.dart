class Message {
  final String id;
  final String sender;
  final String content;
  final DateTime timestamp;
  final bool isRead;

  Message({
    required this.id,
    required this.sender,
    required this.content,
    required this.timestamp,
    this.isRead = false,
  });

  Message copyWith({
    String? id,
    String? sender,
    String? content,
    DateTime? timestamp,
    bool? isRead,
  }) {
    return Message(
      id: id ?? this.id,
      sender: sender ?? this.sender,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
    );
  }
}
