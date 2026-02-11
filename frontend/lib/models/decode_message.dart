import 'package:frontend/models/message.dart';

BaseMessage decodeMessage(Map<String, dynamic> json) {
  final typeStr = json['type'] as String?;
  if (typeStr == null) {
    throw Exception('Message type is required');
  }

  final type = MessageType.fromString(typeStr);

  switch (type) {
    case MessageType.chat:
      return ChatMessage.fromJson(json);
    case MessageType.join:
      return JoinRoomMessage.fromJson(json);
    case MessageType.joined:
      return JoinedMessage.fromJson(json);
    case MessageType.error:
      return ErrorMessage.fromJson(json);
    case MessageType.userLeft:
      return UserLeftMessage.fromJson(json);
  }
}
