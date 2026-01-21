const WebSocket = require("ws")

const ws = new WebSocket("ws://localhost:8080/ws")

ws.on("open", () => {
  console.log("connected");
  ws.send("hello from node");
});

ws.on("message", (data) => {
  console.log("from server:", data.toString());
});