import 'package:frontend/models/message_model.dart';
import 'signaling_message_handler.dart';

/// Handler для room-specific сообщений (room-created, room-joined, room-error)
class RoomMessageHandler implements SignalingMessageHandler {
  @override
  bool canHandle(String messageType) {
    return messageType == 'room-created' ||
        messageType == 'room-joined' ||
        messageType == 'room-error';
  }

  @override
  void handle(SignalingMessage message) {
    print('📨 RoomMessageHandler: Processing ${message.type}');
    
    switch (message.type) {
      case 'room-created':
        _handleRoomCreated(message);
        break;
      case 'room-joined':
        _handleRoomJoined(message);
        break;
      case 'room-error':
        _handleRoomError(message);
        break;
    }
  }

  void _handleRoomCreated(SignalingMessage msg) {
    final roomId = msg.payload['roomId'] as String;
    print('✅ Room created: ${roomId.substring(0, 8)}...');
  }

  void _handleRoomJoined(SignalingMessage msg) {
    final roomId = msg.payload['roomId'] as String;
    final peerCount = msg.payload['peerCount'] as int;
    final connectedPeer = msg.payload['connectedPeer'] as String? ?? '';
    
    print('✅ Joined room ${roomId.substring(0, 8)}... (peers: $peerCount)');
    if (connectedPeer.isNotEmpty) {
      print('   Connected peer: ${connectedPeer.substring(0, 8)}...');
    }
  }

  void _handleRoomError(SignalingMessage msg) {
    final error = msg.payload['error'] as String;
    print('❌ Room error: $error');
  }
}
