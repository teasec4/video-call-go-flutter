import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:permission_handler/permission_handler.dart';

import 'screens/home_screen.dart';
import 'services/media_service.dart';
import 'services/webrtc_service.dart';
import 'services/signaling_service.dart';
import 'models/message_model.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Video Call',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.grey),
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  // Services
  late MediaService mediaService;
  late WebrtcService webrtcService;
  late SignalingService signalingService;

  // State
  String _clientId = '';
  String _connectedPeerId = '';
  List<String> _availablePeers = [];
  bool _isCallActive = false;
  bool _isMicrophoneEnabled = true;
  final List<SignalingMessage> messages = [];
  final TextEditingController controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
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

      final wsUrl = kIsWeb
          ? 'ws://localhost:8081/ws'
          : 'wss://2221b5c37f6b.ngrok-free.app/ws';

      await signalingService.connect(
        wsUrl,
        _handleSignalingMessage,
        _handleSignalingError,
      );

      print('=== INIT DONE ===');
    } catch (e) {
      print('Initialization error: $e');
      _addMessage('Initialization failed: $e');
    }
  }

  Future<void> _requestPermissions() async {
    final cameraStatus = await Permission.camera.request();
    final micStatus = await Permission.microphone.request();

    if (cameraStatus.isDenied || micStatus.isDenied) {
      print('Permissions denied');
      _addMessage('Camera/Microphone permissions denied');
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
        setState(() {
          _clientId = msg.payload['id'] as String;
          _addMessage('Connected as: ${_clientId.substring(0, 8)}...');
        });
        _listPeers();
        break;

      case 'peer-list':
        final peers = List<String>.from(msg.payload ?? []);
        setState(() {
          _availablePeers = peers;
        });
        print('Available peers: $peers');
        break;

      case 'peer-joined':
        final peerId = msg.payload['id'] as String;
        setState(() {
          if (!_availablePeers.contains(peerId)) {
            _availablePeers.add(peerId);
          }
        });
        _addMessage('Peer joined: ${peerId.substring(0, 8)}...');
        break;

      case 'peer-left':
        final peerId = msg.payload['id'] as String;
        setState(() {
          _availablePeers.remove(peerId);
        });
        _addMessage('Peer left: ${peerId.substring(0, 8)}...');
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
        // make up chat logic
        setState(() {
          messages.add(msg);
        });
          break;
    }
  }

  void _handleSignalingError(String error) {
    _addMessage('Error: $error');
  }

  void _listPeers() {
    signalingService.sendMessage(SignalingMessage(type: 'list-peers'));
  }

  void _callPeer(String peerId) async {
    if (webrtcService.peerConnection != null) {
      _addMessage('Call already in progress');
      return;
    }

    print('Calling peer: $peerId');
    setState(() {
      _connectedPeerId = peerId;
    });

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

      setState(() {
        _isCallActive = true;
      });

      _addMessage('Call initiated with ${peerId.substring(0, 8)}...');
    } catch (e) {
      print('Error initiating call: $e');
      _addMessage('Error initiating call: $e');
      setState(() {
        _connectedPeerId = '';
      });
    }
  }

  void _handleOffer(dynamic payload, String fromPeerId) async {
    if (webrtcService.peerConnection != null) {
      print('Already in a call');
      return;
    }

    print('========== HANDLING OFFER ==========');
    print('Received offer from: "$fromPeerId"');

    setState(() {
      _connectedPeerId = fromPeerId;
    });

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

      setState(() {
        _isCallActive = true;
      });

      print('Sent answer to $fromPeerId');
    } catch (e) {
      print('Error handling offer: $e');
      _addMessage('Error handling offer: $e');
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
      _addMessage('Error handling answer: $e');
    }
  }

  void _handleIceCandidate(dynamic payload) async {
    try {
      await webrtcService.addIceCandidate(payload);
    } catch (e) {
      print('Error handling ICE candidate: $e');
    }
  }

  void _endCall() {
    webrtcService.closePeerConnection();
    webrtcService.remoteRenderer.srcObject = null;

    setState(() {
      _isCallActive = false;
      _connectedPeerId = '';
    });

    _addMessage('Call ended');
    _listPeers();
  }

  void _toggleMicrophone() {
    mediaService.toggleMicrophone(!_isMicrophoneEnabled);

    setState(() {
      _isMicrophoneEnabled = !_isMicrophoneEnabled;
    });

    _addMessage('Microphone ${_isMicrophoneEnabled ? 'enabled' : 'disabled'}');
  }

  void _addMessage(String msg) {
    print(msg);
  }

  void sendMessage() {
    if (controller.text.isEmpty) return;

    signalingService.sendMessage(
      SignalingMessage(type: 'chat', payload: controller.text),
    );

    controller.clear();
  }

  @override
  void dispose() {
    signalingService.disconnect();
    mediaService.dispose();
    webrtcService.dispose();
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return HomeScreen(
      localRenderer: webrtcService.localRenderer,
      remoteRenderer: webrtcService.remoteRenderer,
      renderersInitialized: true,
      isCallActive: _isCallActive,
      isMicrophoneEnabled: _isMicrophoneEnabled,
      availablePeers: _availablePeers,
      messages: messages,
      messageController: controller,
      onSendMessage: sendMessage,
      onCallPeer: _callPeer,
      onToggleMicrophone: _toggleMicrophone,
      onEndCall: _endCall,
      myId: _clientId,
    );
  }
}
