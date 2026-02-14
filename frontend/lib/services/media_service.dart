import 'package:flutter_webrtc/flutter_webrtc.dart';

class MediaService {
  late MediaStream _localStream;
  
  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;
  MediaStream get localStream => _localStream;
  

  Future<void> initialize() async {
    try {
      final constraints = {
        'audio': true,
        'video': {
          'mandatory': {
            'minWidth': '640',
            'minHeight': '480',
            'minFrameRate': '30',
          },
          'facingMode': 'user',
          'optional': [],
        }
      };

      _localStream = await navigator.mediaDevices.getUserMedia(constraints);
      _isInitialized = true;
    } catch (e) {
      print('Error initializing media: $e');
      rethrow;
    }
  }

  void dispose() {
    _localStream.getTracks().forEach((track) {
      track.stop();
    });
  }
}
