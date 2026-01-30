import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:frontend/models/message_model.dart';
import '../widgets/video_area.dart';
import '../widgets/peer_list.dart';
import '../widgets/chat_area.dart';
import '../widgets/message_input.dart';
import '../widgets/call_controls.dart';

class HomeScreen extends StatelessWidget {
  final RTCVideoRenderer localRenderer;
  final RTCVideoRenderer remoteRenderer;
  final bool renderersInitialized;
  final bool isCallActive;
  final bool isMicrophoneEnabled;
  final List<String> availablePeers;
  final List<SignalingMessage> messages;
  final TextEditingController messageController;
  final String myId;

  final VoidCallback onSendMessage;
  final Function(String peerId) onCallPeer;
  final VoidCallback onToggleMicrophone;
  final VoidCallback onEndCall;

  const HomeScreen({
    super.key,
    required this.localRenderer,
    required this.remoteRenderer,
    required this.renderersInitialized,
    required this.isCallActive,
    required this.isMicrophoneEnabled,
    required this.availablePeers,
    required this.messages,
    required this.messageController,
    required this.onSendMessage,
    required this.onCallPeer,
    required this.onToggleMicrophone,
    required this.onEndCall,
    required this.myId,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Video Call'), elevation: 0),
      body: Column(
        children: [
          // Video area
          Expanded(
            flex: 3,
            child: VideoArea(
              localRenderer: localRenderer,
              remoteRenderer: remoteRenderer,
              renderersInitialized: renderersInitialized,
              isCallActive: isCallActive,
            ),
          ),
          // Peers/Messages area
          Expanded(
            flex: 2,
            child: Column(
              children: [
                // Peers list
                PeerList(
                  peers: availablePeers,
                  isCallActive: isCallActive,
                  onCallPeer: onCallPeer,
                ),
                // Messages
                ChatArea(
                  messages: messages,
                  messageController: messageController,
                  onSendMessage: onSendMessage,
                  myId: myId,
                ),
                // Input and controls
                MessageInput(
                  controller: messageController,
                  onSendMessage: onSendMessage,
                ),
                CallControls(
                  isCallActive: isCallActive,
                  isMicrophoneEnabled: isMicrophoneEnabled,
                  onToggleMicrophone: onToggleMicrophone,
                  onEndCall: onEndCall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
