import { randomUUID } from "crypto";
import readline from "readline/promises";
import { connectToRoom } from "./wsClient";
import { ChatMessage } from "./messages";

async function main() {
  const id = randomUUID();
    console.log("Your ID:", id);
  
  const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout,
  });
  
  const roomId = (await rl.question("Enter room id: ")).trim();

  if (!roomId) {
    throw new Error("RoomId is empty");
  }
  
  const ws = connectToRoom("ws://localhost:8081/ws", {
    type: "join",
    clientId: id,
    roomId,
  });

  // Не закрываем readline, используем его для ввода сообщений
  rl.on("line", (input) => {
    if (ws.readyState === 1) { // WebSocket.OPEN
      const msg: ChatMessage = {
        type: "chat",
        from: id,
        payload: input.trim(),
      };
      ws.send(JSON.stringify(msg));
    } else {
      console.log("WebSocket not connected");
    }
  });
}

main();