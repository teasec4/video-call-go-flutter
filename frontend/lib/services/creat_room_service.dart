import 'dart:convert';

import 'package:http/http.dart' as http;

class RoomManager {
  final String url;

  RoomManager({required this.url});

  Future<String> createRoom() async {
    try {
      print('Creating room at: $url/createroom');
      late http.Response response;

      try {
        response = await http.post(
          Uri.parse('$url/createroom'),
          headers: {'Content-Type': 'application/json'},
        );
      } catch (e) {
        print('Network error: $e');
        print('Error type: ${e.runtimeType}');
        rethrow;
      }
      
      print('Response status: ${response.statusCode}');
      print('Response body: "${response.body}"');
      print('Response body length: ${response.body.length}');

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print(data);
        return data['roomId'];
      } else {
        throw Exception('Failed to load');
      }
    } catch (e) {
      print('Error: $e');
      rethrow;
    }
  }
}
