import 'package:flutter_webrtc/flutter_webrtc.dart';

class MediaService {
  late MediaStream _localStream;
  late RTCPeerConnection _peerConnection;

  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;
  MediaStream get localStream => _localStream;
  RTCPeerConnection get peerConnection => _peerConnection;

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
        },
      };

      _localStream = await navigator.mediaDevices.getUserMedia(constraints);

      final config = {
        'iceServers': [
          {
            'urls': [
              'stun:stun.l.google.com:19302',
              'stun:stun1.l.google.com:19302',
            ],
          },
        ],
      };

      _peerConnection = await createPeerConnection(config);
      
      for (var track in _localStream.getTracks()) {
        await _peerConnection.addTrack(track, _localStream);
      }

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
    _peerConnection.close();

  }
}
