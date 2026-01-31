import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers/call_controller.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

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
        home: const MyHomePage(),
      ),
    );
  }
}

class MyHomePage extends ConsumerStatefulWidget {
  const MyHomePage({super.key});

  @override
  ConsumerState<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends ConsumerState<MyHomePage> {
  late TextEditingController messageController;

  @override
  void initState() {
    super.initState();
    messageController = TextEditingController();
  }

  @override
  void dispose() {
    messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Инициализация при загрузке
    ref.watch(callInitProvider);

    final callState = ref.watch(callControllerProvider);
    final callController = ref.read(callControllerProvider.notifier);

    return HomeScreen(
      localRenderer: callController.webrtcService.localRenderer,
      remoteRenderer: callController.webrtcService.remoteRenderer,
      renderersInitialized: true,
      isCallActive: callState.isCallActive,
      isMicrophoneEnabled: callState.isMicrophoneEnabled,
      availablePeers: callState.availablePeers,
      messages: callState.messages,
      messageController: messageController,
      onSendMessage: () {
        callController.sendMessage(messageController.text);
        messageController.clear();
      },
      onCallPeer: (peerId) {
        callController.callPeer(peerId);
      },
      onToggleMicrophone: () {
        callController.toggleMicrophone();
      },
      onEndCall: () {
        callController.endCall();
      },
      myId: callState.clientId,
    );
  }
}
