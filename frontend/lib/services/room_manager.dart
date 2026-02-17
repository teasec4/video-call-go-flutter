import 'package:frontend/models/decode_message.dart';
import 'package:frontend/models/message.dart';
import 'package:frontend/services/http_room_service.dart';
import 'package:frontend/services/signaling_service.dart';
import 'package:frontend/services/websocet_service.dart';
import 'package:frontend/services/webrtc/webrtc_service.dart';

/// Управляет комнатой и координирует HTTP + WebSocket + WebRTC
class RoomManager {
  final String wsUrl;
  final String userId;
  final HttpRoomService httpRoomService;
  final WebsocetService websocetService;
  final WebRTCService webrtcService;
  late final SignalingService signalingService;

  List<BaseMessage> messages = [];
  Function(BaseMessage)? onMessageReceived;

  RoomManager({
    required this.wsUrl,
    required this.userId,
    required this.httpRoomService,
    required this.websocetService,
    required this.webrtcService,
  }) {
    signalingService = SignalingService(
      websocetService: websocetService,
      webrtcService: webrtcService,
    );
  }

  late String _currentRoomId;
  bool _isInitialized = false;

  /// Создаёт новую комнату и подключается к ней
  Future<String> createAndJoinRoom() async {
    try {
      final roomId = await httpRoomService.createRoom(userId);
      _currentRoomId = roomId;
      await _setupConnection();
      return roomId;
    } catch (e) {
      print('❌ Error creating room: $e');
      rethrow;
    }
  }

  /// Присоединяется к существующей комнате
  Future<void> joinExistingRoom(String roomId) async {
    try {
      await httpRoomService.joinRoom(roomId, userId);
      _currentRoomId = roomId;
      await _setupConnection();
    } catch (e) {
      print('❌ Error joining room: $e');
      rethrow;
    }
  }

  /// Общая логика подключения к WebSocket и инициализации WebRTC
  Future<void> _setupConnection() async {
    try {
      final roomId = _currentRoomId;
      if (roomId.isEmpty) {
        throw Exception('Room ID is not set');
      }

      // 1️⃣ Инициализируем WebRTC сервис
      print('🎬 Initializing WebRTC...');
      await webrtcService.initialize();

      // 2️⃣ Настраиваем WebRTC сигнализацию через WebSocket
      signalingService.setupSignaling();

      // 3️⃣ Регистрируем обработчик для чат-сообщений
      websocetService.onMessage((data) {
        print('📨 WebSocket message received: $data');
        try {
          final message = decodeMessage(data);
          print('✅ Message decoded: $message');
          if (onMessageReceived != null) {
            onMessageReceived!(message);
          }
        } catch (e) {
          print('❌ Error decoding message: $e');
        }
      });

      // 4️⃣ Подключаемся к WebSocket
      final joinMessage = JoinRoomMessage(clientId: userId, roomId: roomId);
      await websocetService.connect(wsUrl, joinMessage.toJson());

      _isInitialized = true;
      print('✅ Room fully initialized with WebRTC + WebSocket');
    } catch (e) {
      print('❌ Error setting up connection: $e');
      rethrow;
    }
  }

  /// Инициирует исходящий звонок
  /// Вызывается только caller-ом после успешного подключения к комнате
  Future<void> startCall() async {
    if (!_isInitialized) {
      throw Exception('RoomManager must be initialized before starting call');
    }
    print('📞 Starting outgoing call...');
    await webrtcService.startAsCallerAsync();
  }

  /// Отправляет чат-сообщение в комнату
  void sendChatMessage(String payload) {
    try {
      final message = ChatMessage(from: userId, payload: payload);
      websocetService.send(message.toJson());
      print('✅ Chat message sent: $payload');
    } catch (e) {
      print('❌ Error sending chat message: $e');
    }
  }

  /// Отключается от комнаты и очищает ресурсы
  void disconnect() {
    print('🔌 Disconnecting from room...');
    webrtcService.dispose();
    websocetService.disconnect();
    _isInitialized = false;
  }
}
