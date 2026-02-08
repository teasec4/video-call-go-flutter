import 'package:frontend/models/message.dart';

abstract class RoomState {}

class RoomInitial extends RoomState{}

class RoomLoading extends RoomState{}

class RoomInitialized extends RoomState{
  final String roomId;
  final List<Message> messages;
  RoomInitialized({required this.roomId, required this.messages});
}

class MessageAdded extends RoomState{
  final List<Message> messages;
  MessageAdded(this.messages);
}

class RoomError extends RoomState{
  final String error;
  RoomError(this.error);
}