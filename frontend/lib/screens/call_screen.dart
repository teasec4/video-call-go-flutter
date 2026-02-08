import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend/bloc/room_bloc.dart';
import 'package:frontend/bloc/room_event.dart';
import 'package:frontend/bloc/room_state.dart';
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
  late RoomBloc _roomBloc;

  @override
  void initState() {
    super.initState();
    roomId = widget.roomId;
    _chatSendTextController = TextEditingController();

    _roomBloc = RoomBloc(roomManager: getIt<RoomManager>());
    _roomBloc.add(InitializeRoomEvent(widget.roomId));
  }

  @override
  void dispose() {
    _chatSendTextController.dispose();
    _roomBloc.close();
    super.dispose();
  }

  void _sendMessage() {
    final msg = _chatSendTextController.text;
    print('DEBUG: _sendMessage called, text: "$msg"');
    
    if (msg.isNotEmpty) {
      print('DEBUG: Adding SendMessageEvent to Bloc');
      _roomBloc.add(SendMessageEvent(msg));
      _chatSendTextController.clear();
      print('DEBUG: TextField cleared');
    } else {
      print('DEBUG: Text is empty');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Room $roomId'), centerTitle: true),
      body: BlocBuilder<RoomBloc, RoomState>(
        bloc: _roomBloc,
        builder: (context, state) {
          if (state is RoomLoading) {
            return Center(child: CircularProgressIndicator());
          }

          if (state is RoomInitialized || state is MessageAdded) {
            final messages = (state as dynamic).messages;
            
            return Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final msg = messages[index];
                      return Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text('${msg.from}: ${msg.payload}'),
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
                      IconButton(
                        icon: const Icon(Icons.send),
                        onPressed: _sendMessage,
                      ),
                    ],
                  ),
                ),
              ],
            );
          }

          if (state is RoomError) {
            return Center(child: Text('Error: ${state.error}'));
          }

          return Center(child: Text('Unknown state'));
        },
      ),
    );
  }
}
