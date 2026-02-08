import 'package:frontend/models/message.dart';

abstract class RoomEvent {}

class InitializeRoomEvent extends RoomEvent{
  final String roomId;
  InitializeRoomEvent(this.roomId);  
}

class SendMessageEvent extends RoomEvent{
  final String message;
  SendMessageEvent(this.message);
}

class MessageReceivedEvent extends RoomEvent{
  final Message message;
  MessageReceivedEvent(this.message);
}

class RoomInitializedEvent extends RoomEvent{
  final String roomId;
  RoomInitializedEvent(this.roomId);
}
