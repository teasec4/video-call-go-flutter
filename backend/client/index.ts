import { randomUUID } from "crypto";
import readline from "readline/promises";
import { connectToRoom } from "./wsClient";
import { ChatMessage, JoinMessage } from "./messages";
import { createRoom, joinRoom } from "./createRoomHttp";

async function main() {
  const userId = randomUUID();
  console.log("👤 Your ID:", userId);

  const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout,
  });

  let roomId = (await rl.question("📝 Enter room id (or press Enter to create new): ")).trim();

  if (!roomId) {
    console.log("🔨 Creating room...");
    roomId = await createRoom(userId);
  } else {
    console.log("🔨 Joining room...");
    await joinRoom(roomId, userId);
  }

  console.log("🎯 Using room:", roomId);

  const joinMessage: JoinMessage = {
    type: "join",
    payload: {
      from: userId,
      to: "server",
      data: {
        roomId,
      },
    },
  };

  const ws = connectToRoom("ws://localhost:8081/ws", joinMessage);

  // Read messages from stdin and send to room
  rl.on("line", (input) => {
    if (ws.readyState === 1) {
      // WebSocket.OPEN
      const msg: ChatMessage = {
        type: "chat",
        payload: {
          from: userId,
          to: "broadcast",
          data: {
            msg: input.trim(),
          },
        },
      };
      ws.send(JSON.stringify(msg));
    } else {
      console.log("⚠️  WebSocket not connected");
    }
  });
}

main();