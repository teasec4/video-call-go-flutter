import { WebSocket } from "ws";
import { ClientMessage, ServerMessage } from "./messages";


export function connectToRoom(
  url: string,
  joinMessage: ClientMessage
) {
  const ws = new WebSocket(url);
  
  ws.on("open", () => {
    ws.send(JSON.stringify(joinMessage))
  })
  
  ws.on("message", (data) => {
    const msg = JSON.parse(data.toString()) as ServerMessage;
    
    switch (msg.type) {
      case "joined":
        console.log(`Joined room ${msg.roomId}`);
        break;

      case "chat":
        console.log(`[${msg.from}]: ${msg.payload}`);
        break;

      case "error":
        console.error("Server error:", msg.payload);
        ws.close();
        break;
    }
  })
  
  ws.on("error", (err) => {
    console.log("WS error: ", err)
  })
  
  return ws
}