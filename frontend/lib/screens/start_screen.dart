import 'package:flutter/material.dart';
import 'package:frontend/di/service_locator.dart';
import 'package:frontend/services/creat_room_service.dart';

class StartScreen extends StatefulWidget {
  const StartScreen({Key? key}) : super(key: key);

  @override
  State<StartScreen> createState() => _StartScreenState();
}

class _StartScreenState extends State<StartScreen> {
  Future<void> _onStartCallPressed() async {
    print('BUTTON PRESSED');
    
    final roomId = await getIt<RoomManager>().createRoom();
    print(roomId);
    // Переходи на CallScreen
    Navigator.pushNamed(context, '/call', arguments: roomId);
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Video Call'), centerTitle: true),
      body: Center(
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
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {},
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
    );
  }
}
