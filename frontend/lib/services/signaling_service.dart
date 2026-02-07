import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

class SignalingService {
  late WebSocketChannel _channel;
  late Function(Map<String, dynamic>) _onMessage;
  
  bool _isConnected = false;

  bool get isConnected => _isConnected;

  Future<void> connect(String url, Function(Map<String, dynamic>) onMessage) async {
    try {
      _channel = WebSocketChannel.connect(Uri.parse(url));
      _onMessage = onMessage;
      _isConnected = true;

      _channel.stream.listen(
        (message) {
          try {
            final data = jsonDecode(message);
            _onMessage(data);
          } catch (e) {
            print('Error parsing signaling message: $e');
          }
        },
        onError: (error) {
          print('WebSocket error: $error');
          _isConnected = false;
        },
        onDone: () {
          _isConnected = false;
        },
      );
    } catch (e) {
      print('Error connecting to signaling service: $e');
      rethrow;
    }
  }

  void sendOffer(RTCSessionDescription offer) {
    final message = {
      'type': 'offer',
      'data': offer.sdp,
    };
    _send(message);
  }

  void sendAnswer(RTCSessionDescription answer) {
    final message = {
      'type': 'answer',
      'data': answer.sdp,
    };
    _send(message);
  }

  void sendIceCandidate(RTCIceCandidate candidate) {
    final message = {
      'type': 'ice_candidate',
      'data': {
        'candidate': candidate.candidate,
        'sdpMLineIndex': candidate.sdpMLineIndex,
        'sdpMid': candidate.sdpMid,
      }
    };
    _send(message);
  }

  void _send(Map<String, dynamic> message) {
    if (_isConnected) {
      _channel.sink.add(jsonEncode(message));
    }
  }

  void disconnect() {
    _isConnected = false;
    _channel.sink.close();
  }
}
