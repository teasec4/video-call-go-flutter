import 'package:flutter/material.dart';

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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Call'), centerTitle: true),
      body: Center(child: Text(roomId)),
    );
  }
}
