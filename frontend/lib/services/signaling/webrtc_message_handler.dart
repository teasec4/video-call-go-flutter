import 'package:frontend/models/message_model.dart';
import 'signaling_message_handler.dart';

/// Handler для WebRTC сообщений (offer, answer, ice-candidate)
class WebRTCMessageHandler implements SignalingMessageHandler {
  @override
  bool canHandle(String messageType) {
    return messageType == 'offer' ||
        messageType == 'answer' ||
        messageType == 'ice-candidate';
  }

  @override
  void handle(SignalingMessage message) {
    print('📨 WebRTCMessageHandler: Processing ${message.type} from ${message.from}');
    
    switch (message.type) {
      case 'offer':
        _handleOffer(message);
        break;
      case 'answer':
        _handleAnswer(message);
        break;
      case 'ice-candidate':
        _handleIceCandidate(message);
        break;
    }
  }

  void _handleOffer(SignalingMessage msg) {
    final sdp = msg.payload['sdp'] as String? ?? '';
    print('📥 Offer received from ${msg.from}');
    print('   SDP length: ${sdp.length}');
  }

  void _handleAnswer(SignalingMessage msg) {
    final sdp = msg.payload['sdp'] as String? ?? '';
    print('📥 Answer received from ${msg.from}');
    print('   SDP length: ${sdp.length}');
  }

  void _handleIceCandidate(SignalingMessage msg) {
    final candidate = msg.payload['candidate'] as String? ?? '';
    print('📥 ICE candidate received from ${msg.from}');
    print('   Candidate: ${candidate.substring(0, 30)}...');
  }
}
