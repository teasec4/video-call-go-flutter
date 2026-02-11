import 'package:frontend/models/message.dart';

abstract class RoomEvent {}

class InitializeRoomEvent extends RoomEvent {
  final String roomId;
  InitializeRoomEvent(this.roomId);
}

class SendMessageEvent extends RoomEvent {
  final String message;
  SendMessageEvent(this.message);
}

class MessageReceivedEvent extends RoomEvent {
  final BaseMessage message;
  MessageReceivedEvent(this.message);
}
