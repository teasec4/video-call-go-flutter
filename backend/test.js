const WebSocket = require("ws")
const {randomUUID} = require("crypto")
const readline = require("readline");

const rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout,
});

const id = randomUUID() || "anon";
console.log("Your ID:", id);


rl.question("Enter room id: ", (roomId) => {
  roomId = roomId.trim();
  if (!roomId) {
    console.log("RoomId is Empty");
    process.exit(1)
  }
  console.log("Room ID:", roomId);
  
  rl.close()
  
  connectToRoom({
    id,
    roomId
  })
})

   
function connectToRoom({ id, roomId }) {
  console.log(`Trying to connect to roomId: ${roomId}`);

  const ws = new WebSocket("ws://localhost:8081/ws");

  ws.on("open", () => {
    ws.send(JSON.stringify({
      clientId: id,
      roomId: roomId
    }));

    console.log(`Connected to room ${roomId}`);

    process.stdin.on("data", (data) => {
      ws.send(JSON.stringify({
        type: "chat",
        from: id,
        payload: data.toString().trim()
      }));
    });
  });

  ws.on("message", (data) => {
    console.log(`[${id}] got:`, data.toString());
  });

  ws.on("error", (err) => {
    console.error("WS error:", err);
  });
}