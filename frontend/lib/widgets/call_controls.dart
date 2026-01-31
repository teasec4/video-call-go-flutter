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
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.grey[700],
            borderRadius: BorderRadius.circular(24),
          ),
          child: IconButton(
            icon: Icon(
              isMicrophoneEnabled ? Icons.mic : Icons.mic_off,
              color: isMicrophoneEnabled ? Colors.blue[300] : Colors.red,
            ),
            onPressed: onToggleMicrophone,
            tooltip: isMicrophoneEnabled ? 'Mute' : 'Unmute',
          ),
        ),
        const SizedBox(width: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.red.shade600,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.red.withOpacity(0.3),
                blurRadius: 8,
              ),
            ],
          ),
          child: IconButton(
            icon: const Icon(Icons.call_end, color: Colors.white),
            onPressed: onEndCall,
            tooltip: 'End Call',
          ),
        ),
      ],
    );
  }
}
