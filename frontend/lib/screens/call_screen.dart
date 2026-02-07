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

  @override
  void initState() {
    super.initState();
    roomId = widget.roomId;
    initWebSocet();
  }

  Future<void> initWebSocet() async {
    await getIt<RoomManager>().connectToWs();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Room $roomId'), centerTitle: true),
      body: Center(child: Text(roomId)),
    );
  }
}
