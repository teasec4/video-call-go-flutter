/// Модель комнаты
class RoomModel {
  final String roomId;
  final int peerCount;
  final String creatorId;
  final DateTime createdAt;

  const RoomModel({
    required this.roomId,
    required this.peerCount,
    required this.creatorId,
    required this.createdAt,
  });

  factory RoomModel.fromJson(Map<String, dynamic> json) {
    return RoomModel(
      roomId: json['roomId'] as String,
      peerCount: json['peerCount'] as int? ?? 1,
      creatorId: json['creatorId'] as String? ?? '',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'roomId': roomId,
    'peerCount': peerCount,
    'creatorId': creatorId,
    'createdAt': createdAt.toIso8601String(),
  };

  RoomModel copyWith({
    String? roomId,
    int? peerCount,
    String? creatorId,
    DateTime? createdAt,
  }) {
    return RoomModel(
      roomId: roomId ?? this.roomId,
      peerCount: peerCount ?? this.peerCount,
      creatorId: creatorId ?? this.creatorId,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() => 'RoomModel(id: ${roomId.substring(0, 8)}, peers: $peerCount)';
}

/// Состояние комнаты для UI
class RoomState {
  final RoomModel? currentRoom;
  final String? connectedPeerId;
  final bool isLoading;
  final String? error;

  const RoomState({
    this.currentRoom,
    this.connectedPeerId,
    this.isLoading = false,
    this.error,
  });

  factory RoomState.initial() {
    return const RoomState(
      currentRoom: null,
      connectedPeerId: null,
      isLoading: false,
      error: null,
    );
  }

  RoomState copyWith({
    RoomModel? currentRoom,
    String? connectedPeerId,
    bool? isLoading,
    String? error,
  }) {
    return RoomState(
      currentRoom: currentRoom ?? this.currentRoom,
      connectedPeerId: connectedPeerId ?? this.connectedPeerId,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  bool get isInRoom => currentRoom != null;
  bool get hasConnectedPeer => connectedPeerId?.isNotEmpty ?? false;

  @override
  String toString() => 'RoomState(room: $currentRoom, peer: $connectedPeerId, loading: $isLoading)';
}
