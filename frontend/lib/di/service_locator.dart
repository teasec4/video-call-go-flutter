import 'package:frontend/services/creat_room_service.dart';
import 'package:get_it/get_it.dart';

final getIt = GetIt.instance;

void setupServiceLocator() {
  getIt.registerSingleton<RoomManager>(RoomManager(url: "http://localhost:8081"));
  print("room manager inited");
}
