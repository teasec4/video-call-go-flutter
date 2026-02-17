import 'dart:convert';
import 'package:http/http.dart' as http;

/// Управляет HTTP операциями: создание и присоединение к комнате
class HttpRoomService {
  final String baseUrl;

  HttpRoomService({required this.baseUrl});

  /// Создаёт новую комнату и возвращает roomId
  Future<String> createRoom(String clientId) async {
    try {
      print('🏗️ Creating room...');
      final response = await http.post(
        Uri.parse('$baseUrl/createroom'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'clientId': clientId}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        final roomId = data['roomId'] as String;
        print('✅ Room created: $roomId');
        return roomId;
      } else {
        throw Exception('Failed to create room: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error creating room: $e');
      rethrow;
    }
  }

  /// Присоединяется к существующей комнате
  Future<void> joinRoom(String roomId, String clientId) async {
    try {
      print('📍 Joining room: $roomId');
      final response = await http.post(
        Uri.parse('$baseUrl/room'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'roomId': roomId, 'clientId': clientId}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        print('✅ Room joined: $roomId');
      } else {
        throw Exception('Failed to join room: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('❌ Error joining room: $e');
      rethrow;
    }
  }
}
