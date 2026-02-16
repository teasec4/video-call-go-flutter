import 'package:frontend/services/websocet_service.dart';
import 'package:frontend/services/webrtc_service_new.dart';

/// Координирует WebRTC сигнализацию через WebSocket
/// Подключает обработчики и управляет потоком SDP + ICE
class SignalingService {
  final WebsocetService websocetService;
  final WebRTCService webrtcService;

  SignalingService({
    required this.websocetService,
    required this.webrtcService,
  });

  /// Регистрирует все необходимые обработчики для сигнализации
  void setupSignaling() {
    // Обработчик входящего offer от удалённого пира
    websocetService.onOffer((offer) async {
      print('📬 Received offer from remote peer');
      if (offer.sdp == null) {
        print('❌ Offer SDP is null');
        return;
      }
      await webrtcService.handleOffer(offer.sdp!);
    });

    // Обработчик входящего answer от удалённого пира
    websocetService.onAnswer((answer) async {
      print('📬 Received answer from remote peer');
      if (answer.sdp == null) {
        print('❌ Answer SDP is null');
        return;
      }
      await webrtcService.handleAnswer(answer.sdp!);
    });

    // Обработчик входящего ICE кандидата от удалённого пира
    websocetService.onIceCandidate((candidate) async {
      print('🧊 Received ICE candidate from remote peer');
      await webrtcService.addIceCandidate(
        candidate.candidate ?? '',
        candidate.sdpMLineIndex,
        candidate.sdpMid,
      );
    });
  }
}
