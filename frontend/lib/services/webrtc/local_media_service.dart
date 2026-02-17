import 'package:flutter_webrtc/flutter_webrtc.dart';

/// Управляет локальным видео и аудио устройством
class LocalMediaService {
  late MediaStream _localStream;
  late RTCVideoRenderer _localRenderer;

  bool _isInitialized = false;

  MediaStream get localStream => _localStream;
  RTCVideoRenderer get localRenderer => _localRenderer;
  bool get isInitialized => _isInitialized;

  /// Инициализирует локальное видео и аудио устройства
  /// Создаёт рендерер для отображения локального потока
  Future<void> initialize() async {
    if (_isInitialized) return;

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

      _isInitialized = true;
      print('✅ Local media initialized');
    } catch (e) {
      print('❌ Error initializing local media: $e');
      rethrow;
    }
  }

  /// Очищает ресурсы: останавливает треки и рендерер
  void dispose() {
    if (!_isInitialized) return;

    _localStream.getTracks().forEach((track) {
      track.stop();
    });
    _localRenderer.dispose();
    _isInitialized = false;
    print('🔌 Local media disposed');
  }
}
