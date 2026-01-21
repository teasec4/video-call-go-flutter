import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

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
  late WebSocketChannel channel;
  final TextEditingController controller = TextEditingController();
  final List<String> messages = [];

  // WebRTC
  late final RTCVideoRenderer _localRenderer;
  late final RTCVideoRenderer _remoteRenderer;
  bool _renderersInitialized = false;
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;

  String _clientId = '';
  String _connectedPeerId = '';
  List<String> _availablePeers = [];
  bool _isCallActive = false;

  // Buffer for ICE candidates that arrive before remote description is set
  List<RTCIceCandidate> _iceCandidateBuffer = [];

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      print('=== INIT START ===');
      // Request permissions for camera and microphone (not needed on web)
      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
        print('Requesting permissions...');
        await _requestPermissions();
      } else {
        print('Skipping permissions (web platform)');
      }

      print('Initializing renderers...');
      await _initRenderers();
      print('Starting camera...');
      await _startCamera();
      print('=== INIT DONE ===');
    } catch (e) {
      print('Initialization error: $e');
      _addMessage('Initialization failed: $e');
    }

    // Choose URL based on platform
    final wsUrl = kIsWeb 
        ? 'ws://localhost:8081/ws'
        : 'wss://2221b5c37f6b.ngrok-free.app/ws';
    print('Connecting to WebSocket: $wsUrl');

    try {
      channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      channel.stream.listen(
        (data) {
          _handleMessage(data);
        },
        onError: (error) {
          print('WebSocket error: $error');
          _addMessage('Connection error: $error');
        },
        onDone: () {
          print('WebSocket closed');
          _addMessage('Disconnected');
        },
      );
    } catch (e) {
      print('Connection failed: $e');
      _addMessage('Connection failed: $e');
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

  Future<void> _initRenderers() async {
    try {
      print('Creating renderers...');
      _localRenderer = RTCVideoRenderer();
      _remoteRenderer = RTCVideoRenderer();
      print('Initializing local renderer...');
      await _localRenderer.initialize();
      print('Initializing remote renderer...');
      await _remoteRenderer.initialize();
      print('Setting _renderersInitialized = true');
      setState(() {
        _renderersInitialized = true;
      });
      print('Renderers initialized');
    } catch (e) {
      print('Renderer init error: $e');
      _addMessage('Renderer error: $e');
    }
  }

  Future<void> _startCamera() async {
    try {
      print('Starting camera...');
      final mediaStream = await navigator.mediaDevices.getUserMedia({
        'audio': true,
        'video': {'facingMode': 'user'},
      });
      print('Got mediaStream with ${mediaStream.getTracks().length} tracks');
      for (final track in mediaStream.getTracks()) {
        print('Track: kind=${track.kind}, enabled=${track.enabled}');
      }
      setState(() {
        _localStream = mediaStream;
        if (_renderersInitialized) {
          _localRenderer.srcObject = mediaStream;
        }
      });
      _addMessage('Camera started');
    } catch (e) {
      print('Camera error: $e');
      _addMessage('Camera error: $e');
    }
  }

  void _handleMessage(dynamic data) {
    try {
      print('Raw data type: ${data.runtimeType}');
      print('Raw data: $data');
      final msg = jsonDecode(data);
      print('======= MESSAGE RECEIVED =======');
      print('Decoded msg: $msg');
      print('Type: ${msg['type']}');
      print('From: ${msg['from']}');
      print('Keys: ${msg.keys}');
      print('================================');

      switch (msg['type']) {
        case 'client-id':
          setState(() {
            _clientId = msg['id'];
            _addMessage('Connected as: ${_clientId.substring(0, 8)}...');
          });
          _listPeers();
          break;

        case 'peer-list':
          final peers = List<String>.from(msg['peers'] ?? []);
          setState(() {
            _availablePeers = peers;
          });
          print('Available peers: $peers');
          break;

        case 'peer-joined':
          final peerId = msg['id'] as String;
          setState(() {
            if (!_availablePeers.contains(peerId)) {
              _availablePeers.add(peerId);
            }
          });
          _addMessage('Peer joined: ${peerId.substring(0, 8)}...');
          print('Peer joined: $peerId');
          break;

        case 'peer-left':
          final peerId = msg['id'] as String;
          setState(() {
            _availablePeers.remove(peerId);
          });
          _addMessage('Peer left: ${peerId.substring(0, 8)}...');
          print('Peer left: $peerId');
          break;

        case 'offer':
          _handleOffer(msg['payload'], msg['from']);
          break;

        case 'answer':
          _handleAnswer(msg['payload'], msg['from']);
          break;

        case 'ice-candidate':
          _handleIceCandidate(msg['payload']);
          break;

        case 'chat':
          _addMessage('${msg['from'].substring(0, 8)}: ${msg['payload']}');
          break;
      }
    } catch (e) {
      print('Error handling message: $e');
    }
  }

  void _listPeers() {
    final msg = jsonEncode({'type': 'list-peers'});
    channel.sink.add(msg);
  }

  void _callPeer(String peerId) async {
    if (_peerConnection != null) {
      _addMessage('Call already in progress');
      return;
    }

    print('Calling peer: $peerId');
    setState(() {
      _connectedPeerId = peerId;
    });

    await _createPeerConnection();

    // Create offer
    try {
      print('Creating offer...');
      final offer = await _peerConnection!.createOffer();
      print('Offer created: ${offer.type}');
      await _peerConnection!.setLocalDescription(offer);
      print('Local description set');

      final msgMap = {'type': 'offer', 'to': peerId, 'payload': offer.toMap()};
      final msg = jsonEncode(msgMap);

      // Send as UTF8 bytes
      channel.sink.add(msg);
      print('Sent offer to $peerId');
    } catch (e) {
      print('Error creating offer: $e');
      _addMessage('Error creating offer: $e');
    }
  }

  int min(int a, int b) => a < b ? a : b;

  Future<void> _createPeerConnection() async {
    if (_peerConnection != null) return;

    final configuration = {
      'iceServers': [
        {
          'urls': ['stun:stun.l.google.com:19302'],
        },
      ],
    };

    _peerConnection = await createPeerConnection(configuration, {
      'mandatory': {},
      'optional': [
        {'DtlsSrtpKeyAgreement': true},
      ],
    });

    // Add local stream
    if (_localStream != null) {
      print('Adding ${_localStream!.getTracks().length} tracks to peer connection');
      for (final track in _localStream!.getTracks()) {
        print('Adding track: ${track.kind}');
        await _peerConnection!.addTrack(track, _localStream!);
      }
    } else {
      print('WARNING: _localStream is null!');
    }

    // Handle connection state changes
    _peerConnection!.onConnectionState = (RTCPeerConnectionState state) {
      print('Connection state changed: $state');
    };

    _peerConnection!.onIceConnectionState = (RTCIceConnectionState state) {
      print('ICE connection state: $state');
    };

    // Handle remote tracks
    _peerConnection!.onTrack = (RTCTrackEvent event) {
      print('=== REMOTE TRACK ADDED ===');
      print('Track kind: ${event.track.kind}');
      print('Streams count: ${event.streams.length}');
      if (event.streams.isNotEmpty) {
        print('Setting remote renderer srcObject');
        setState(() {
          _remoteRenderer.srcObject = event.streams[0];
          _isCallActive = true;
        });
      }
    };

    _peerConnection!.onRemoveStream = (stream) {
      print('Remote stream removed');
      setState(() {
        _remoteRenderer.srcObject = null;
      });
    };

    // Handle ICE candidates
    _peerConnection!.onIceCandidate = (candidate) {
      if (candidate != null && _connectedPeerId.isNotEmpty) {
        final msg = jsonEncode({
          'type': 'ice-candidate',
          'to': _connectedPeerId,
          'payload': {
            'candidate': candidate.candidate,
            'sdpMLineIndex': candidate.sdpMLineIndex,
            'sdpMid': candidate.sdpMid,
          },
        });
        channel.sink.add(msg);
        print('Sent ICE candidate');
      }
    };

    _peerConnection!.onConnectionState = (state) {
      print('Connection state: $state');
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        setState(() {
          _isCallActive = true;
        });
        _addMessage('Call connected');
      } else if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateClosed) {
        _endCall();
      }
    };
  }

  void _handleOffer(dynamic payload, String fromPeerId) async {
    print('========== HANDLING OFFER ==========');
    print('Received offer from: "$fromPeerId"');
    print('fromPeerId is empty: ${fromPeerId.isEmpty}');

    if (_peerConnection != null) {
      print('Peer connection already exists');
      return;
    }

    print('Setting connected peer to: $fromPeerId');
    setState(() {
      _connectedPeerId = fromPeerId;
      print('_connectedPeerId is now: $_connectedPeerId');
    });

    await _createPeerConnection();

    try {
      final sdp = payload['sdp'] as String;
      final type = payload['type'] as String;

      final offer = RTCSessionDescription(sdp, type);
      await _peerConnection!.setRemoteDescription(offer);
      print('Remote description set');

      // Flush buffered ICE candidates
      await _flushIceCandidateBuffer();

      final answer = await _peerConnection!.createAnswer();
      await _peerConnection!.setLocalDescription(answer);

      print('Creating answer to send back to: $fromPeerId');
      final msg = jsonEncode({
        'type': 'answer',
        'to': fromPeerId,
        'payload': answer.toMap(),
      });
      print('Answer message to field: $fromPeerId');
      channel.sink.add(msg);
      print('Sent answer to $fromPeerId');
    } catch (e) {
      print('Error handling offer: $e');
      _addMessage('Error handling offer: $e');
    }
  }

  void _handleAnswer(dynamic payload, String fromPeerId) async {
    print('========== HANDLING ANSWER ==========');
    print('Received answer from: "$fromPeerId"');
    print('Payload: $payload');

    try {
      final sdp = payload['sdp'] as String;
      final type = payload['type'] as String;
      
      print('SDP length: ${sdp.length}');
      print('Type: $type');
      
      final answer = RTCSessionDescription(sdp, type);
      print('Setting remote description with answer...');
      await _peerConnection!.setRemoteDescription(answer);
      print('Answer applied successfully');
      
      // Flush buffered ICE candidates
      print('Flushing buffered ICE candidates...');
      await _flushIceCandidateBuffer();
      print('ICE candidates flushed');
    } catch (e) {
      print('Error handling answer: $e');
      _addMessage('Error handling answer: $e');
    }
  }

  void _handleIceCandidate(dynamic payload) async {
    try {
      final candidate = RTCIceCandidate(
        payload['candidate'] as String,
        payload['sdpMid'] as String?,
        payload['sdpMLineIndex'] as int?,
      );

      if (_peerConnection == null) {
        print('Buffering ICE candidate - no peer connection yet');
        _iceCandidateBuffer.add(candidate);
        return;
      }

      // Check if remote description is set
      if (_peerConnection!.getRemoteDescription() == null) {
        print('Buffering ICE candidate - remote description not set yet');
        _iceCandidateBuffer.add(candidate);
        return;
      }

      await _peerConnection!.addCandidate(candidate);
      print('ICE candidate added');
    } catch (e) {
      print('Error adding ICE candidate: $e');
    }
  }

  Future<void> _flushIceCandidateBuffer() async {
    print('Flushing ${_iceCandidateBuffer.length} buffered ICE candidates');
    for (final candidate in _iceCandidateBuffer) {
      try {
        await _peerConnection!.addCandidate(candidate);
      } catch (e) {
        print('Error adding buffered ICE candidate: $e');
      }
    }
    _iceCandidateBuffer.clear();
  }

  void _endCall() {
    _peerConnection?.close();
    _peerConnection = null;
    setState(() {
      _isCallActive = false;
      _connectedPeerId = '';
      _remoteRenderer.srcObject = null;
    });
    _addMessage('Call ended');
    _listPeers();
  }

  void _addMessage(String msg) {
    setState(() {
      messages.add(msg);
    });
  }

  void sendMessage() {
    if (controller.text.isEmpty) return;

    final msg = jsonEncode({'type': 'chat', 'payload': controller.text});

    channel.sink.add(msg);
    controller.clear();
  }

  @override
  void dispose() {
    channel.sink.close();
    controller.dispose();
    _peerConnection?.close();
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Video Call'), elevation: 0),
      body: Column(
        children: [
          // Video area
          Expanded(
            flex: 3,
            child: Container(
              color: Colors.black,
              child: !_renderersInitialized
                  ? const Center(child: CircularProgressIndicator())
                  : Stack(
                      children: [
                        // Remote video (background)
                        RTCVideoView(
                          _remoteRenderer,
                          objectFit:
                              RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                        ),
                        // Local video (corner)
                        Positioned(
                          bottom: 16,
                          right: 16,
                          width: 120,
                          height: 160,
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.white, width: 2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: RTCVideoView(
                              _localRenderer,
                              mirror: true,
                              objectFit: RTCVideoViewObjectFit
                                  .RTCVideoViewObjectFitCover,
                            ),
                          ),
                        ),
                        // Status overlay
                        if (_isCallActive)
                          Positioned(
                            top: 16,
                            left: 16,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text(
                                'Call Active',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
            ),
          ),
          // Peers/Messages area
          Expanded(
            flex: 2,
            child: Column(
              children: [
                // Peers list
                if (_availablePeers.isNotEmpty && !_isCallActive)
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Available Peers:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: _availablePeers
                                .map(
                                  (peerId) => Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4.0,
                                    ),
                                    child: ElevatedButton(
                                      onPressed: () => _callPeer(peerId),
                                      child: Text(peerId.substring(0, 8)),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                      ],
                    ),
                  ),
                // Messages
                Expanded(
                  child: ListView(
                    children: messages
                        .map((m) => ListTile(title: Text(m)))
                        .toList(),
                  ),
                ),
                // Input
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    children: [
                      Expanded(child: TextField(controller: controller)),
                      IconButton(
                        icon: const Icon(Icons.send),
                        onPressed: sendMessage,
                      ),
                      if (_isCallActive)
                        IconButton(
                          icon: const Icon(Icons.call_end, color: Colors.red),
                          onPressed: _endCall,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
