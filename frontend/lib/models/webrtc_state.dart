import 'package:flutter_webrtc/flutter_webrtc.dart';

/// Фазы жизненного цикла WebRTC соединения
enum WebRTCPhase {
  idle, // нет соединения
  connecting, // соединение в процессе инициализации
  connected, // соединение установлено и активно
  closing, // соединение закрывается
}

/// Синхронизированное состояние WebRTC соединения
/// Обеспечивает единую точку управления жизненным циклом соединения
class WebRTCState {
  // Текущая фаза соединения
  final WebRTCPhase phase;

  // ID пира, с которым установлено соединение
  final String? connectedWith;

  // WebRTC соединение (если активно)
  final RTCPeerConnection? peerConnection;

  // Локальная описание (offer или answer)
  final RTCSessionDescription? localDescription;

  // Удалённая описание (offer или answer от пира)
  final RTCSessionDescription? remoteDescription;

  // Статус локального потока
  final bool localStreamAdded;

  // Флаг инициатора соединения (true если мы создали offer, false если ответили answer)
  final bool isInitiator;

  // Ошибка если была
  final String? error;

  WebRTCState({
    required this.phase,
    this.connectedWith,
    this.peerConnection,
    this.localDescription,
    this.remoteDescription,
    this.localStreamAdded = false,
    this.isInitiator = false,
    this.error,
  });

  /// Начальное состояние - нет соединения
  factory WebRTCState.idle() {
    return WebRTCState(phase: WebRTCPhase.idle);
  }

  /// Создание копии с переопределением некоторых полей
  WebRTCState copyWith({
    WebRTCPhase? phase,
    String? connectedWith,
    RTCPeerConnection? peerConnection,
    RTCSessionDescription? localDescription,
    RTCSessionDescription? remoteDescription,
    bool? localStreamAdded,
    bool? isInitiator,
    String? error,
  }) {
    return WebRTCState(
      phase: phase ?? this.phase,
      connectedWith: connectedWith ?? this.connectedWith,
      peerConnection: peerConnection ?? this.peerConnection,
      localDescription: localDescription ?? this.localDescription,
      remoteDescription: remoteDescription ?? this.remoteDescription,
      localStreamAdded: localStreamAdded ?? this.localStreamAdded,
      isInitiator: isInitiator ?? this.isInitiator,
      error: error,
    );
  }

  /// Состояние: соединение в процессе подключения к пиру
  WebRTCState connectingTo(String peerId, RTCPeerConnection pc) {
    return copyWith(
      phase: WebRTCPhase.connecting,
      connectedWith: peerId,
      peerConnection: pc,
      isInitiator: true,
    );
  }

  /// Состояние: соединение получено от пира (мы ответили)
  WebRTCState answeringTo(String peerId, RTCPeerConnection pc) {
    return copyWith(
      phase: WebRTCPhase.connecting,
      connectedWith: peerId,
      peerConnection: pc,
      isInitiator: false,
    );
  }

  /// Состояние: соединение установлено
  WebRTCState connected() {
    return copyWith(phase: WebRTCPhase.connected);
  }

  /// Состояние: добавлен локальный поток
  WebRTCState withLocalStreamAdded() {
    return copyWith(localStreamAdded: true);
  }

  /// Состояние: установлена локальная описание
  WebRTCState withLocalDescription(RTCSessionDescription description) {
    return copyWith(localDescription: description);
  }

  /// Состояние: установлена удалённая описание
  WebRTCState withRemoteDescription(RTCSessionDescription description) {
    return copyWith(remoteDescription: description);
  }

  /// Состояние: ошибка при соединении
  WebRTCState withError(String errorMsg) {
    return copyWith(error: errorMsg);
  }

  /// Возможно ли инициировать соединение?
  bool canInitiateCall() {
    return phase == WebRTCPhase.idle;
  }

  /// Возможно ли ответить на offer?
  bool canAnswerOffer() {
    return phase == WebRTCPhase.idle;
  }

  /// Активно ли соединение?
  bool isActive() {
    return phase == WebRTCPhase.connected;
  }

  @override
  String toString() {
    return 'WebRTCState(phase=$phase, connectedWith=$connectedWith, '
        'localStreamAdded=$localStreamAdded, isInitiator=$isInitiator, error=$error)';
  }
}
