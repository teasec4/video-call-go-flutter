import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:frontend/services/websocet_service.dart';
import 'media_service.dart';


class WebRtcService {
  final MediaService mediaService;
  final WebsocetService webSocketService;

  RTCVideoRenderer? _remoteRenderer;
  bool _isCaller = false;

  WebRtcService({
    required this.mediaService,
    required this.webSocketService,
  });

  Future<void> initialize() async {

    await mediaService.initialize();
    await mediaService.initializePeerConnection();

    mediaService.peerConnection.onIceCandidate = (candidate) {
      webSocketService.sendIceCandidate(candidate);
    };

    mediaService.peerConnection.onTrack = (RTCTrackEvent event) {
      print('Remote track received: ${event.track.kind}');
    };

    if (_isCaller) {
      await _createAndSendOffer();
    }
  }

  Future<void> _createAndSendOffer() async {
    try {
      final offer = await mediaService.peerConnection.createOffer();
      await mediaService.peerConnection.setLocalDescription(offer);
      webSocketService.sendOffer(offer);
    } catch (e) {
      print('Error creating offer: $e');
      rethrow;
    }
  }

  Future<void> handleOffer(String sdp) async {
    try {
      final offer = RTCSessionDescription(sdp, 'offer');
      await mediaService.peerConnection.setRemoteDescription(offer);

      final answer = await mediaService.peerConnection.createAnswer();
      await mediaService.peerConnection.setLocalDescription(answer);
      webSocketService.sendAnswer(answer);
    } catch (e) {
      print('Error handling offer: $e');
      rethrow;
    }
  }

  Future<void> handleAnswer(String sdp) async {
    try {
      final answer = RTCSessionDescription(sdp, 'answer');
      await mediaService.peerConnection.setRemoteDescription(answer);
    } catch (e) {
      print('Error handling answer: $e');
      rethrow;
    }
  }

  Future<void> addIceCandidate(String candidate, int? sdpMLineIndex, String? sdpMid) async {
    try {
      final iceCandidate = RTCIceCandidate(candidate, sdpMid, sdpMLineIndex);
      await mediaService.peerConnection.addIceCandidate(iceCandidate);
    } catch (e) {
      print('Error adding ICE candidate: $e');
      rethrow;
    }
  }

  void dispose() {
    _remoteRenderer?.dispose();
    mediaService.dispose();
    webSocketService.disconnect();
  }
}
