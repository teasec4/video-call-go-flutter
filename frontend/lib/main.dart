import 'dart:convert';

import 'package:flutter/material.dart';
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
      theme: ThemeData(colorScheme: .fromSeed(seedColor: Colors.deepPurple)),
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

  @override
  void initState() {
    super.initState();

    channel = WebSocketChannel.connect(Uri.parse('ws://localhost:8080/ws'));
    channel.stream.listen((data) {
      setState(() {
        messages.add(data.toString());
      });
    });
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Flutter WS Demo"),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              children: messages
              .map((m) => ListTile(title: Text(m),))
              .toList(),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: TextField(controller: controller,),
              ),
              IconButton(
                icon: const Icon(Icons.send),
                onPressed: sendMessage,
              )
            ],
          )
        ],
      ),
    );
  }
}
