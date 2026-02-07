import 'package:flutter/material.dart';
import 'package:frontend/di/service_locator.dart';
import 'package:frontend/screens/call_screen.dart';
import 'screens/start_screen.dart';

void main() {
  
  setupServiceLocator();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Video Call',
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      home: const StartScreen(),
      routes: {
        '/call': (context) {
          final roomId = ModalRoute.of(context)?.settings.arguments as String?;
          return CallScreen(roomId: roomId ?? '');
        },
      },
    );
  }
}
