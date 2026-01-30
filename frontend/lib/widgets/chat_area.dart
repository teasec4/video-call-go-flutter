import 'package:flutter/material.dart';
import 'package:frontend/models/message_model.dart';

class ChatArea extends StatefulWidget {
  final List<SignalingMessage> messages;
  final TextEditingController messageController;
  final VoidCallback onSendMessage;
  final String myId;

  const ChatArea({
    super.key,
    required this.messages,
    required this.messageController,
    required this.onSendMessage,
    required this.myId,
  });

  @override
  State<ChatArea> createState() => _ChatAreaState();
}

class _ChatAreaState extends State<ChatArea> {
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(
          _scrollController.position.maxScrollExtent,
        );
      }
    });

    return Expanded(
      child: ListView.builder(
        controller: _scrollController,
        itemCount: widget.messages.length,
        itemBuilder: (context, index) {
          final msg = widget.messages[index];
          final isOwn = widget.myId == msg.from;
          return Align(
            alignment: isOwn ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              margin: const EdgeInsets.all(8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isOwn ? Colors.blue[300] : Colors.grey[300],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(msg.payload.toString()),
            ),
          );
        },
      ),
    );
  }
}
