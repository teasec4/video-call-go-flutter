const WebSocket = require("ws")

const id = process.argv[2] || "anon";
const ws = new WebSocket("ws://localhost:8080/ws")

ws.on("open", () => {
  console.log(`[${id}] connected`);
});

ws.on("message", (data) => {
  console.log(`[${id}] got:`, data.toString());
});

// manuall sending
process.stdin.on("data", (data) => {
  ws.send(JSON.stringify({
    type: "chat",
    from: id,
    payload: data.toString().trim()
  }));
});