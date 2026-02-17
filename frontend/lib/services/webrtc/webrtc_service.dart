import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:frontend/services/websocet_service.dart';
import 'package:frontend/services/webrtc/local_media_service.dart';
import 'package:frontend/services/webrtc/peer_connection_service.dart';

/// Координирует локальные медиа и P2P соединение
class WebRTCService {
  final WebsocetService websocetService;
  final LocalMediaService localMediaService;
  final PeerConnectionService peerConnectionService;

  WebRTCService({
    required this.websocetService,
    required this.localMediaService,
    required this.peerConnectionService,
  });

  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;
  MediaStream get localStream => localMediaService.localStream;
  RTCPeerConnection get peerConnection => peerConnectionService.peerConnection;

  /// Инициализирует WebRTC: медиа, P2P соединение и обработчики
  /// Эта функция только подготавливает к соединению, но не создаёт offer
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Инициализируем локальные медиа
      await localMediaService.initialize();
      
      // Инициализируем P2P соединение
      await peerConnectionService.initialize();

      // Добавляем локальные треки в соединение
      for (var track in localMediaService.localStream.getTracks()) {
        await peerConnectionService.addTrack(track, localMediaService.localStream);
      }

      // Обработчик для отправки ICE кандидатов
      peerConnectionService.onIceCandidate((candidate) {
        websocetService.sendIceCandidate(candidate);
      });

      // Обработчик для получения удалённого видео-потока
      peerConnectionService.onTrack((event) {
        print('🎥 Remote track received: ${event.track.kind}');
      });

      _isInitialized = true;
      print('✅ WebRTC fully initialized');
    } catch (e) {
      print('❌ Error initializing WebRTC: $e');
      rethrow;
    }
  }

  /// Инициирует соединение как caller: создаёт и отправляет offer
  /// Вызывается после initialize() тем, кто инициирует звонок
  Future<void> startAsCallerAsync() async {
    if (!_isInitialized) {
      throw Exception('WebRTCService must be initialized before starting as caller');
    }
    await _createAndSendOffer();
  }

  /// Создаёт offer (предложение о соединении) и отправляет через WebSocket
  /// Вызывается инициатором соединения (caller)
  Future<void> _createAndSendOffer() async {
    try {
      final offer = await peerConnectionService.peerConnection.createOffer();
      await peerConnectionService.peerConnection.setLocalDescription(offer);
      websocetService.sendOffer(offer);
      print('📤 Offer sent');
    } catch (e) {
      print('❌ Error creating offer: $e');
      rethrow;
    }
  }

  /// Обрабатывает входящий offer от удалённого пира
  /// Создаёт и отправляет answer в ответ
  Future<void> handleOffer(String sdp) async {
    try {
      final offer = RTCSessionDescription(sdp, 'offer');
      await peerConnectionService.peerConnection.setRemoteDescription(offer);

      // Создаём ответ на offer
      final answer = await peerConnectionService.peerConnection.createAnswer();
      await peerConnectionService.peerConnection.setLocalDescription(answer);
      websocetService.sendAnswer(answer);
      print('📤 Answer sent');
    } catch (e) {
      print('❌ Error handling offer: $e');
      rethrow;
    }
  }

  /// Обрабатывает входящий answer от удалённого пира
  /// Завершает процесс согласования SDP описаний
  Future<void> handleAnswer(String sdp) async {
    try {
      final answer = RTCSessionDescription(sdp, 'answer');
      await peerConnectionService.peerConnection.setRemoteDescription(answer);
      print('✅ Answer received');
    } catch (e) {
      print('❌ Error handling answer: $e');
      rethrow;
    }
  }

  /// Добавляет ICE кандидата для прямого соединения между пирами
  /// ICE кандидаты содержат потенциальные адреса для подключения
  Future<void> addIceCandidate(
    String candidate,
    int? sdpMLineIndex,
    String? sdpMid,
  ) async {
    try {
      final iceCandidate = RTCIceCandidate(candidate, sdpMid, sdpMLineIndex);
      await peerConnectionService.peerConnection.addCandidate(iceCandidate);
      print('🧊 ICE candidate added');
    } catch (e) {
      print('❌ Error adding ICE candidate: $e');
      rethrow;
    }
  }

  /// Очищает все ресурсы: останавливает треки, закрывает соединение и рендереры
  void dispose() {
    if (!_isInitialized) return;

    localMediaService.dispose();
    peerConnectionService.dispose();
    _isInitialized = false;
    print('🔌 WebRTC disposed');
  }
}
