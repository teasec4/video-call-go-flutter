import 'package:flutter_webrtc/flutter_webrtc.dart';

class MediaService {
  MediaStream? _localStream;
  
  MediaStream? get localStream => _localStream;

  Future<void> startMedia() async {
    try {
      _localStream = await navigator.mediaDevices.getUserMedia({
        'audio': true,
        'video': {'facingMode': 'user'},
      });
      print('Media started: ${_localStream?.getTracks().length} tracks');
    } catch (e) {
      print('Failed to start media: $e');
      rethrow;
    }
  }

  void toggleMicrophone(bool enabled) {
    if (_localStream == null) return;
    
    final audioTracks = _localStream!.getAudioTracks();
    for (var track in audioTracks) {
      track.enabled = enabled;
    }
  }

  void toggleCamera(bool enabled) {
    if (_localStream == null) return;
    
    final videoTracks = _localStream!.getVideoTracks();
    for (var track in videoTracks) {
      track.enabled = enabled;
    }
  }

  void dispose() {
    if (_localStream != null) {
      for (var track in _localStream!.getTracks()) {
        track.stop();
      }
      _localStream = null;
    }
  }
}
