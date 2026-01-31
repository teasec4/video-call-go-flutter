import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:frontend/models/message_model.dart';
import '../widgets/video_area.dart';
import '../widgets/chat_area.dart';
import '../widgets/message_input.dart';
import '../widgets/call_controls.dart';

class HomeScreen extends StatefulWidget {
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
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isChatExpanded = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Video Call'),
        elevation: 0,
        backgroundColor: Colors.grey[900],
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Video area
          Expanded(
            flex: _isChatExpanded ? 3 : 5,
            child: VideoArea(
              localRenderer: widget.localRenderer,
              remoteRenderer: widget.remoteRenderer,
              renderersInitialized: widget.renderersInitialized,
              isCallActive: widget.isCallActive,
            ),
          ),
          // Peers/Messages area
          if (_isChatExpanded)
            Expanded(
              flex: 2,
              child: Column(
                children: [
                  // Chat header with toggle
                  Container(
                    color: Colors.grey[850],
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Chat',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white),
                          onPressed: () {
                            setState(() {
                              _isChatExpanded = false;
                            });
                          },
                          iconSize: 24,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ),
                  // Messages
                  ChatArea(
                    messages: widget.messages,
                    messageController: widget.messageController,
                    onSendMessage: widget.onSendMessage,
                    myId: widget.myId,
                  ),
                  // Input and controls
                  Container(
                    color: Colors.grey[900],
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        MessageInput(
                          controller: widget.messageController,
                          onSendMessage: widget.onSendMessage,
                        ),
                        CallControls(
                          isCallActive: widget.isCallActive,
                          isMicrophoneEnabled: widget.isMicrophoneEnabled,
                          onToggleMicrophone: widget.onToggleMicrophone,
                          onEndCall: widget.onEndCall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )
          else
            // Chat collapsed button
            Container(
              color: Colors.grey[850],
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: Text(
                      'Chat (${widget.messages.length})',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      if (widget.isCallActive)
                        Row(
                          children: [
                            IconButton(
                              icon: Icon(
                                widget.isMicrophoneEnabled
                                    ? Icons.mic
                                    : Icons.mic_off,
                                color: widget.isMicrophoneEnabled
                                    ? Colors.blue
                                    : Colors.red,
                              ),
                              onPressed: widget.onToggleMicrophone,
                              iconSize: 20,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.call_end, color: Colors.red),
                              onPressed: widget.onEndCall,
                              iconSize: 20,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                            const SizedBox(width: 8),
                          ],
                        ),
                      IconButton(
                        icon: const Icon(
                          Icons.keyboard_arrow_up,
                          color: Colors.white,
                        ),
                        onPressed: () {
                          setState(() {
                            _isChatExpanded = true;
                          });
                        },
                        iconSize: 24,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 12),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
