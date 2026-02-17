import 'package:flutter_webrtc/flutter_webrtc.dart';

/// Управляет P2P соединением и ICE логикой
class PeerConnectionService {
  late RTCPeerConnection _peerConnection;
  late RTCVideoRenderer _remoteRenderer;
  late MediaStream? _remoteStream;

  bool _isInitialized = false;

  RTCPeerConnection get peerConnection => _peerConnection;
  RTCVideoRenderer get remoteRenderer => _remoteRenderer;
  MediaStream? get remoteStream => _remoteStream;
  bool get isInitialized => _isInitialized;

  /// Создаёт и настраивает P2P соединение с STUN серверами
  /// для преодоления NAT
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
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

      // Инициализируем рендерер для удалённого видео
      _remoteRenderer = RTCVideoRenderer();
      await _remoteRenderer.initialize();

      _isInitialized = true;
      print('✅ Peer connection initialized');
    } catch (e) {
      print('❌ Error initializing peer connection: $e');
      rethrow;
    }
  }

  /// Добавляет локальный трек в соединение
  Future<void> addTrack(MediaStreamTrack track, MediaStream stream) async {
    try {
      await _peerConnection.addTrack(track, stream);
      print('✅ Track added to peer connection');
    } catch (e) {
      print('❌ Error adding track: $e');
      rethrow;
    }
  }

  /// Регистрирует обработчик для ICE кандидатов
  void onIceCandidate(Function(RTCIceCandidate) handler) {
    _peerConnection.onIceCandidate = handler;
  }

  /// Регистрирует обработчик для входящих треков (удалённое видео)
  void onTrack(Function(RTCTrackEvent) handler) {
    _peerConnection.onTrack = (RTCTrackEvent event) {
      if (event.streams.isNotEmpty) {
        _remoteStream = event.streams[0];
        _remoteRenderer.srcObject = _remoteStream;
      }
      handler(event);
    };
  }

  /// Очищает ресурсы: закрывает соединение и рендерер
  void dispose() {
    if (!_isInitialized) return;

    _peerConnection.close();
    _remoteRenderer.dispose();
    _isInitialized = false;
    print('🔌 Peer connection disposed');
  }
}
