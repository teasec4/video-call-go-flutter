import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(colorScheme: .fromSeed(seedColor: Colors.grey)),
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
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    await _initRenderer();
    await _startCamera();
    
    // should start ngrok http 8081 and hardcode https tonnel
    final wsUrl = 'wss://5efe8c3e6ca9.ngrok-free.app/ws';
    
    
    print('Connecting to WebSocket: $wsUrl');


    try {
          channel = WebSocketChannel.connect(Uri.parse(wsUrl));
          channel.stream.listen(
            (data) {
              setState(() {
                messages.add(data.toString());
              });
            },
            onError: (error) {
              print('WebSocket error: $error');
            },
            onDone: () {
              print('WebSocket closed');
            },
          );
        } catch (e) {
          print('Connection failed: $e');
        }

  }

  Future<void> _initRenderer() async {
    try {
      await _localRenderer.initialize();
      print('Renderer initialized successfully');
    } catch (e) {
      print('Renderer init error: $e');
    }
  }

  Future<void> _startCamera() async {
    try {
      final mediaStream = await navigator.mediaDevices.getUserMedia({
        'audio': true,
        'video': {'facingMode': 'user'},
      });
      print('Got mediaStream with ${mediaStream.getTracks().length} tracks');
      setState(() {
        _localRenderer.srcObject = mediaStream;
        print('Set srcObject on renderer');
      });
    } catch (e) {
      print('Camera error: $e');
    }
  }

  void sendMessage() {
    if (controller.text.isEmpty) return;

    final msg = jsonEncode({
      "type": "chat",
      "from": "flutter",
      "payload": controller.text,
    });

    channel.sink.add(msg);
    controller.clear();
  }

  @override
  void dispose() {
    channel.sink.close();
    controller.dispose();
    _localRenderer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Flutter WS Demo")),
      body: Column(
        mainAxisAlignment: .spaceAround,
        children: [
          Container(
            height: 300,
            margin: const EdgeInsets.all(8.0),
            color: Colors.black,
            child: RTCVideoView(
              _localRenderer,
              mirror: true,
              objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
            ),
          ),
          Expanded(
            child: ListView(
              children: messages.map((m) => ListTile(title: Text(m))).toList(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(10.0),
            child: Row(
              children: [
                Expanded(child: TextField(controller: controller)),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
