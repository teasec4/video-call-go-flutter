import 'package:frontend/models/message_model.dart';
import 'signaling_message_handler.dart';

/// Dispatcher для маршрутизации сообщений нужным handlers
class MessageDispatcher {
  final List<SignalingMessageHandler> handlers;

  MessageDispatcher({required this.handlers});

  /// Отправить сообщение нужному handler'у
  void dispatch(SignalingMessage message) {
    print('📤 MessageDispatcher: Dispatching ${message.type}');
    
    for (final handler in handlers) {
      if (handler.canHandle(message.type)) {
        print('   ✓ Found handler for ${message.type}');
        handler.handle(message);
        return;
      }
    }
    
    print('   ✗ No handler found for ${message.type}');
  }

  /// Добавить новый handler
  void addHandler(SignalingMessageHandler handler) {
    handlers.add(handler);
  }

  /// Удалить handler
  void removeHandler(SignalingMessageHandler handler) {
    handlers.remove(handler);
  }
}
