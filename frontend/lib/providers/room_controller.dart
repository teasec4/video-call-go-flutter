import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/models/room_model.dart';
import 'package:frontend/services/room_service.dart';
import 'package:frontend/services/signaling_service.dart';

/// StateNotifier для управления состоянием комнаты
class RoomController extends StateNotifier<RoomState> {
  final RoomService _roomService;

  RoomController(this._roomService) : super(RoomState.initial());

  /// Создать новую комнату
  Future<void> createRoom() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final roomId = await _roomService.createRoom();
      final room = RoomModel(
        roomId: roomId,
        peerCount: 1,
        creatorId: '', // TODO: add client ID
        createdAt: DateTime.now(),
      );
      state = state.copyWith(
        currentRoom: room,
        isLoading: false,
      );
      print('✅ Room created in controller: $room');
    } catch (e) {
      print('❌ Room creation failed: $e');
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
      rethrow;
    }
  }

  /// Присоединиться к комнате
  Future<void> joinRoom(String roomId) async {
    if (!_roomService.validateRoomId(roomId)) {
      throw Exception('Invalid room ID format');
    }

    state = state.copyWith(isLoading: true, error: null);
    try {
      final room = await _roomService.joinRoom(roomId);
      state = state.copyWith(
        currentRoom: room,
        connectedPeerId: room.copyWith(), // Will be set by peer-joined message
        isLoading: false,
      );
      print('✅ Room joined in controller: $room');
    } catch (e) {
      print('❌ Room join failed: $e');
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
      rethrow;
    }
  }

  /// Покинуть комнату
  Future<void> leaveRoom() async {
    try {
      await _roomService.leaveRoom();
      state = RoomState.initial();
      print('✅ Left room');
    } catch (e) {
      print('❌ Leave room failed: $e');
      state = state.copyWith(error: e.toString());
    }
  }

  /// Обновить информацию о подключённом пире (вызывается из signaling)
  void setConnectedPeer(String peerId) {
    state = state.copyWith(connectedPeerId: peerId);
    print('👥 Connected peer set: ${peerId.substring(0, 8)}...');
  }

  /// Обновить количество пиров
  void updatePeerCount(int count) {
    if (state.currentRoom != null) {
      state = state.copyWith(
        currentRoom: state.currentRoom!.copyWith(peerCount: count),
      );
    }
  }

  /// Очистить ошибку
  void clearError() {
    state = state.copyWith(error: null);
  }
}

/// Provider для RoomService
final roomServiceProvider = Provider((ref) {
  final signalingService = ref.watch(signalingServiceProvider);
  return RoomService(signalingService);
});

/// Provider для RoomController
final roomControllerProvider = StateNotifierProvider<RoomController, RoomState>(
  (ref) {
    final roomService = ref.watch(roomServiceProvider);
    return RoomController(roomService);
  },
);

/// Удобные providers для чтения отдельных свойств
final currentRoomProvider = Provider((ref) {
  return ref.watch(roomControllerProvider).currentRoom;
});

final connectedPeerProvider = Provider((ref) {
  return ref.watch(roomControllerProvider).connectedPeerId;
});

final isInRoomProvider = Provider((ref) {
  return ref.watch(roomControllerProvider).isInRoom;
});

final roomLoadingProvider = Provider((ref) {
  return ref.watch(roomControllerProvider).isLoading;
});

final roomErrorProvider = Provider((ref) {
  return ref.watch(roomControllerProvider).error;
});
