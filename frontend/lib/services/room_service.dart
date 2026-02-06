import 'dart:async';
import 'package:frontend/models/room_model.dart';
import 'signaling_service.dart';

/// Service для управления комнатами (create, join, leave)
/// Отделён от UI логики и state management
class RoomService {
  final SignalingService signalingService;

  RoomService(this.signalingService);

  /// Создать новую комнату
  /// Возвращает ID созданной комнаты
  Future<String> createRoom() async {
    print('🔐 RoomService: Creating room...');
    
    final completer = Completer<String>();
    
    // Подписываемся на ответ один раз
    final subscription = signalingService.messageStream.listen((msg) {
      if (msg.type == 'room-created') {
        try {
          final roomId = msg.payload['roomId'] as String;
          print('✅ RoomService: Room created - ${roomId.substring(0, 8)}...');
          completer.complete(roomId);
        } catch (e) {
          completer.completeError('Invalid room-created response: $e');
        }
      }
    });

    // Отправляем запрос
    signalingService.sendMessage(
      SignalingMessage(type: 'create-room'),
    );

    // Ждём ответ с таймаутом
    try {
      final roomId = await completer.future.timeout(
        const Duration(seconds: 5),
        onTimeout: () => throw Exception('Room creation timeout'),
      );
      return roomId;
    } finally {
      subscription.cancel();
    }
  }

  /// Присоединиться к комнате
  /// Возвращает комнату с информацией о другом пире
  Future<RoomModel> joinRoom(String roomId) async {
    print('🔐 RoomService: Joining room ${roomId.substring(0, 8)}...');
    
    final completer = Completer<RoomModel>();
    
    final subscription = signalingService.messageStream.listen((msg) {
      if (msg.type == 'room-joined') {
        try {
          final responseRoomId = msg.payload['roomId'] as String;
          if (responseRoomId == roomId) {
            final room = RoomModel.fromJson(msg.payload as Map<String, dynamic>);
            print('✅ RoomService: Joined room ${room.roomId.substring(0, 8)}...');
            completer.complete(room);
          }
        } catch (e) {
          completer.completeError('Invalid room-joined response: $e');
        }
      } else if (msg.type == 'room-error') {
        final error = msg.payload['error'] as String? ?? 'Unknown error';
        completer.completeError(error);
      }
    });

    // Отправляем запрос
    signalingService.sendMessage(
      SignalingMessage(
        type: 'join-room',
        payload: {'roomId': roomId},
      ),
    );

    try {
      return await completer.future.timeout(
        const Duration(seconds: 5),
        onTimeout: () => throw Exception('Room join timeout'),
      );
    } finally {
      subscription.cancel();
    }
  }

  /// Покинуть комнату
  Future<void> leaveRoom() async {
    print('🔐 RoomService: Leaving room...');
    signalingService.sendMessage(
      SignalingMessage(type: 'leave-room'),
    );
  }

  /// Проверить валидность room ID
  bool validateRoomId(String roomId) {
    if (roomId.isEmpty) return false;
    if (roomId.length > 64) return false; // Разумный лимит
    // Только буквы, цифры и дефисы
    return RegExp(r'^[a-zA-Z0-9\-_]+$').hasMatch(roomId);
  }
}
