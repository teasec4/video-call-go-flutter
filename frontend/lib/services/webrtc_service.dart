import 'package:flutter_webrtc/flutter_webrtc.dart';

class WebrtcService {
  late RTCVideoRenderer localRenderer;
  late RTCVideoRenderer remoteRenderer;
  RTCPeerConnection? _peerConnection;
  final List<RTCIceCandidate> _iceCandidateBuffer = [];

  WebrtcService() {
    localRenderer = RTCVideoRenderer();
    remoteRenderer = RTCVideoRenderer();
  }

  RTCPeerConnection? get peerConnection => _peerConnection;
  
  Future<void> initRenderers() async {
    try {
      await localRenderer.initialize();
      await remoteRenderer.initialize();
      print('Renderers initialized');
    } catch (e) {
      print('Failed to initialize renderers: $e');
      rethrow;
    }
  }

  Future<void> initPeerConnection(
    Function(RTCSessionDescription) onLocalDescription,
    Function(RTCIceCandidate) onIceCandidate,
  ) async {
    try {
      final configuration = {
        'iceServers': [
          {'urls': ['stun:stun.l.google.com:19302']}
        ]
      };

      _peerConnection = await createPeerConnection(
        configuration,
        {'mandatory': {}, 'optional': []},
      );

      // Handle both legacy onAddStream and modern onTrack
      _peerConnection!.onAddStream = (stream) {
        print('Legacy: Remote stream received');
        remoteRenderer.srcObject = stream;
      };

      _peerConnection!.onTrack = (RTCTrackEvent event) {
        print('Track received: ${event.track.kind} (${event.track.id})');
        // Get the first stream from the event
        if (event.streams.isNotEmpty) {
          remoteRenderer.srcObject = event.streams[0];
          print('Remote stream set from track event');
        }
      };

      _peerConnection!.onIceCandidate = (candidate) {
        print('ICE candidate generated');
        onIceCandidate(candidate);
      };

      print('Peer connection created');
    } catch (e) {
      print('Failed to create peer connection: $e');
      rethrow;
    }
  }

  Future<RTCSessionDescription> createOffer() async {
    try {
      final offer = await _peerConnection!.createOffer();
      await _peerConnection!.setLocalDescription(offer);
      print('Offer created');
      return offer;
    } catch (e) {
      print('Failed to create offer: $e');
      rethrow;
    }
  }

  Future<RTCSessionDescription> createAnswer() async {
    try {
      final answer = await _peerConnection!.createAnswer();
      await _peerConnection!.setLocalDescription(answer);
      print('Answer created');
      return answer;
    } catch (e) {
      print('Failed to create answer: $e');
      rethrow;
    }
  }

  Future<void> setRemoteDescription(
    String sdp,
    String type,
  ) async {
    try {
      final description = RTCSessionDescription(sdp, type);
      await _peerConnection!.setRemoteDescription(description);
      print('Remote description set: $type');
      await _flushIceCandidateBuffer();
    } catch (e) {
      print('Failed to set remote description: $e');
      rethrow;
    }
  }

  Future<void> addIceCandidate(dynamic payload) async {
    try {
      final candidate = RTCIceCandidate(
        payload['candidate'] as String,
        payload['sdpMid'] as String?,
        payload['sdpMLineIndex'] as int?,
      );

      if (_peerConnection == null) {
        print('Buffering ICE candidate - no peer connection');
        _iceCandidateBuffer.add(candidate);
        return;
      }

      try {
        await _peerConnection!.addCandidate(candidate);
        print('ICE candidate added');
      } catch (e) {
        print('Failed to add candidate, buffering: $e');
        _iceCandidateBuffer.add(candidate);
      }
    } catch (e) {
      print('Error handling ICE candidate: $e');
    }
  }

  Future<void> _flushIceCandidateBuffer() async {
    print('Flushing ${_iceCandidateBuffer.length} buffered ICE candidates');
    for (final candidate in _iceCandidateBuffer) {
      try {
        await _peerConnection!.addCandidate(candidate);
      } catch (e) {
        print('Error adding buffered ICE candidate: $e');
      }
    }
    _iceCandidateBuffer.clear();
  }

  Future<void> addStream(MediaStream stream) async {
    try {
      if (_peerConnection == null) {
        throw Exception('Peer connection not initialized');
      }

      // Add audio tracks
      final audioTracks = stream.getAudioTracks();
      for (final track in audioTracks) {
        await _peerConnection!.addTrack(track, stream);
        print('Audio track added: ${track.id}');
      }

      // Add video tracks
      final videoTracks = stream.getVideoTracks();
      for (final track in videoTracks) {
        await _peerConnection!.addTrack(track, stream);
        print('Video track added: ${track.id}');
      }

      print('All streams added to peer connection (${audioTracks.length} audio, ${videoTracks.length} video)');
    } catch (e) {
      print('Failed to add stream: $e');
      rethrow;
    }
  }

  void closePeerConnection() {
    try {
      _peerConnection?.close();
      _peerConnection = null;
      _iceCandidateBuffer.clear();
      print('Peer connection closed');
    } catch (e) {
      print('Error closing peer connection: $e');
    }
  }

  void dispose() {
    closePeerConnection();
    try {
      localRenderer.dispose();
      remoteRenderer.dispose();
      print('Renderers disposed');
    } catch (e) {
      print('Error disposing renderers: $e');
    }
  }
}
