import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';

import 'package:frontend/models/message_model.dart';
import 'package:frontend/services/media_service.dart';
import 'package:frontend/services/signaling_service.dart';
import 'package:frontend/services/webrtc_service.dart';

class CallController extends StateNotifier<CallState> {
  CallController() : super(CallState.initial()) {
    webrtcService = WebrtcService();
    _clientId = const Uuid().v4();
    state = state.copyWith(clientId: _clientId);
  }

  // Services
  late MediaService mediaService;
  late WebrtcService webrtcService;
  late SignalingService signalingService;

  final String _wsUrl = kIsWeb
      ? 'ws://localhost:8081/ws'
      : 'ws://localhost:8081/ws';

  bool _initialized = false;
  bool _cameraInitialized = false;
  late String _clientId;
  Completer<void>? _roomResponseCompleter;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    try {
      print('=== INIT START ===');
      print('Client ID: ${_clientId.substring(0, 8)}...');

      // Request permissions
      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
        print('Requesting permissions...');
        await _requestPermissions();
      }

      // Initialize services
      print('Initializing WebRTC service...');
      await webrtcService.initRenderers();

      // Initialize signaling
      print('Initializing Signaling service...');
      signalingService = SignalingService();

      await signalingService.connect(
        _wsUrl,
        _clientId,
        _handleSignalingMessage,
        _handleSignalingError,
      );

      print('=== INIT DONE ===');
    } catch (e) {
      print('Initialization error: $e');
    }
  }

  Future<void> _requestPermissions() async {
    final cameraStatus = await Permission.camera.request();
    final micStatus = await Permission.microphone.request();

    if (cameraStatus.isDenied || micStatus.isDenied) {
      print('Permissions denied');
    } else if (cameraStatus.isPermanentlyDenied ||
        micStatus.isPermanentlyDenied) {
      print('Permissions permanently denied, opening app settings');
      openAppSettings();
    }
  }

  Future<void> initializeCamera() async {
    if (_cameraInitialized) return;
    _cameraInitialized = true;

    try {
      print('Initializing Media service...');
      mediaService = MediaService();
      await mediaService.startMedia();

      // Set local stream to renderer
      webrtcService.localRenderer.srcObject = mediaService.localStream;
      print('Camera initialized');
    } catch (e) {
      print('Error initializing camera: $e');
      _cameraInitialized = false;
      rethrow;
    }
  }

  Future<void> stopCamera() async {
    if (!_cameraInitialized) return;
    _cameraInitialized = false;

    try {
      print('Stopping camera...');
      mediaService.dispose();
      webrtcService.localRenderer.srcObject = null;
      print('Camera stopped');
    } catch (e) {
      print('Error stopping camera: $e');
    }
  }

  void _handleSignalingMessage(SignalingMessage msg) {
    print('=== MESSAGE RECEIVED ===');
    print('Type: ${msg.type}, From: ${msg.from}');

    switch (msg.type) {
      case 'peer-list':
        final peers = List<String>.from(msg.payload ?? []);
        state = state.copyWith(availablePeers: peers);
        print('Available peers: $peers');
        break;

      // Peer notifications from legacy system or room system
      case 'peer-joined':
        // Check if it's from room system (has 'peerId') or legacy (has 'id')
        final peerId =
            msg.payload['peerId'] as String? ?? msg.payload['id'] as String?;
        if (peerId != null) {
          if (state.roomId.isNotEmpty) {
            // Room system: peer joined the room
            final peerCount = msg.payload['peerCount'] as int? ?? 2;
            state = state.copyWith(
              connectedPeerId: peerId,
              peerCount: peerCount,
            );
            print(
              'Peer joined room: ${peerId.substring(0, 8)}... (total: $peerCount)',
            );
            print(
              'DEBUG peer-joined: isCallActive=${state.isCallActive}, connectedPeerId=${state.connectedPeerId}',
            );

            // Automatically initiate call when peer joins
            if (peerId.isNotEmpty && !state.isCallActive) {
              print(
                'Auto-initiating call with peer: ${peerId.substring(0, 8)}...',
              );
              callPeer(peerId);
            } else {
              print(
                'Auto-call conditions NOT met: peerId.isEmpty=${peerId.isEmpty}, isCallActive=${state.isCallActive}',
              );
            }
          } else {
            // Legacy system: peer available
            if (!state.availablePeers.contains(peerId)) {
              final updatedPeers = [...state.availablePeers, peerId];
              state = state.copyWith(availablePeers: updatedPeers);
            }
            print('Peer joined: ${peerId.substring(0, 8)}...');
          }
        }
        break;

      case 'peer-left':
        final peerId =
            msg.payload['peerId'] as String? ?? msg.payload['id'] as String?;
        if (peerId != null) {
          if (state.roomId.isNotEmpty) {
            // Room system: peer left the room
            print('Peer left room: ${peerId.substring(0, 8)}...');
            if (state.connectedPeerId == peerId) {
              endCall();
              state = state.copyWith(connectedPeerId: '', peerCount: 1);
            }
          } else {
            // Legacy system
            final updatedPeers = state.availablePeers
                .where((id) => id != peerId)
                .toList();
            state = state.copyWith(availablePeers: updatedPeers);
            print('Peer left: ${peerId.substring(0, 8)}...');
          }
        }
        break;

      // Room system messages
      case 'room-created':
        final roomId = msg.payload['roomId'] as String;
        state = state.copyWith(roomId: roomId, peerCount: 1);
        print('Room created: ${roomId.substring(0, 8)}...');
        _roomResponseCompleter?.complete();
        _roomResponseCompleter = null;
        break;

      case 'room-joined':
        final roomId = msg.payload['roomId'] as String;
        final peerCount = msg.payload['peerCount'] as int;

        // Получаем ID другого пира в комнате
        final connectedPeer = msg.payload['connectedPeer'] as String? ?? '';

        state = state.copyWith(
          roomId: roomId,
          peerCount: peerCount,
          connectedPeerId: connectedPeer,
        );

        print(
          'Joined room: ${roomId.substring(0, 8)}..., Peers: $peerCount, Connected: ${connectedPeer.isEmpty ? "waiting" : connectedPeer.substring(0, 8)}',
        );
        print(
          'DEBUG room-joined: connectedPeer=$connectedPeer, isCallActive=${state.isCallActive}',
        );

        // Automatically initiate call if peer is already in room
        if (connectedPeer.isNotEmpty && !state.isCallActive) {
          print(
            'Auto-initiating call with existing peer: ${connectedPeer.substring(0, 8)}...',
          );
          callPeer(connectedPeer);
        } else {
          print(
            'Auto-call skipped: connectedPeer.isEmpty=${connectedPeer.isEmpty}, isCallActive=${state.isCallActive}',
          );
        }

        _roomResponseCompleter?.complete();
        _roomResponseCompleter = null;
        break;

      case 'room-error':
        final error = msg.payload['error'] as String;
        print('Room error: $error');
        state = state.copyWith(lastError: error);
        _roomResponseCompleter?.completeError(error);
        _roomResponseCompleter = null;
        break;

      case 'offer':
        _handleOffer(msg.payload, msg.from!);
        break;

      case 'answer':
        _handleAnswer(msg.payload, msg.from!);
        break;

      case 'ice-candidate':
        _handleIceCandidate(msg.payload);
        break;

      case 'chat':
        print('========== CHAT MESSAGE RECEIVED ==========');
        print('From: ${msg.from}');
        print('Payload: ${msg.payload}');
        print('My ID: $_clientId');
        print('Is own? ${msg.from == _clientId}');
        state = state.copyWith(messages: [...state.messages, msg]);
        print('Total messages: ${state.messages.length}');
        break;
    }
  }

  void _handleSignalingError(String error) {
    print('Error: $error');
  }

  void listPeers() {
    signalingService.sendMessage(SignalingMessage(type: 'list-peers'));
  }

  Future<void> createRoom() async {
    print('Creating room...');
    print('DEBUG: signalingService initialized? ${signalingService != null}');

    if (signalingService == null) {
      print('❌ ERROR: signalingService not initialized!');
      throw Exception('Signaling service not initialized');
    }

    _roomResponseCompleter = Completer<void>();
    print('DEBUG: Sending create-room message...');
    signalingService.sendMessage(SignalingMessage(type: 'create-room'));
    print('DEBUG: Waiting for room-created response...');

    try {
      await _roomResponseCompleter!.future.timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          throw Exception('Room creation timeout - no response from server');
        },
      );
      print('✅ Room created successfully');
    } catch (e) {
      print('❌ Room creation failed: $e');
      rethrow;
    }
  }

  Future<void> joinRoom(String roomId) async {
    print('Joining room: ${roomId.substring(0, 8)}...');
    _roomResponseCompleter = Completer<void>();
    signalingService.sendMessage(
      SignalingMessage(type: 'join-room', payload: {'roomId': roomId}),
    );
    await _roomResponseCompleter!.future;
  }

  Future<void> leaveRoom() async {
    print('Leaving room...');

    // End call first
    endCall();

    // Stop camera
    await stopCamera();

    // Send leave-room message
    signalingService.sendMessage(SignalingMessage(type: 'leave-room'));

    // Reset state
    state = state.copyWith(
      roomId: '',
      peerCount: 0,
      connectedPeerId: '',
      isCallActive: false,
    );

    print('Left room');
  }

  void callPeer(String peerId) async {
    print('========== CALL PEER START ==========');
    print('Peer ID: ${peerId.substring(0, 8)}...');

    if (webrtcService.peerConnection != null) {
      print('❌ Call already in progress');
      return;
    }

    print('Calling peer: $peerId');
    state = state.copyWith(connectedPeerId: peerId);

    try {
      // Ensure camera is initialized before starting call
      if (!_cameraInitialized) {
        print('⏳ Waiting for camera initialization...');
        await initializeCamera();
        print('✅ Camera initialized');
      } else {
        print('✅ Camera already initialized');
      }

      // Ensure we have a local stream
      if (mediaService.localStream == null) {
        print('❌ ERROR: Local stream not available');
        return;
      }
      print('✅ Local stream available');

      print('Initializing peer connection...');
      await webrtcService.initPeerConnection(
        (description) {
          // Send local description to peer
          final payload = {'type': description.type, 'sdp': description.sdp};

          signalingService.sendMessage(
            SignalingMessage(
              type: description.type == 'offer' ? 'offer' : 'answer',
              to: peerId,
              payload: payload,
            ),
          );
        },
        (candidate) {
          // Send ICE candidate to peer
          final payload = {
            'candidate': candidate.candidate,
            'sdpMid': candidate.sdpMid,
            'sdpMLineIndex': candidate.sdpMLineIndex,
          };

          signalingService.sendMessage(
            SignalingMessage(
              type: 'ice-candidate',
              to: peerId,
              payload: payload,
            ),
          );
        },
      );

      print('Adding local stream...');
      await webrtcService.addStream(mediaService.localStream!);
      print('✅ Local stream added');

      print('Creating offer...');
      final offer = await webrtcService.createOffer();
      print('✅ Offer created: ${offer.type}');

      final payload = {'type': offer.type, 'sdp': offer.sdp};

      print('Sending offer to peer...');
      signalingService.sendMessage(
        SignalingMessage(type: 'offer', to: peerId, payload: payload),
      );
      print('✅ Offer sent to ${peerId.substring(0, 8)}...');

      state = state.copyWith(isCallActive: true);

      print('========== CALL PEER END - SUCCESS ==========');
    } catch (e) {
      print('❌ Error initiating call: $e');
      state = state.copyWith(connectedPeerId: '');
    }
  }

  void _handleOffer(dynamic payload, String fromPeerId) async {
    if (webrtcService.peerConnection != null) {
      print('Already in a call');
      return;
    }

    print('========== HANDLING OFFER ==========');
    print('Received offer from: "$fromPeerId"');

    state = state.copyWith(connectedPeerId: fromPeerId);

    try {
      await webrtcService.initPeerConnection(
        (description) {
          final payload = {'type': description.type, 'sdp': description.sdp};

          signalingService.sendMessage(
            SignalingMessage(
              type: description.type == 'offer' ? 'offer' : 'answer',
              to: fromPeerId,
              payload: payload,
            ),
          );
        },
        (candidate) {
          final payload = {
            'candidate': candidate.candidate,
            'sdpMid': candidate.sdpMid,
            'sdpMLineIndex': candidate.sdpMLineIndex,
          };

          signalingService.sendMessage(
            SignalingMessage(
              type: 'ice-candidate',
              to: fromPeerId,
              payload: payload,
            ),
          );
        },
      );

      await webrtcService.addStream(mediaService.localStream!);

      final sdp = payload['sdp'] as String;
      final type = payload['type'] as String;

      await webrtcService.setRemoteDescription(sdp, type);

      final answer = await webrtcService.createAnswer();

      final answerPayload = {'type': answer.type, 'sdp': answer.sdp};

      signalingService.sendMessage(
        SignalingMessage(
          type: 'answer',
          to: fromPeerId,
          payload: answerPayload,
        ),
      );

      state = state.copyWith(isCallActive: true);

      print('Sent answer to $fromPeerId');
    } catch (e) {
      print('Error handling offer: $e');
    }
  }

  void _handleAnswer(dynamic payload, String fromPeerId) async {
    print('========== HANDLING ANSWER ==========');
    print('Received answer from: "$fromPeerId"');

    try {
      final sdp = payload['sdp'] as String;
      final type = payload['type'] as String;

      await webrtcService.setRemoteDescription(sdp, type);

      print('Answer applied successfully');
    } catch (e) {
      print('Error handling answer: $e');
    }
  }

  void _handleIceCandidate(dynamic payload) async {
    try {
      await webrtcService.addIceCandidate(payload);
    } catch (e) {
      print('Error handling ICE candidate: $e');
    }
  }

  void endCall() {
    try {
      webrtcService.closePeerConnection();
      webrtcService.remoteRenderer.srcObject = null;

      state = state.copyWith(isCallActive: false, connectedPeerId: '');

      print('Call ended');
    } catch (e) {
      print('Error ending call: $e');
    }
  }

  void toggleMicrophone() {
    mediaService.toggleMicrophone(!state.isMicrophoneEnabled);

    state = state.copyWith(isMicrophoneEnabled: !state.isMicrophoneEnabled);

    print('Microphone ${state.isMicrophoneEnabled ? 'enabled' : 'disabled'}');
  }

  void sendMessage(String text) {
    if (text.isEmpty) return;

    print('========== SENDING MESSAGE ==========');
    print('Text: $text');
    print('My ID: $_clientId');

    // Send to server (server will broadcast back with From field set properly)
    signalingService.sendMessage(SignalingMessage(type: 'chat', payload: text));

    print('✅ Message sent to server, waiting for broadcast response...');
  }

  @override
  void dispose() {
    try {
      print('=== DISPOSING CALL CONTROLLER ===');

      // End current call if active
      if (state.isCallActive) {
        endCall();
      }

      // Stop camera if initialized
      if (_cameraInitialized) {
        mediaService.dispose();
      }

      // Close peer connection
      webrtcService.dispose();

      // Disconnect from signaling server
      signalingService.disconnect();

      print('=== CALL CONTROLLER DISPOSED ===');
    } catch (e) {
      print('Error during dispose: $e');
    }
    super.dispose();
  }
}

class CallState {
  // id strings
  final String clientId;
  final String connectedPeerId;
  final List<String> availablePeers;
  // room info
  final String roomId;
  final int peerCount;
  // bool control
  final bool isCallActive;
  final bool isMicrophoneEnabled;
  // error handling
  final String? lastError;
  // chat
  final List<SignalingMessage> messages;

  CallState({
    required this.clientId,
    required this.connectedPeerId,
    required this.availablePeers,
    required this.roomId,
    required this.peerCount,
    required this.isCallActive,
    required this.isMicrophoneEnabled,
    this.lastError,
    required this.messages,
  });

  factory CallState.initial() {
    return CallState(
      clientId: '',
      connectedPeerId: '',
      availablePeers: [],
      roomId: '',
      peerCount: 0,
      isCallActive: false,
      isMicrophoneEnabled: true,
      lastError: null,
      messages: [],
    );
  }

  CallState copyWith({
    String? clientId,
    String? connectedPeerId,
    List<String>? availablePeers,
    String? roomId,
    int? peerCount,
    bool? isCallActive,
    bool? isMicrophoneEnabled,
    String? lastError,
    List<SignalingMessage>? messages,
  }) {
    return CallState(
      clientId: clientId ?? this.clientId,
      connectedPeerId: connectedPeerId ?? this.connectedPeerId,
      availablePeers: availablePeers ?? this.availablePeers,
      roomId: roomId ?? this.roomId,
      peerCount: peerCount ?? this.peerCount,
      isCallActive: isCallActive ?? this.isCallActive,
      isMicrophoneEnabled: isMicrophoneEnabled ?? this.isMicrophoneEnabled,
      lastError: lastError,
      messages: messages ?? this.messages,
    );
  }
}

// Провайдер для CallController
final callControllerProvider = StateNotifierProvider<CallController, CallState>(
  (ref) {
    return CallController();
  },
);

// Провайдер для инициализации
final callInitProvider = FutureProvider<void>((ref) async {
  final controller = ref.watch(callControllerProvider.notifier);
  await controller.init();
});

// Провайдеры для отдельных состояний (удобно для read/fetch в виджетах)
final clientIdProvider = Provider<String>((ref) {
  return ref.watch(callControllerProvider).clientId;
});

final connectedPeerIdProvider = Provider<String>((ref) {
  return ref.watch(callControllerProvider).connectedPeerId;
});

final availablePeersProvider = Provider<List<String>>((ref) {
  return ref.watch(callControllerProvider).availablePeers;
});

final isCallActiveProvider = Provider<bool>((ref) {
  return ref.watch(callControllerProvider).isCallActive;
});

final isMicrophoneEnabledProvider = Provider<bool>((ref) {
  return ref.watch(callControllerProvider).isMicrophoneEnabled;
});

final messagesProvider = Provider<List<SignalingMessage>>((ref) {
  return ref.watch(callControllerProvider).messages;
});
