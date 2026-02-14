import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

class WebsocetService {
  late WebSocketChannel _channel;
  late Function(Map<String, dynamic>) _onMessage;
  late bool _isConnected;

  Future<void> connect(
    String url,
    Map<String, dynamic> handShakeMessage,
    Function(Map<String, dynamic>) onMessage,
  ) async {
    try {
      print('🔌 Connecting to WebSocket: $url');
      _channel = WebSocketChannel.connect(Uri.parse(url));
      _onMessage = onMessage;
      
      // Ждём, пока соединение установится
      print('⏳ Waiting for connection...');
      await _channel.ready;
      _isConnected = true;
      print('✅ WebSocket connected');
      print('📤 Sending handshake: $handShakeMessage');
      send(handShakeMessage);

      _channel.stream.listen(
        (message) {
          print('📨 WebSocket received: $message');
          try {
            late Map<String, dynamic> data;

            // Если message уже Map (на web это может быть)
            if (message is Map<String, dynamic>) {
              data = message;
            } else if (message is String) {
              // Если это строка - парсим JSON
              data = jsonDecode(message);
            } else {
              print("Unknown message type: ${message.runtimeType}");
              return;
            }

            print('📦 Parsed data: $data');
            _onMessage(data);
          } catch (e) {
            print("Error parsing data: $e");
          }
        },
        onError: (error) {
          print('WebSocket err $error');
          _isConnected = false;
        },
        onDone: () {
          disconnect();
        },
      );
    } catch (e) {
      print("Error to connecting to WS ");
      rethrow;
    }
  }

  void disconnect() {
    if (!_isConnected) return;
    _isConnected = false;
    _channel.sink.close();
  }

  void send(Map<String, dynamic> data) {
    if (!_isConnected) {
      throw Exception('WebSocket not connected');
    }
    _channel.sink.add(jsonEncode(data));
  }

}
