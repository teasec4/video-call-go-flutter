import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';

import 'package:frontend/models/message_model.dart';
import 'package:frontend/models/webrtc_state.dart';
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

  // WebRTC состояние - единая точка управления соединением
  WebRTCState _webrtcState = WebRTCState.idle();

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
    print('Type: ${msg.type}, From: ${msg.from}, To: ${msg.to}');
    if (msg.payload != null && msg.payload is Map) {
      print('Payload keys: ${(msg.payload as Map).keys}');
    }

    // Room-related messages need to be handled synchronously for completers
    if (msg.type == 'room-created' ||
        msg.type == 'room-joined' ||
        msg.type == 'room-error') {
      _handleRoomMessage(msg);
    } else {
      // Handle async operations in background for other messages
      _processSignalingMessage(msg);
    }
  }

  void _handleRoomMessage(SignalingMessage msg) {
    switch (msg.type) {
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
    }
  }

  Future<void> _processSignalingMessage(SignalingMessage msg) async {
    try {
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

        case 'offer':
          await _handleOffer(msg.payload, msg.from!);
          break;

        case 'answer':
          await _handleAnswer(msg.payload, msg.from!);
          break;

        case 'ice-candidate':
          await _handleIceCandidate(msg.payload);
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
    } catch (e) {
      print('Error processing signaling message: $e');
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
    print('DEBUG: Full room ID: $roomId');
    _roomResponseCompleter = Completer<void>();
    final msg = SignalingMessage(type: 'join-room', payload: {'roomId': roomId});
    print('DEBUG: Sending join-room message with payload: ${msg.payload}');
    signalingService.sendMessage(msg);
    
    try {
      await _roomResponseCompleter!.future.timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          throw Exception('Join room timeout - no response from server');
        },
      );
      print('✅ Room joined successfully');
    } catch (e) {
      print('❌ Room join failed: $e');
      state = state.copyWith(lastError: e.toString());
      rethrow;
    }
  }

  Future<void> leaveRoom() async {
    print('========== LEAVING ROOM ==========');

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

    print('✅ Left room');
  }

  void callPeer(String peerId) async {
    print('========== CALL PEER START ==========');
    print('Peer ID: ${peerId.substring(0, 8)}...');
    print('Current WebRTC state: ${_webrtcState.phase}, connectedWith: ${_webrtcState.connectedWith}');

    // Проверка: можем ли мы инициировать соединение?
    if (!_webrtcState.canInitiateCall()) {
      print('❌ Cannot initiate call. Current state: ${_webrtcState.phase}');
      return;
    }
    
    // Дополнительная проверка: если это другой пир, отклоняем
    if (_webrtcState.connectedWith != null && _webrtcState.connectedWith != peerId) {
      print('❌ Already connected to different peer: ${_webrtcState.connectedWith}');
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

      print('Initializing peer connection (initiator)...');
      await webrtcService.initPeerConnection(
        (description) {
          print('>>> LOCAL DESCRIPTION CALLBACK: ${description.type}');
          // Send local description to peer
          final payload = {'type': description.type, 'sdp': description.sdp};

          signalingService.sendMessage(
            SignalingMessage(
              type: description.type == 'offer' ? 'offer' : 'answer',
              from: _clientId,
              to: peerId,
              payload: payload,
            ),
          );
          print(
            '>>> Sent ${description.type} to ${peerId.substring(0, 8)}',
          );
        },
        (candidate) {
          print('>>> ICE CANDIDATE CALLBACK from ${peerId.substring(0, 8)}');
          // Send ICE candidate to peer
          final payload = {
            'candidate': candidate.candidate,
            'sdpMid': candidate.sdpMid,
            'sdpMLineIndex': candidate.sdpMLineIndex,
          };

          signalingService.sendMessage(
            SignalingMessage(
              type: 'ice-candidate',
              from: _clientId,
              to: peerId,
              payload: payload,
            ),
          );
        },
      );

      // Обновляем состояние: соединение инициировано
      _webrtcState = _webrtcState.connectingTo(
        peerId,
        webrtcService.peerConnection!,
      );

      print('Adding local stream...');
      await webrtcService.addStream(mediaService.localStream!);
      _webrtcState = _webrtcState.withLocalStreamAdded();
      print('✅ Local stream added');

      print('Creating offer...');
      final offer = await webrtcService.createOffer();
      _webrtcState = _webrtcState.withLocalDescription(offer);
      print('✅ Offer created: ${offer.type}');
      // Note: Offer is sent via callback in webrtcService.createOffer()

      state = state.copyWith(isCallActive: true);

      print('========== CALL PEER END - SUCCESS ==========');
    } catch (e) {
      print('❌ Error initiating call: $e');
      _webrtcState = _webrtcState.withError(e.toString());
      state = state.copyWith(connectedPeerId: '');
    }
  }

  Future<void> _handleOffer(dynamic payload, String fromPeerId) async {
    print('========== HANDLING OFFER ==========');
    print('Received offer from: "$fromPeerId"');
    print('Current WebRTC state: ${_webrtcState.phase}, connectedWith: ${_webrtcState.connectedWith}');

    // Проверка: если мы уже в процессе инициации с этим же пиром
    // то это может быть race condition - игнорируем
    if (_webrtcState.phase == WebRTCPhase.connecting &&
        _webrtcState.connectedWith == fromPeerId &&
        _webrtcState.isInitiator) {
      print('⚠️  Race condition detected: Already initiating call with this peer, ignoring incoming offer');
      return;
    }

    // Проверка: можем ли мы ответить на offer?
    if (!_webrtcState.canAnswerOffer()) {
      print('❌ Cannot answer offer. Current state: ${_webrtcState.phase}');
      return;
    }

    state = state.copyWith(connectedPeerId: fromPeerId);

    try {
      // Убедимся что камера инициализирована
      if (!_cameraInitialized) {
        print('⏳ Initializing camera for incoming call...');
        await initializeCamera();
      }

      // Убедимся что есть локальный поток
      if (mediaService.localStream == null) {
        print('❌ ERROR: Local stream not available for answering');
        return;
      }

      print('Initializing peer connection (answerer)...');
      await webrtcService.initPeerConnection(
        (description) {
          print('>>> LOCAL DESCRIPTION CALLBACK (answer): ${description.type}');
          final payload = {'type': description.type, 'sdp': description.sdp};

          signalingService.sendMessage(
            SignalingMessage(
              type: description.type == 'offer' ? 'offer' : 'answer',
              from: _clientId,
              to: fromPeerId,
              payload: payload,
            ),
          );
          print(
            '>>> Sent answer to ${fromPeerId.substring(0, 8)}',
          );
        },
        (candidate) {
          print(
            '>>> ICE CANDIDATE CALLBACK (answer) from ${fromPeerId.substring(0, 8)}',
          );
          final payload = {
            'candidate': candidate.candidate,
            'sdpMid': candidate.sdpMid,
            'sdpMLineIndex': candidate.sdpMLineIndex,
          };

          signalingService.sendMessage(
            SignalingMessage(
              type: 'ice-candidate',
              from: _clientId,
              to: fromPeerId,
              payload: payload,
            ),
          );
        },
      );

      // Обновляем состояние: мы ответили на offer
      _webrtcState = _webrtcState.answeringTo(
        fromPeerId,
        webrtcService.peerConnection!,
      );

      print('Adding local stream for answer...');
      await webrtcService.addStream(mediaService.localStream!);
      _webrtcState = _webrtcState.withLocalStreamAdded();
      print('✅ Local stream added');

      final sdp = payload['sdp'] as String;
      final type = payload['type'] as String;

      print('Setting remote description (offer)...');
      await webrtcService.setRemoteDescription(sdp, type);
      _webrtcState = _webrtcState.withRemoteDescription(
        RTCSessionDescription(sdp, type),
      );
      print('✅ Remote description set');

      print('Creating answer...');
      final answer = await webrtcService.createAnswer();
      _webrtcState = _webrtcState.withLocalDescription(answer);
      print('✅ Answer created: ${answer.type}');
      // Note: Answer is sent via callback in webrtcService.createAnswer()

      state = state.copyWith(isCallActive: true);

      print('========== HANDLING OFFER - SUCCESS ==========');
    } catch (e) {
      print('❌ Error handling offer: $e');
      _webrtcState = _webrtcState.withError(e.toString());
    }
  }

  Future<void> _handleAnswer(dynamic payload, String fromPeerId) async {
    print('========== HANDLING ANSWER ==========');
    print('Received answer from: "$fromPeerId"');
    print('Current WebRTC state: ${_webrtcState.phase}');

    try {
      final sdp = payload['sdp'] as String;
      final type = payload['type'] as String;

      print('Setting remote description (answer)...');
      await webrtcService.setRemoteDescription(sdp, type);
      _webrtcState = _webrtcState.withRemoteDescription(
        RTCSessionDescription(sdp, type),
      );

      // Соединение теперь установлено когда обе стороны обменялись descriptions
      _webrtcState = _webrtcState.connected();

      print('✅ Answer applied successfully');
      print('========== HANDLING ANSWER - SUCCESS ==========');
    } catch (e) {
      print('❌ Error handling answer: $e');
      _webrtcState = _webrtcState.withError(e.toString());
    }
  }

  Future<void> _handleIceCandidate(dynamic payload) async {
    try {
      await webrtcService.addIceCandidate(payload);
    } catch (e) {
      print('Error handling ICE candidate: $e');
    }
  }

  void endCall() {
    print('========== ENDING CALL ==========');
    try {
      webrtcService.closePeerConnection();
      webrtcService.remoteRenderer.srcObject = null;

      // Сбрасываем WebRTC состояние в idle
      _webrtcState = WebRTCState.idle();

      state = state.copyWith(isCallActive: false, connectedPeerId: '');

      print('✅ Call ended, state reset to idle');
    } catch (e) {
      print('❌ Error ending call: $e');
      _webrtcState = _webrtcState.withError(e.toString());
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

      // Reset WebRTC state
      _webrtcState = WebRTCState.idle();

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
