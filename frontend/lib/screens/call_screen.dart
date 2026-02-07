import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:frontend/di/service_locator.dart';
import 'package:frontend/services/creat_room_service.dart';

class CallScreen extends StatefulWidget {
  final String roomId;

  const CallScreen({Key? key, required this.roomId}) : super(key: key);

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  late String roomId;
  late TextEditingController _chatSendTextController;

  @override
  void initState() {
    super.initState();
    roomId = widget.roomId;
    initWebSocet();
    _chatSendTextController = TextEditingController();
    getIt<RoomManager>().onMessageReceived = (data) {
      setState(() {
        // UI обновится
      });
    };
  }

  @override
  void dispose() {
    _chatSendTextController.dispose();
    super.dispose();
  }

  Future<void> initWebSocet() async {
    await getIt<RoomManager>().connectToWs();
  }

  void _onSendMsg() {
    final msg = _chatSendTextController.text;
    
    if (msg.isEmpty) return;
    
     getIt<RoomManager>().websocetService.send({
      'type' : 'chat',
      'from' : getIt<RoomManager>().userId,
      'payload' : msg,
    });
    
    _chatSendTextController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Room $roomId'), centerTitle: true),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: getIt<RoomManager>().messages.length,
              itemBuilder: (context, index) {
                final msg = getIt<RoomManager>().messages[index];
                return Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text('${msg['from']}: ${msg['payload']}'),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _chatSendTextController,
                    decoration: InputDecoration(
                      hintText: "input message",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.all(12),
                    ),
                  ),
                ),
                IconButton(icon: const Icon(Icons.send), onPressed: _onSendMsg),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
