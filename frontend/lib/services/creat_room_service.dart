import 'dart:convert';
import 'package:frontend/models/decode_message.dart';
import 'package:frontend/models/message.dart';
import 'package:frontend/services/websocet_service.dart';
import 'package:http/http.dart' as http;

class RoomManager {
  final String url;
  final String wsUrl;
  final String userId;
  final WebsocetService websocetService;

  List<BaseMessage> messages = [];
  Function(BaseMessage)? onMessageReceived;

  RoomManager({
    required this.url,
    required this.wsUrl,
    required this.userId,
    required this.websocetService,
  });

  late String _currentRoomId;

  /// Создаёт новую комнату через HTTP и подключается к WebSocket
  Future<String> createAndJoinRoom() async {
    try {
      print('Creating room at: $url/room');

      final response = await http.post(
        Uri.parse('$url/createroom'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'clientId': userId}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        _currentRoomId = data['roomId'];
        print('✅ Room created: $_currentRoomId');

        // Сразу подключаемся к WebSocket
        await connectToWs();
        return _currentRoomId;
      } else {
        throw Exception('Failed to create room: ${response.statusCode}');
      }
    } catch (e) {
      print('Error creating room: $e');
      rethrow;
    }
  }

  /// Присоединяется к существующей комнате через HTTP и подключается к WebSocket
  Future<void> joinExistingRoom(String roomId) async {
    try {
      print('Joining room at: $url/room');
      print('DEBUG: roomId=$roomId, clientId=$userId');

      final response = await http.post(
        Uri.parse('$url/room'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'roomId': roomId, 'clientId': userId}),
      );

      print('DEBUG: Response status=${response.statusCode}, body=${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        _currentRoomId = roomId;
        print('✅ Room joined: $_currentRoomId');

        // Сразу подключаемся к WebSocket
        await connectToWs();
      } else {
        throw Exception('Failed to join room: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Error joining room: $e');
      rethrow;
    }
  }

  /// Подключается к WebSocket и отправляет первое сообщение join
  Future<void> connectToWs() async {
    try {
      final roomId = _currentRoomId;
      if (roomId.isEmpty) {
        throw Exception('Room ID is not set');
      }

      final joinMessage = JoinRoomMessage(clientId: userId, roomId: roomId);

      await websocetService.connect(wsUrl, joinMessage.toJson(), (data) {
        print('✅ Callback called with: $data');
        try {
          final message = decodeMessage(data);
          print('✅ Message decoded: $message');
          if (onMessageReceived != null) {
            onMessageReceived!(message);
            print('✅ onMessageReceived called');
          }
        } catch (e) {
          print('❌ Error decoding message: $e');
          rethrow;
        }
      });

      print('✅ Connected to WebSocket');
    } catch (e) {
      print('Error connecting to WebSocket: $e');
      rethrow;
    }
  }

  /// Отправляет чат-сообщение в комнату
  void sendChatMessage(String payload) {
    try {
      final message = ChatMessage(from: userId, payload: payload);
      websocetService.send(message.toJson());
      print('✅ Chat message sent: $payload');
    } catch (e) {
      print('❌ Error sending chat message: $e');
    }
  }

  /// Отключается от WebSocket и очищает ресурсы
  void disconnect() {
    websocetService.disconnect();
  }
}
