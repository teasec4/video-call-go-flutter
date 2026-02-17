/// Типы сообщений в протоколе WebSocket
enum MessageType {
  handshake,
  offer,
  answer,
  iceCandidate,
  unknown,
}

/// Структурированное сообщение от WebSocket сервера
class WSMessage {
  final MessageType type;
  final Map<String, dynamic> payload;

  WSMessage({required this.type, required this.payload});

  factory WSMessage.fromJson(Map<String, dynamic> json) {
    final typeStr = json['type'] as String?;
    final type = _parseMessageType(typeStr);
    return WSMessage(
      type: type,
      payload: json['data'] as Map<String, dynamic>? ?? {},
    );
  }

  static MessageType _parseMessageType(String? type) {
    return switch (type) {
      'handshake' => MessageType.handshake,
      'offer' => MessageType.offer,
      'answer' => MessageType.answer,
      'ice_candidate' => MessageType.iceCandidate,
      _ => MessageType.unknown,
    };
  }
}
