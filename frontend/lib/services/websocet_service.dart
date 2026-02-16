import 'dart:async';
import 'dart:convert';

import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Типы сообщений в протоколе
enum MessageType {
  handshake,
  offer,
  answer,
  iceCandidate,
  unknown,
}

/// Структурированное сообщение от сервера
class WSMessage {
  final MessageType type;
  final Map<String, dynamic> payload;

  WSMessage({required this.type, required this.payload});

  factory WSMessage.fromJson(Map<String, dynamic> json) {
    final typeStr = json['type'] as String?;
    final type = _parseMessageType(typeStr);
    return WSMessage(
      type: type,
      payload: json['data'] as Map<String, dynamic>? ?? {},
    );
  }

  static MessageType _parseMessageType(String? type) {
    return switch (type) {
      'handshake' => MessageType.handshake,
      'offer' => MessageType.offer,
      'answer' => MessageType.answer,
      'ice_candidate' => MessageType.iceCandidate,
      _ => MessageType.unknown,
    };
  }
}

/// Управляет WebSocket соединением для WebRTC сигнализации
class WebsocetService {
  late WebSocketChannel _channel;
  bool _isConnected = false;

  // Обработчики для разных типов сообщений
  Function(RTCSessionDescription)? _onOffer;
  Function(RTCSessionDescription)? _onAnswer;
  Function(RTCIceCandidate)? _onIceCandidate;
  Function(Map<String, dynamic>)? _onMessage; // fallback

  /// Подключается к WebSocket серверу и отправляет handshake
  Future<void> connect(
    String url,
    Map<String, dynamic> handshakeMessage,
  ) async {
    try {
      print('🔌 Connecting to WebSocket: $url');
      _channel = WebSocketChannel.connect(Uri.parse(url));

      print('⏳ Waiting for connection...');
      await _channel.ready;
      _isConnected = true;
      print('✅ WebSocket connected');

      print('📤 Sending handshake: $handshakeMessage');
      send(handshakeMessage);

      // Слушаем входящие сообщения
      _channel.stream.listen(
        _handleMessage,
        onError: _handleError,
        onDone: disconnect,
      );
    } catch (e) {
      print('❌ Error connecting to WebSocket: $e');
      rethrow;
    }
  }

  /// Обрабатывает входящее сообщение и вызывает нужный обработчик
  void _handleMessage(dynamic message) {
    print('📨 WebSocket received: $message');
    try {
      final Map<String, dynamic> data;

      // Парсим сообщение в зависимости от типа
      if (message is Map<String, dynamic>) {
        data = message;
      } else if (message is String) {
        data = jsonDecode(message);
      } else {
        print('❌ Unknown message type: ${message.runtimeType}');
        return;
      }

      print('📦 Parsed data: $data');
      final wsMessage = WSMessage.fromJson(data);

      // Маршрутизируем по типу сообщения
      switch (wsMessage.type) {
        case MessageType.offer:
          _handleOfferMessage(wsMessage.payload);
        case MessageType.answer:
          _handleAnswerMessage(wsMessage.payload);
        case MessageType.iceCandidate:
          _handleIceCandidateMessage(wsMessage.payload);
        case MessageType.handshake:
          print('✅ Handshake confirmed');
        case MessageType.unknown:
          _onMessage?.call(wsMessage.payload);
      }
    } catch (e) {
      print('❌ Error handling message: $e');
    }
  }

  /// Обработчик входящего offer
  void _handleOfferMessage(Map<String, dynamic> payload) {
    try {
      final sdp = payload['data'] as String?;
      if (sdp == null) {
        print('❌ Offer message missing SDP');
        return;
      }
      final offer = RTCSessionDescription(sdp, 'offer');
      _onOffer?.call(offer);
    } catch (e) {
      print('❌ Error handling offer: $e');
    }
  }

  /// Обработчик входящего answer
  void _handleAnswerMessage(Map<String, dynamic> payload) {
    try {
      final sdp = payload['data'] as String?;
      if (sdp == null) {
        print('❌ Answer message missing SDP');
        return;
      }
      final answer = RTCSessionDescription(sdp, 'answer');
      _onAnswer?.call(answer);
    } catch (e) {
      print('❌ Error handling answer: $e');
    }
  }

  /// Обработчик входящего ICE кандидата
  void _handleIceCandidateMessage(Map<String, dynamic> payload) {
    try {
      final data = payload['data'] as Map<String, dynamic>?;
      if (data == null) {
        print('❌ ICE candidate message missing data');
        return;
      }

      final candidate = RTCIceCandidate(
        data['candidate'] as String?,
        data['sdpMid'] as String?,
        data['sdpMLineIndex'] as int?,
      );
      _onIceCandidate?.call(candidate);
    } catch (e) {
      print('❌ Error handling ICE candidate: $e');
    }
  }

  void _handleError(Object error) {
    print('❌ WebSocket error: $error');
    _isConnected = false;
  }

  /// Регистрирует обработчик для offer сообщений
  void onOffer(Function(RTCSessionDescription) handler) {
    _onOffer = handler;
  }

  /// Регистрирует обработчик для answer сообщений
  void onAnswer(Function(RTCSessionDescription) handler) {
    _onAnswer = handler;
  }

  /// Регистрирует обработчик для ICE кандидатов
  void onIceCandidate(Function(RTCIceCandidate) handler) {
    _onIceCandidate = handler;
  }

  /// Регистрирует fallback обработчик для неизвестных сообщений
  void onMessage(Function(Map<String, dynamic>) handler) {
    _onMessage = handler;
  }

  /// Отправляет offer
  void sendOffer(RTCSessionDescription offer) {
    final message = {
      'type': 'offer',
      'data': offer.sdp,
    };
    send(message);
  }

  /// Отправляет answer
  void sendAnswer(RTCSessionDescription answer) {
    final message = {
      'type': 'answer',
      'data': answer.sdp,
    };
    send(message);
  }

  /// Отправляет ICE кандидата
  void sendIceCandidate(RTCIceCandidate candidate) {
    final message = {
      'type': 'ice_candidate',
      'data': {
        'candidate': candidate.candidate,
        'sdpMLineIndex': candidate.sdpMLineIndex,
        'sdpMid': candidate.sdpMid,
      }
    };
    send(message);
  }

  /// Отправляет произвольное сообщение
  void send(Map<String, dynamic> data) {
    if (!_isConnected) {
      throw Exception('WebSocket not connected');
    }
    _channel.sink.add(jsonEncode(data));
  }

  /// Закрывает соединение
  void disconnect() {
    if (!_isConnected) return;
    _isConnected = false;
    _channel.sink.close();
    print('🔌 WebSocket disconnected');
  }

  bool get isConnected => _isConnected;
}
