const WebSocket = require("ws");

const id = process.argv[2] || "anon";
const ws = new WebSocket("ws://localhost:8081/ws");

let clientId = null;
let roomId = null;

ws.on("open", () => {
  console.log(`[${id}] Connected to server`);
});

ws.on("message", (data) => {
  const msg = JSON.parse(data.toString());
  console.log(`[${id}] Received:`, JSON.stringify(msg, null, 2));

  // Handle room-created
  if (msg.type === "room-created") {
    roomId = msg.payload.roomId;
    console.log(`[${id}] Room created: ${roomId}`);
    console.log(`[${id}] Share this roomId with other peer: ${roomId}`);
  }

  // Handle room-joined
  if (msg.type === "room-joined") {
    console.log(
      `[${id}] Successfully joined room. Peer count: ${msg.payload.peerCount}`
    );
    if (msg.payload.peerCount === 2) {
      console.log(`[${id}] Both peers connected! Ready for WebRTC`);
    }
  }

  // Handle peer-joined
  if (msg.type === "peer-joined") {
    console.log(`[${id}] Peer joined: ${msg.payload.peerId}`);
    console.log(`[${id}] You can now start WebRTC handshake`);
  }

  // Handle peer-left
  if (msg.type === "peer-left") {
    console.log(`[${id}] Peer left: ${msg.payload.peerId}`);
  }

  // Handle room-error
  if (msg.type === "room-error") {
    console.error(`[${id}] Room error: ${msg.payload.error}`);
  }

  // Handle client-id
  if (msg.type === "client-id") {
    clientId = msg.payload.id;
    console.log(`[${id}] Your client ID: ${clientId}`);
  }
});

ws.on("error", (err) => {
  console.error(`[${id}] Error:`, err);
});

ws.on("close", () => {
  console.log(`[${id}] Disconnected from server`);
});

// Interactive commands
console.log(`
[${id}] Commands:
  create       - Create a new room
  join <id>    - Join existing room by ID
  leave        - Leave current room
  offer        - Send SDP offer to peer
  answer       - Send SDP answer to peer
  ice <data>   - Send ICE candidate
  list         - List all peers (old API)
  help         - Show this help

Paste commands and press Enter...
`);

process.stdin.on("data", (data) => {
  const input = data.toString().trim();

  if (!input) return;

  const [command, ...args] = input.split(" ");

  switch (command.toLowerCase()) {
    case "create":
      ws.send(
        JSON.stringify({
          type: "create-room",
        })
      );
      console.log(`[${id}] Sent: create-room`);
      break;

    case "join":
      if (!args[0]) {
        console.log("[ERROR] Usage: join <roomId>");
        return;
      }
      roomId = args[0];
      ws.send(
        JSON.stringify({
          type: "join-room",
          payload: {
            roomId: roomId,
          },
        })
      );
      console.log(`[${id}] Sent: join-room ${roomId}`);
      break;

    case "leave":
      ws.send(
        JSON.stringify({
          type: "leave-room",
        })
      );
      console.log(`[${id}] Sent: leave-room`);
      break;

    case "offer":
      if (!args[0]) {
        console.log("[ERROR] Usage: offer <peerId>");
        return;
      }
      const peerId = args[0];
      const dummySDP = `v=0
o=- 123456 2 IN IP4 127.0.0.1
s=-
t=0 0
a=group:BUNDLE 0
a=extmap-allow-mixed
a=msid-semantic: WMS stream
m=application 9 UDP/TLS/RTP/SAVPF 120`;

      ws.send(
        JSON.stringify({
          type: "offer",
          to: peerId,
          payload: {
            sdp: dummySDP,
          },
        })
      );
      console.log(`[${id}] Sent: offer to ${peerId.substring(0, 8)}`);
      break;

    case "answer":
      if (!args[0]) {
        console.log("[ERROR] Usage: answer <peerId>");
        return;
      }
      ws.send(
        JSON.stringify({
          type: "answer",
          to: args[0],
          payload: {
            sdp: "dummy answer sdp",
          },
        })
      );
      console.log(`[${id}] Sent: answer to ${args[0].substring(0, 8)}`);
      break;

    case "ice":
      if (!args[0] || !args[1]) {
        console.log("[ERROR] Usage: ice <peerId> <candidate>");
        return;
      }
      ws.send(
        JSON.stringify({
          type: "ice-candidate",
          to: args[0],
          payload: {
            candidate: args.slice(1).join(" "),
          },
        })
      );
      console.log(`[${id}] Sent: ice-candidate to ${args[0].substring(0, 8)}`);
      break;

    case "list":
      ws.send(
        JSON.stringify({
          type: "list-peers",
        })
      );
      console.log(`[${id}] Sent: list-peers`);
      break;

    case "help":
      console.log(`
[${id}] Commands:
  create       - Create a new room
  join <id>    - Join existing room by ID
  leave        - Leave current room
  offer <id>   - Send SDP offer to peer
  answer <id>  - Send SDP answer to peer
  ice <id> <d> - Send ICE candidate
  list         - List all peers (old API)
  help         - Show this help
      `);
      break;

    default:
      console.log(`[${id}] Unknown command: ${command}`);
      console.log(`Type 'help' for available commands`);
  }
});
