import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/call_controller.dart';
import '../widgets/video_area.dart';
import '../widgets/chat_area.dart';
import '../widgets/message_input.dart';
import '../widgets/call_controls.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({
    super.key,
    this.localRenderer,
    this.remoteRenderer,
    required this.renderersInitialized,
    required this.isCallActive,
    required this.isMicrophoneEnabled,
    required this.availablePeers,
    required this.messages,
    this.messageController,
    this.onSendMessage,
    this.onCallPeer,
    this.onToggleMicrophone,
    this.onEndCall,
    required this.myId,
  });

  final dynamic localRenderer;
  final dynamic remoteRenderer;
  final bool renderersInitialized;
  final bool isCallActive;
  final bool isMicrophoneEnabled;
  final List<String> availablePeers;
  final dynamic messages;
  final dynamic messageController;

  final VoidCallback? onSendMessage;
  final Function(String peerId)? onCallPeer;
  final VoidCallback? onToggleMicrophone;
  final VoidCallback? onEndCall;
  final String myId;

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _isChatExpanded = true;
  late TextEditingController messageController;

  @override
  void initState() {
    super.initState();
    messageController = TextEditingController();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    // Инициализируем камеру при входе в комнату
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final callController = ref.read(callControllerProvider.notifier);
      try {
        await callController.initializeCamera();
      } catch (e) {
        print('Failed to initialize camera: $e');
      }
    });
  }

  @override
  void dispose() {
    messageController.dispose();

    // If leaving the screen, stop camera and end call
    final callController = ref.read(callControllerProvider.notifier);
    final callState = ref.read(callControllerProvider);

    if (callState.roomId.isNotEmpty) {
      // Don't cleanup here - let leaveRoom handle it
      // This is just for navigation tracking
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final callState = ref.watch(callControllerProvider);
    final callController = ref.read(callControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Video Call'),
            if (callState.roomId.isNotEmpty)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Room: ${callState.roomId.substring(0, 8)}...',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[300],
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: callState.roomId));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Room ID copied!'),
                          duration: Duration(seconds: 1),
                        ),
                      );
                    },
                    child: Icon(Icons.copy, size: 12, color: Colors.blue[300]),
                  ),
                ],
              ),
          ],
        ),
        elevation: 0,
        backgroundColor: Colors.grey[900],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Leave Room',
            onPressed: () async {
              await callController.leaveRoom();
              if (mounted) {
                Navigator.of(context).pop();
              }
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // Video area
              Expanded(
                flex: _isChatExpanded ? 3 : 5,
                child: VideoArea(
                  localRenderer: callController.webrtcService.localRenderer,
                  remoteRenderer: callController.webrtcService.remoteRenderer,
                  renderersInitialized: true,
                  isCallActive: callState.isCallActive,
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
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
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
                              icon: const Icon(
                                Icons.keyboard_arrow_down,
                                color: Colors.white,
                              ),
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
                        messages: callState.messages,
                        messageController: messageController,
                        onSendMessage: () {
                          callController.sendMessage(messageController.text);
                          messageController.clear();
                        },
                        myId: callState.clientId,
                      ),
                      // Input and controls
                      Container(
                        color: Colors.grey[900],
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            MessageInput(
                              controller: messageController,
                              onSendMessage: () {
                                callController.sendMessage(
                                  messageController.text,
                                );
                                messageController.clear();
                              },
                            ),
                            CallControls(
                              isCallActive: callState.isCallActive,
                              isMicrophoneEnabled:
                                  callState.isMicrophoneEnabled,
                              onToggleMicrophone: () {
                                callController.toggleMicrophone();
                              },
                              onEndCall: () {
                                callController.endCall();
                              },
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
                          'Chat (${callState.messages.length})',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          if (callState.isCallActive)
                            Row(
                              children: [
                                IconButton(
                                  icon: Icon(
                                    callState.isMicrophoneEnabled
                                        ? Icons.mic
                                        : Icons.mic_off,
                                    color: callState.isMicrophoneEnabled
                                        ? Colors.blue
                                        : Colors.red,
                                  ),
                                  onPressed: () {
                                    callController.toggleMicrophone();
                                  },
                                  iconSize: 20,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(
                                    Icons.call_end,
                                    color: Colors.red,
                                  ),
                                  onPressed: () {
                                    callController.endCall();
                                  },
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
          // Waiting for peer overlay
          if (callState.roomId.isNotEmpty && callState.peerCount == 1)
            Container(
              color: Colors.black54,
              child: Center(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[900],
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.blue[400]!, width: 2),
                  ),
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.hourglass_empty,
                        size: 48,
                        color: Colors.blue,
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Waiting for peer...',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Room ID display card
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.grey[800],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.blue[300]!,
                            width: 1,
                          ),
                        ),
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ROOM ID',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[400],
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.grey[900],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SelectableText(
                                    callState.roomId,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Colors.white,
                                      fontFamily: 'monospace',
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: () {
                                        Clipboard.setData(
                                          ClipboardData(text: callState.roomId),
                                        );
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: const Text(
                                              'Room ID copied!',
                                            ),
                                            duration: const Duration(
                                              seconds: 1,
                                            ),
                                            backgroundColor: Colors.blue[600],
                                          ),
                                        );
                                      },
                                      borderRadius: BorderRadius.circular(6),
                                      child: Padding(
                                        padding: const EdgeInsets.all(8),
                                        child: Icon(
                                          Icons.copy,
                                          size: 18,
                                          color: Colors.blue[300],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Share this ID with your friend',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[500],
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: 48,
                        height: 48,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          valueColor: AlwaysStoppedAnimation(Colors.blue[400]),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
