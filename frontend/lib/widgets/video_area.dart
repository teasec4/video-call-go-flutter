import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

class VideoArea extends StatelessWidget {
  final RTCVideoRenderer localRenderer;
  final RTCVideoRenderer remoteRenderer;
  final bool renderersInitialized;
  final bool isCallActive;

  const VideoArea({
    super.key,
    required this.localRenderer,
    required this.remoteRenderer,
    required this.renderersInitialized,
    required this.isCallActive,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: !renderersInitialized
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                // Remote video (background)
                RTCVideoView(
                  remoteRenderer,
                  objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                ),
                // Local video (corner)
                Positioned(
                  bottom: 16,
                  right: 16,
                  width: 120,
                  height: 160,
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white, width: 2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: RTCVideoView(
                      localRenderer,
                      mirror: true,
                      objectFit:
                          RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                    ),
                  ),
                ),
                // Status overlay
                if (isCallActive)
                  Positioned(
                    top: 16,
                    left: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Call Active',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
