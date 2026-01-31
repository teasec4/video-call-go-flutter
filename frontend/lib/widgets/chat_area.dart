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
      child: Container(
        color: Colors.grey[900],
        child: widget.messages.isEmpty
            ? Center(
                child: Text(
                  'No messages yet',
                  style: TextStyle(color: Colors.grey[500]),
                ),
              )
            : ListView.builder(
                controller: _scrollController,
                itemCount: widget.messages.length,
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemBuilder: (context, index) {
                  final msg = widget.messages[index];
                  final isOwn = widget.myId == msg.from;
                  return Align(
                    alignment:
                        isOwn ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: isOwn ? Colors.blue[600] : Colors.grey[700],
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: Text(
                        msg.payload.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
