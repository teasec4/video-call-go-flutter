import 'package:frontend/models/message_model.dart';

/// Abstract base for signaling message handlers
abstract class SignalingMessageHandler {
  /// Проверить может ли этот handler обработать сообщение
  bool canHandle(String messageType);

  /// Обработать сообщение
  void handle(SignalingMessage message);
}
