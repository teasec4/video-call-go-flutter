import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/message_model.dart';

class SignalingService {
  late WebSocketChannel _channel;
  late Function(SignalingMessage) onMessage;
  late Function(String) onError;

  bool get isConnected => _channel.sink != null;

  Future<void> connect(
    String url,
    Function(SignalingMessage) onMessageCallback,
    Function(String) onErrorCallback,
  ) async {
    try {
      onMessage = onMessageCallback;
      onError = onErrorCallback;

      _channel = WebSocketChannel.connect(Uri.parse(url));
      
      _channel.stream.listen(
        (data) {
          try {
            final json = jsonDecode(data);
            final message = SignalingMessage.fromJson(json);
            onMessage(message);
          } catch (e) {
            print('Error parsing message: $e');
          }
        },
        onError: (error) {
          print('WebSocket error: $error');
          onError('Connection error: $error');
        },
        onDone: () {
          print('WebSocket closed');
          onError('Connection closed');
        },
      );

      print('Connected to signaling server');
    } catch (e) {
      print('Connection failed: $e');
      onError('Connection failed: $e');
      rethrow;
    }
  }

  void sendMessage(SignalingMessage message) {
    try {
      final json = jsonEncode(message.toJson());
      _channel.sink.add(json);
      print('Message sent: ${message.type}');
    } catch (e) {
      print('Failed to send message: $e');
    }
  }

  void disconnect() {
    try {
      _channel.sink.close();
      print('Disconnected from signaling server');
    } catch (e) {
      print('Error disconnecting: $e');
    }
  }
}
