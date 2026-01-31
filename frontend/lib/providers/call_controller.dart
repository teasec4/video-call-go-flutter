import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:frontend/models/message_model.dart';
import 'package:frontend/services/media_service.dart';
import 'package:frontend/services/signaling_service.dart';
import 'package:frontend/services/webrtc_service.dart';

class CallController extends StateNotifier<CallState> {
  CallController() : super(CallState.initial());

  // Services
  late MediaService mediaService;
  late WebrtcService webrtcService;
  late SignalingService signalingService;

  final String _wsUrl = kIsWeb
      ? 'ws://localhost:8081/ws'
      : 'ws://localhost:8081/ws';
  
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    try {
      print('=== INIT START ===');

      // Request permissions
      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
        print('Requesting permissions...');
        await _requestPermissions();
      }

      // Initialize services
      print('Initializing WebRTC service...');
      webrtcService = WebrtcService();
      await webrtcService.initRenderers();

      print('Initializing Media service...');
      mediaService = MediaService();
      await mediaService.startMedia();

      // Set local stream to renderer
      webrtcService.localRenderer.srcObject = mediaService.localStream;

      // Initialize signaling
      print('Initializing Signaling service...');
      signalingService = SignalingService();

      await signalingService.connect(
        _wsUrl,
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

  void _handleSignalingMessage(SignalingMessage msg) {
    print('=== MESSAGE RECEIVED ===');
    print('Type: ${msg.type}, From: ${msg.from}');

    switch (msg.type) {
      case 'client-id':
        state = state.copyWith(clientId: msg.payload['id'] as String);
        print('Connected as: ${state.clientId.substring(0, 8)}...');
        listPeers();
        break;

      case 'peer-list':
        final peers = List<String>.from(msg.payload ?? []);
        state = state.copyWith(availablePeers: peers);
        print('Available peers: $peers');
        break;

      case 'peer-joined':
        final peerId = msg.payload['id'] as String;
        if (!state.availablePeers.contains(peerId)) {
          final updatedPeers = [...state.availablePeers, peerId];
          state = state.copyWith(availablePeers: updatedPeers);
        }
        print('Peer joined: ${peerId.substring(0, 8)}...');
        break;

      case 'peer-left':
        final peerId = msg.payload['id'] as String;
        final updatedPeers = state.availablePeers
            .where((id) => id != peerId)
            .toList();
        state = state.copyWith(availablePeers: updatedPeers);
        print('Peer left: ${peerId.substring(0, 8)}...');
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
        state = state.copyWith(
          messages: [...state.messages, msg],
        );
        break;
    }
  }

  void _handleSignalingError(String error) {
    print('Error: $error');
  }

  void listPeers() {
    signalingService.sendMessage(SignalingMessage(type: 'list-peers'));
  }

  void callPeer(String peerId) async {
    if (webrtcService.peerConnection != null) {
      print('Call already in progress');
      return;
    }

    print('Calling peer: $peerId');
    state = state.copyWith(connectedPeerId: peerId);

    try {
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

      webrtcService.addStream(mediaService.localStream!);

      final offer = await webrtcService.createOffer();

      final payload = {'type': offer.type, 'sdp': offer.sdp};

      signalingService.sendMessage(
        SignalingMessage(type: 'offer', to: peerId, payload: payload),
      );

      state = state.copyWith(isCallActive: true);

      print('Call initiated with ${peerId.substring(0, 8)}...');
    } catch (e) {
      print('Error initiating call: $e');
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

      webrtcService.addStream(mediaService.localStream!);

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
    webrtcService.closePeerConnection();
    webrtcService.remoteRenderer.srcObject = null;

    state = state.copyWith(
      isCallActive: false,
      connectedPeerId: '',
    );

    print('Call ended');
    listPeers();
  }

  void toggleMicrophone() {
    mediaService.toggleMicrophone(!state.isMicrophoneEnabled);

    state = state.copyWith(
      isMicrophoneEnabled: !state.isMicrophoneEnabled,
    );

    print('Microphone ${state.isMicrophoneEnabled ? 'enabled' : 'disabled'}');
  }

  void sendMessage(String text) {
    if (text.isEmpty) return;

    signalingService.sendMessage(
      SignalingMessage(type: 'chat', payload: text),
    );
  }

  @override
  void dispose() {
    signalingService.disconnect();
    mediaService.dispose();
    webrtcService.dispose();
    super.dispose();
  }
}

class CallState {
  // id strings
  final String clientId;
  final String connectedPeerId;
  final List<String> availablePeers;
  // bool control
  final bool isCallActive;
  final bool isMicrophoneEnabled;
  // chat
  final List<SignalingMessage> messages;

  CallState({
    required this.clientId,
    required this.connectedPeerId,
    required this.availablePeers,
    required this.isCallActive,
    required this.isMicrophoneEnabled,
    required this.messages,
  });

  factory CallState.initial() {
    return CallState(
      clientId: '',
      connectedPeerId: '',
      availablePeers: [],
      isCallActive: false,
      isMicrophoneEnabled: true,
      messages: [],
    );
  }

  CallState copyWith({
    String? clientId,
    String? connectedPeerId,
    List<String>? availablePeers,
    bool? isCallActive,
    bool? isMicrophoneEnabled,
    List<SignalingMessage>? messages,
  }) {
    return CallState(
      clientId: clientId ?? this.clientId,
      connectedPeerId: connectedPeerId ?? this.connectedPeerId,
      availablePeers: availablePeers ?? this.availablePeers,
      isCallActive: isCallActive ?? this.isCallActive,
      isMicrophoneEnabled: isMicrophoneEnabled ?? this.isMicrophoneEnabled,
      messages: messages ?? this.messages,
    );
  }
}

// Провайдер для CallController
final callControllerProvider =
    StateNotifierProvider<CallController, CallState>((ref) {
  return CallController();
});

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
