import { WebSocket } from "ws";
import { ClientMessage, ServerMessage } from "./messages";

export function connectToRoom(
  url: string,
  joinMessage: ClientMessage
) {
  const ws = new WebSocket(url);

  ws.on("open", () => {
    ws.send(JSON.stringify(joinMessage));
  });

  ws.on("message", (data) => {
    const msg = JSON.parse(data.toString()) as ServerMessage;

    switch (msg.type) {
      case "joined":
        console.log(`✅ Joined room - from: ${msg.payload.from}`);
        break;

      case "chat":
        console.log(
          `💬 [${msg.payload.from}]: ${msg.payload.data.msg}`
        );
        break;

      case "offer":
        console.log(`📬 Received offer from ${msg.payload.from}`);
        break;

      case "answer":
        console.log(`📬 Received answer from ${msg.payload.from}`);
        break;

      case "ice_candidate":
        console.log(`🧊 Received ICE candidate from ${msg.payload.from}`);
        break;

      case "error":
        console.error(
          `❌ Server error: ${msg.payload.data.error}`
        );
        ws.close();
        break;

      default:
        console.log("Unknown message type:", msg);
    }
  });

  ws.on("error", (err) => {
    console.error("❌ WS error: ", err);
  });

  ws.on("close", () => {
    console.log("🔌 WebSocket closed");
  });

  return ws;
}