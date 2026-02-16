import 'package:frontend/services/creat_room_service.dart';
import 'package:frontend/services/webrtc_service_new.dart';

import 'package:frontend/services/websocet_service.dart';
import 'package:get_it/get_it.dart';
import 'package:uuid/uuid.dart';

final getIt = GetIt.instance;
final userId = const Uuid().v4();

void setupServiceLocator() {
  // WS
  getIt.registerSingleton<WebsocetService>(WebsocetService());

  // WebRTCService
  getIt.registerSingleton<WebRTCService>(WebRTCService(
    websocetService: getIt<WebsocetService>(),
  ));

  
  getIt.registerSingleton<RoomManager>(
    RoomManager(
      url: "http://localhost:8081",
      wsUrl: "ws://localhost:8081/ws",
      userId: userId,
      websocetService: getIt<WebsocetService>(),
    ),
  );
  print("room manager inited and userId is $userId");
}
