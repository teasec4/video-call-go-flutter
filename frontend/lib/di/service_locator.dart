import 'package:frontend/services/http_room_service.dart';
import 'package:frontend/services/room_manager.dart';
import 'package:frontend/services/signaling_service.dart';
import 'package:frontend/services/websocet_service.dart';
import 'package:frontend/services/webrtc/local_media_service.dart';
import 'package:frontend/services/webrtc/peer_connection_service.dart';
import 'package:frontend/services/webrtc/webrtc_service.dart';
import 'package:get_it/get_it.dart';
import 'package:uuid/uuid.dart';

final getIt = GetIt.instance;
final userId = const Uuid().v4();

void setupServiceLocator() {
  const String baseUrl = "http://localhost:8081";
  const String wsUrl = "ws://localhost:8081/ws";

  // WebSocket Service
  getIt.registerSingleton<WebsocetService>(WebsocetService());

  // Local Media Service
  getIt.registerSingleton<LocalMediaService>(LocalMediaService());

  // Peer Connection Service
  getIt.registerSingleton<PeerConnectionService>(PeerConnectionService());

  // WebRTC Service (координирует медиа и P2P)
  getIt.registerSingleton<WebRTCService>(
    WebRTCService(
      websocetService: getIt<WebsocetService>(),
      localMediaService: getIt<LocalMediaService>(),
      peerConnectionService: getIt<PeerConnectionService>(),
    ),
  );

  // Signaling Service (WebRTC + WebSocket сигнализация)
  getIt.registerSingleton<SignalingService>(
    SignalingService(
      websocetService: getIt<WebsocetService>(),
      webrtcService: getIt<WebRTCService>(),
    ),
  );

  // HTTP Room Service (создание/присоединение комнаты)
  getIt.registerSingleton<HttpRoomService>(
    HttpRoomService(baseUrl: baseUrl),
  );

  // Room Manager (оркестрирует всё)
  getIt.registerSingleton<RoomManager>(
    RoomManager(
      wsUrl: wsUrl,
      userId: userId,
      httpRoomService: getIt<HttpRoomService>(),
      websocetService: getIt<WebsocetService>(),
      webrtcService: getIt<WebRTCService>(),
    ),
  );

  print('✅ Service locator initialized with userId: $userId');
}
