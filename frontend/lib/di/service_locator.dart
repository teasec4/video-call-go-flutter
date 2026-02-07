import 'package:frontend/services/creat_room_service.dart';
import 'package:get_it/get_it.dart';
import 'package:uuid/uuid.dart';

final getIt = GetIt.instance;
final userId = const Uuid().v4();

void setupServiceLocator() {
  getIt.registerSingleton<RoomManager>(RoomManager(url: "http://localhost:8081", userId: userId ));
  print("room manager inited and userId is $userId");
}
