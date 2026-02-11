enum MessageType {
  join('join'),
  joined('joined'),
  chat('chat'),
  error('error'),
  userLeft('user-left');

  final String value;
  const MessageType(this.value);

  factory MessageType.fromString(String value) {
    return MessageType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => throw Exception('Unknown message type: $value'),
    );
  }
}

abstract class BaseMessage {
  final MessageType type;

  BaseMessage(this.type);

  Map<String, dynamic> toJson();
}

// Основное сообщение чата
class ChatMessage extends BaseMessage {
  final String from;
  final String? to;
  final dynamic payload;

  ChatMessage({
    required this.from,
    this.to,
    required this.payload,
  }) : super(MessageType.chat);

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      from: json['from'] as String,
      to: json['to'] as String?,
      payload: json['payload'],
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'type': type.value,
      'from': from,
      if (to != null) 'to': to,
      'payload': payload,
    };
  }

  @override
  String toString() => 'ChatMessage(from: $from, payload: $payload)';
}

// Сообщение присоединения к комнате
class JoinRoomMessage extends BaseMessage {
  final String clientId;
  final String roomId;

  JoinRoomMessage({
    required this.clientId,
    required this.roomId,
  }) : super(MessageType.join);

  @override
  Map<String, dynamic> toJson() {
    return {
      'type': type.value,
      'clientId': clientId,
      'roomId': roomId,
    };
  }

  factory JoinRoomMessage.fromJson(Map<String, dynamic> json) {
    return JoinRoomMessage(
      clientId: json['clientId'] as String,
      roomId: json['roomId'] as String,
    );
  }

  @override
  String toString() => 'JoinRoomMessage(clientId: $clientId, roomId: $roomId)';
}

// Подтверждение присоединения к комнате
class JoinedMessage extends BaseMessage {
  final String roomId;

  JoinedMessage({required this.roomId}) : super(MessageType.joined);

  @override
  Map<String, dynamic> toJson() {
    return {
      'type': type.value,
      'roomId': roomId,
    };
  }

  factory JoinedMessage.fromJson(Map<String, dynamic> json) {
    return JoinedMessage(roomId: json['roomId'] as String);
  }

  @override
  String toString() => 'JoinedMessage(roomId: $roomId)';
}

// Ошибка
class ErrorMessage extends BaseMessage {
  final String payload;

  ErrorMessage({required this.payload}) : super(MessageType.error);

  @override
  Map<String, dynamic> toJson() {
    return {
      'type': type.value,
      'payload': payload,
    };
  }

  factory ErrorMessage.fromJson(Map<String, dynamic> json) {
    return ErrorMessage(payload: json['payload'] as String);
  }

  @override
  String toString() => 'ErrorMessage(payload: $payload)';
}

// Пользователь отключился
class UserLeftMessage extends BaseMessage {
  final String from;

  UserLeftMessage({required this.from}) : super(MessageType.userLeft);

  @override
  Map<String, dynamic> toJson() {
    return {
      'type': type.value,
      'from': from,
    };
  }

  factory UserLeftMessage.fromJson(Map<String, dynamic> json) {
    return UserLeftMessage(from: json['from'] as String);
  }

  @override
  String toString() => 'UserLeftMessage(from: $from)';
}
