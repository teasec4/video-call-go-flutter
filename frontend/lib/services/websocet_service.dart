import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

class WebsocetService {
  late WebSocketChannel _channel;
  late Function(Map<String, dynamic>) _onMessage;

  Future<void> conncet(
    String url,
    Function(Map<String, dynamic>) onMessage,
  ) async {
    try {
      _channel = WebSocketChannel.connect(Uri.parse(url));
      _onMessage = onMessage;

      _channel.stream.listen(
        (message) {
          try {
            final data = jsonDecode(message);
            _onMessage(data);
          } catch (e) {
            print("Error parsing data");
          }
        },
        onError: (error) {
          print('WebSicket err $error');
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
    _channel.sink.close();
  }
}
