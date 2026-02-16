import 'dart:convert';
import 'package:frontend/models/decode_message.dart';
import 'package:frontend/models/message.dart';
import 'package:frontend/services/signaling_service.dart';
import 'package:frontend/services/websocet_service.dart';
import 'package:frontend/services/webrtc_service_new.dart';
import 'package:http/http.dart' as http;

/// Управляет созданием/присоединением к комнате и координирует WebRTC + WebSocket
class RoomManager {
  final String url;
  final String wsUrl;
  final String userId;
  final WebsocetService websocetService;
  final WebRTCService webrtcService;
  late final SignalingService signalingService;

  List<BaseMessage> messages = [];
  Function(BaseMessage)? onMessageReceived;

  RoomManager({
    required this.url,
    required this.wsUrl,
    required this.userId,
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

  /// Создаёт новую комнату через HTTP и подключается к WebSocket
  Future<String> createAndJoinRoom() async {
    try {
      print('Creating room at: $url/room');

      final response = await http.post(
        Uri.parse('$url/createroom'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'clientId': userId}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        _currentRoomId = data['roomId'];
        print('✅ Room created: $_currentRoomId');

        // Сразу подключаемся к WebSocket
        await connectToWs();
        return _currentRoomId;
      } else {
        throw Exception('Failed to create room: ${response.statusCode}');
      }
    } catch (e) {
      print('Error creating room: $e');
      rethrow;
    }
  }

  /// Присоединяется к существующей комнате через HTTP и подключается к WebSocket
  Future<void> joinExistingRoom(String roomId) async {
    try {
      print('Joining room at: $url/room');
      print('DEBUG: roomId=$roomId, clientId=$userId');

      final response = await http.post(
        Uri.parse('$url/room'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'roomId': roomId, 'clientId': userId}),
      );

      print('DEBUG: Response status=${response.statusCode}, body=${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        _currentRoomId = roomId;
        print('✅ Room joined: $_currentRoomId');

        // Сразу подключаемся к WebSocket
        await connectToWs();
      } else {
        throw Exception('Failed to join room: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Error joining room: $e');
      rethrow;
    }
  }

  /// Подключается к WebSocket, инициализирует WebRTC и регистрирует обработчики
  Future<void> connectToWs() async {
    try {
      final roomId = _currentRoomId;
      if (roomId.isEmpty) {
        throw Exception('Room ID is not set');
      }

      // 1️⃣ Инициализируем WebRTC сервис (без создания offer)
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

      // 4️⃣ Подключаемся к WebSocket и отправляем join message
      final joinMessage = JoinRoomMessage(clientId: userId, roomId: roomId);
      await websocetService.connect(wsUrl, joinMessage.toJson());

      _isInitialized = true;
      print('✅ Room fully initialized with WebRTC + WebSocket');
    } catch (e) {
      print('❌ Error connecting to WebSocket: $e');
      rethrow;
    }
  }

  /// Инициирует исходящий звонок (создаёт и отправляет offer)
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

  /// Отключается от WebSocket и очищает ресурсы
  void disconnect() {
    print('🔌 Disconnecting from room...');
    webrtcService.dispose();
    websocetService.disconnect();
    _isInitialized = false;
  }
}
