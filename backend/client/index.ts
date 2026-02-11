import { randomUUID } from "crypto";
import readline from "readline/promises";
import { connectToRoom } from "./wsClient";
import { ChatMessage } from "./messages";
import { createRoom } from "./createRoomHttp";

async function main() {
  const userId = randomUUID();
    console.log("Your ID:", userId);
  
  const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout,
  });
  
  let roomId = (await rl.question("Enter room id: ")).trim();

  if (!roomId) {
    // create th room
    roomId = await createRoom(userId)
  }
  
  console.log("Using room:", roomId);
  
  const ws = connectToRoom("ws://localhost:8081/ws", {
    type: "join",
    clientId: userId,
    roomId,
  });
  
  // Не закрываем readline, используем его для ввода сообщений
  rl.on("line", (input) => {
    if (ws.readyState === 1) { // WebSocket.OPEN
      const msg: ChatMessage = {
        type: "chat",
        from: userId,
        payload: input.trim(),
      };
      ws.send(JSON.stringify(msg));
    } else {
      console.log("WebSocket not connected");
    }
  });
}

main();