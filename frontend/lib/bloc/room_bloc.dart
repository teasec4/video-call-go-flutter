import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend/bloc/room_event.dart';
import 'package:frontend/bloc/room_state.dart';
import 'package:frontend/services/creat_room_service.dart';

class RoomBloc extends Bloc<RoomEvent, RoomState> {
  final RoomManager roomManager;

  RoomBloc({required this.roomManager}) : super(RoomInitial()) {
    on<InitializeRoomEvent>(_onInitializeRoom);
    on<SendMessageEvent>(_onSendMessage);
    on<MessageReceivedEvent>(_onMessageReceived);
  }

  Future<void> _onInitializeRoom(
    InitializeRoomEvent event,
    Emitter<RoomState> emit,
  ) async {
    // Emit loading state while establishing WebSocket connection
    emit(RoomLoading());
    
    try {
      print('RoomBloc: Connecting to WebSocket...');
      await roomManager.connectToWs();
      print('RoomBloc: Connected to WebSocket');
      
      // Set up callback for incoming messages
      roomManager.onMessageReceived = (message) {
        print('RoomBloc: Received message: $message');
        add(MessageReceivedEvent(message));
      };
      
      print('RoomBloc: Emitting RoomInitialized');
      // Emit initialized state with room ID and initial messages
      emit(RoomInitialized(
        roomId: event.roomId,
        messages: roomManager.messages,
      ));
    } catch (e) {
      print('RoomBloc: Error - $e');
      emit(RoomError(e.toString()));
    }
  }
  
  Future<void> _onMessageReceived(
    MessageReceivedEvent event,
    Emitter<RoomState> emit,
  ) async {
    final currentState = state;
    
    // Handle message received from WebSocket
    if (currentState is RoomInitialized) {
      // Add new message to the existing list and emit updated state
      emit(MessageAdded([...currentState.messages, event.message]));
    } else if (currentState is MessageAdded) {
      // If already in MessageAdded state, append message to current list
      emit(MessageAdded([...currentState.messages, event.message]));
    }
  }
  
  Future<void> _onSendMessage(
    SendMessageEvent event,
    Emitter<RoomState> emit,
  ) async {
    try {
      print('RoomBloc: Sending message: ${event.message}');
      
      // Send message through WebSocket
      // Do not emit state after sending - UI updates only when MessageReceivedEvent arrives
      roomManager.websocetService.send({
        'type': 'chat',
        'from': roomManager.userId,
        'payload': event.message,
      });
      
      print('RoomBloc: Message sent successfully');
    } catch (e) {
      print('RoomBloc: Error sending message: $e');
      emit(RoomError(e.toString()));
    }
  }
}
