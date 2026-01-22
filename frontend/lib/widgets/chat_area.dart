import 'package:flutter/material.dart';

class ChatArea extends StatelessWidget {
  final List<String> messages;
  final TextEditingController messageController;
  final VoidCallback onSendMessage;

  const ChatArea({
    super.key,
    required this.messages,
    required this.messageController,
    required this.onSendMessage,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: ListView(
        children: messages
            .map((m) => ListTile(title: Text(m)))
            .toList(),
      ),
    );
  }
}
