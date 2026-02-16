import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:frontend/services/websocet_service.dart';

/// Управляет WebRTC соединением между двумя пирами
class WebRTCService {
  final WebsocetService websocetService;

  WebRTCService({required this.websocetService});

  // Локальный медиа-поток (видео + аудио)
  late MediaStream _localStream;
  late MediaStream? _remoteStream;

  // Рендереры для отображения видео
  late RTCVideoRenderer _localRenderer;
  late RTCVideoRenderer _remoteRenderer;

  // Объект для управления P2P соединением
  late RTCPeerConnection _peerConnection;

  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;
  MediaStream get localStream => _localStream;
  RTCPeerConnection get peerConnection => _peerConnection;

  /// Инициализирует локальное видео и аудио устройства
  /// Создаёт рендереры для отображения потоков
  Future<void> initLocalAndRemoteRenderer() async {
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
      // Получаем локальный медиа-поток
      _localStream = await navigator.mediaDevices.getUserMedia(constraints);
      
      // Инициализируем рендерер для локального видео
      _localRenderer = RTCVideoRenderer();
      await _localRenderer.initialize();
      _localRenderer.srcObject = _localStream;

      // Инициализируем рендерер для удалённого видео
      _remoteRenderer = RTCVideoRenderer();
      await _remoteRenderer.initialize();
    } catch (e) {
      rethrow;
    }
  }

  /// Создаёт и настраивает P2P соединение с STUN серверами
  /// для преодоления NAT
  Future<void> initPeerConnection() async {
    // STUN конфигурация для обнаружения публичного IP
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
  }

  /// Инициализирует WebRTC: медиа, P2P соединение и обработчики
  /// Эта функция только подготавливает к соединению, но не создаёт offer
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      // Инициализируем медиа и рендереры
      await initLocalAndRemoteRenderer();
      await initPeerConnection();

      // Добавляем локальные треки в соединение
      for (var track in _localStream.getTracks()) {
        await _peerConnection.addTrack(track, _localStream);
      }

      // Обработчик для отправки ICE кандидатов
      _peerConnection.onIceCandidate = (candidate) {
        websocetService.sendIceCandidate(candidate);
      };

      // Обработчик для получения удалённого видео-потока
      _peerConnection.onTrack = (RTCTrackEvent event) {
        if (event.streams.isNotEmpty) {
          _remoteStream = event.streams[0];
          _remoteRenderer.srcObject = _remoteStream;
        }
      };

      _isInitialized = true;
    } catch (e) {
      print('Error initializing WebRTC: $e');
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
      final offer = await _peerConnection.createOffer();
      await _peerConnection.setLocalDescription(offer);
      websocetService.sendOffer(offer);
    } catch (e) {
      print('Error creating offer: $e');
      rethrow;
    }
  }

  /// Обрабатывает входящий offer от удалённого пира
  /// Создаёт и отправляет answer в ответ
  Future<void> handleOffer(String sdp) async {
    try {
      final offer = RTCSessionDescription(sdp, 'offer');
      await _peerConnection.setRemoteDescription(offer);

      // Создаём ответ на offer
      final answer = await _peerConnection.createAnswer();
      await _peerConnection.setLocalDescription(answer);
      websocetService.sendAnswer(answer);
    } catch (e) {
      print('Error handling offer: $e');
      rethrow;
    }
  }

  /// Обрабатывает входящий answer от удалённого пира
  /// Завершает процесс согласования SDP описаний
  Future<void> handleAnswer(String sdp) async {
    try {
      final answer = RTCSessionDescription(sdp, 'answer');
      await _peerConnection.setRemoteDescription(answer);
    } catch (e) {
      print('Error handling answer: $e');
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
      await _peerConnection.addCandidate(iceCandidate);
    } catch (e) {
      print('Error adding ICE candidate: $e');
      rethrow;
    }
  }

  /// Очищает все ресурсы: останавливает треки, закрывает соединение
  /// и рендереры
  void dispose() {
    if (!_isInitialized) return;
    
    _localStream.getTracks().forEach((track) {
      track.stop();
    });
    _peerConnection.close();
    _remoteRenderer.dispose();
    _localRenderer.dispose();
    websocetService.disconnect();
  }
}
