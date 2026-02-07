import 'dart:convert';
import 'package:frontend/models/message.dart';
import 'package:frontend/services/websocet_service.dart';
import 'package:http/http.dart' as http;

class RoomManager {
  final String url;
  final String wsUrl;
  final String userId;
  final WebsocetService websocetService;

  List<Message> messages = [];
  Function(Message)? onMessageReceived;

  RoomManager({
    required this.url,
    required this.wsUrl,
    required this.userId,
    required this.websocetService,
  });

  late String _currentRoomId;

  Future<String> createRoom() async {
    try {
      print('Creating room at: $url/createroom');

      final response = await http.post(
        Uri.parse('$url/createroom'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'clientId': userId}),
      );

      print('Response status: ${response.statusCode}');
      print('Response body: "${response.body}"');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        print('Room created successfully: $data');
        _currentRoomId = data['roomId'];
        return _currentRoomId;
      } else {
        throw Exception('Failed to create room: ${response.statusCode}');
      }
    } catch (e) {
      print('Error creating room: $e');
      rethrow;
    }
  }

  Future<void> joinRoom(String roomId) async {
    try {
      print('Joining room at: $url/joinroom');

      final response = await http.post(
        Uri.parse('$url/joinroom'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'roomId': roomId, 'clientId': userId}),
      );

      print('Response status: ${response.statusCode}');
      print('Response body: "${response.body}"');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        print('Room joined successfully: $data');
        _currentRoomId = roomId;
      } else {
        print('Failed to join room: ${response.statusCode}');
      }
    } catch (e) {
      print('Error joining room: $e');
    }
  }

  Future<void> connectToWs() async {
    try {
      await websocetService.connect(wsUrl, (data) {
        print('Received from WS: $data');
        final message = Message.fromJson(data);
        messages.add(message);
        
        if (onMessageReceived != null) {
          onMessageReceived!(message);
        }
      });

      // Даем время на подключение
      await Future.delayed(const Duration(milliseconds: 500));

      websocetService.send({'clientId': userId, 'roomId': _currentRoomId});
      print('✅ Connected to WebSocket and sent registration');
    } catch (e) {
      print('Error connecting to WebSocket: $e');
      rethrow;
    }
  }
}
