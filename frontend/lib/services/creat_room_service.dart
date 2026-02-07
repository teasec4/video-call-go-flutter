import 'dart:convert';
import 'package:http/http.dart' as http;

class RoomManager {
  final String url;
  final String userId;

  RoomManager({required this.url, required this.userId});

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
        return data['roomId'];
      } else {
        throw Exception('Failed to create room: ${response.statusCode}');
      }
    } catch (e) {
      print('Error creating room: $e');
      rethrow;
    }
  }
}