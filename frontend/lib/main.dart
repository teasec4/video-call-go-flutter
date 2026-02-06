import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'screens/start_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String? _initialRoomId;

  @override
  void initState() {
    super.initState();
    _parseInitialUrl();
  }

  void _parseInitialUrl() {
    // Parse URI for room ID
    // Support formats:
    // - ?roomId=abc123
    // - #/room/abc123
    // - /room/abc123
    final uri = Uri.base;
    
    // Check query parameters first
    if (uri.queryParameters.containsKey('roomId')) {
      _initialRoomId = uri.queryParameters['roomId'];
      print('Parsed room ID from query parameter: $_initialRoomId');
      return;
    }
    
    // Check hash fragment
    if (uri.fragment.isNotEmpty) {
      final fragment = uri.fragment;
      if (fragment.contains('/room/')) {
        _initialRoomId = fragment.split('/room/').last;
        print('Parsed room ID from hash fragment: $_initialRoomId');
        return;
      }
    }
    
    // Check path
    final pathSegments = uri.pathSegments;
    if (pathSegments.length >= 2 && pathSegments[0] == 'room') {
      _initialRoomId = pathSegments[1];
      print('Parsed room ID from path: $_initialRoomId');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      child: MaterialApp(
        title: 'Video Call',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.blue,
            brightness: Brightness.light,
          ),
          useMaterial3: true,
          appBarTheme: AppBarTheme(
            backgroundColor: Colors.grey[900],
            foregroundColor: Colors.white,
            elevation: 0,
          ),
          scaffoldBackgroundColor: Colors.white,
          inputDecorationTheme: InputDecorationTheme(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            filled: true,
            fillColor: Colors.white,
          ),
        ),
        home: StartScreen(initialRoomId: _initialRoomId),
      ),
    );
  }
}


