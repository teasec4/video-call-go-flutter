import 'package:flutter/material.dart';

class CallControls extends StatelessWidget {
  final bool isCallActive;
  final bool isMicrophoneEnabled;
  final VoidCallback onToggleMicrophone;
  final VoidCallback onEndCall;

  const CallControls({
    super.key,
    required this.isCallActive,
    required this.isMicrophoneEnabled,
    required this.onToggleMicrophone,
    required this.onEndCall,
  });

  @override
  Widget build(BuildContext context) {
    if (!isCallActive) {
      return const SizedBox.shrink();
    }

    return Row(
      children: [
        IconButton(
          icon: Icon(
            isMicrophoneEnabled ? Icons.mic : Icons.mic_off,
            color: isMicrophoneEnabled ? Colors.blue : Colors.red,
          ),
          onPressed: onToggleMicrophone,
        ),
        IconButton(
          icon: const Icon(Icons.call_end, color: Colors.red),
          onPressed: onEndCall,
        ),
      ],
    );
  }
}
