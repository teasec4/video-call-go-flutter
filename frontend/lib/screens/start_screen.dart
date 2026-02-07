import 'package:flutter/material.dart';
import 'package:frontend/di/service_locator.dart';
import 'package:frontend/services/creat_room_service.dart';

class StartScreen extends StatefulWidget {
  const StartScreen({Key? key}) : super(key: key);

  @override
  State<StartScreen> createState() => _StartScreenState();
}

class _StartScreenState extends State<StartScreen> {
  late TextEditingController _textEditingRoomId;

  @override
  void initState() {
    super.initState();
    _textEditingRoomId = TextEditingController();
  }

  @override
  void dispose() {
    _textEditingRoomId.dispose();
    super.dispose();
  }

  Future<void> _onStartCallPressed() async {
    print('BUTTON PRESSED');

    final roomId = await getIt<RoomManager>().createRoom();
    print(roomId);
    // Переходи на CallScreen
    Navigator.pushNamed(context, '/call', arguments: roomId);
  }

  Future<void> _onJoinToRoomPressed() async {
    print("JOIN BUTTON PRESSED");
    final roomId = _textEditingRoomId.text;
    if (roomId.isNotEmpty) {
      await getIt<RoomManager>().joinRoom(roomId);
      print("Joined to Room - SUCCESS");
      _textEditingRoomId.clear();
      
      // await getIt<RoomManager>().connectToWs();
      
      Navigator.pushNamed(context, '/call', arguments: roomId);
      
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter room ID')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Video Call'), centerTitle: true),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: _onStartCallPressed,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 40,
                      vertical: 16,
                    ),
                  ),
                  child: const Text('Start Call'),
                ),
                const SizedBox(height: 32),
                TextField(
                  controller: _textEditingRoomId,
                  decoration: InputDecoration(
                    hintText: 'Enter room ID',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.all(12),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _onJoinToRoomPressed,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 40,
                      vertical: 16,
                    ),
                  ),
                  child: const Text('Join Call'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
