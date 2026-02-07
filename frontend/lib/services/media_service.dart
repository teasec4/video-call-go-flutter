import 'package:flutter_webrtc/flutter_webrtc.dart';

class MediaService {
  late RTCPeerConnection _peerConnection;
  late MediaStream _localStream;
  
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
        }
      };

      _localStream = await navigator.mediaDevices.getUserMedia(constraints);
      _isInitialized = true;
    } catch (e) {
      print('Error initializing media: $e');
      rethrow;
    }
  }

  Future<void> initializePeerConnection() async {
    final configuration = {
      'iceServers': [
        {'urls': ['stun:stun.l.google.com:19302']}
      ]
    };

    _peerConnection = await createPeerConnection(configuration);
    
    for (var track in _localStream.getTracks()) {
      await _peerConnection.addTrack(track, _localStream);
    }
  }

  void dispose() {
    _localStream.getTracks().forEach((track) {
      track.stop();
    });
    _peerConnection.close();
  }
}
