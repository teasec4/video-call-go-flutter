import { ServerReqCreateRoom, ServerReqJoinRoom, ServerResRoomCreated } from "./messages";


const API_URL = "http://localhost:8081";

export async function createRoom(clientId: string): Promise<string> {
  const req: ServerReqCreateRoom = {
    type: "create",
    payload: {
      roomId: "", // empty string to create new room
      clientId,
    },
  };

  const res = await fetch(`${API_URL}/room`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify(req),
  });

  if (!res.ok) {
    const text = await res.text();
    let errorMsg = "failed to create room";

    try {
      const jsonErr = JSON.parse(text);
      errorMsg = jsonErr.error || text;
    } catch {
      errorMsg = text;
    }

    console.error("❌ Create room error:", errorMsg);
    throw new Error(errorMsg);
  }

  const data : ServerResRoomCreated = await res.json();
  let roomId = data.payload.roomId;
  console.log(`room id: ${roomId}`)
  return roomId;
}

export async function joinRoom(roomId: string, clientId: string){
  const req: ServerReqJoinRoom = {
    type: "join",
    payload: {
      roomId: roomId,
      clientId: clientId,
    }
  }
  
  const res = await fetch(`${API_URL}/room`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify(req),
  });

  if (!res.ok) {
    const text = await res.text();
    let errorMsg = "failed to create room";

    try {
      const jsonErr = JSON.parse(text);
      errorMsg = jsonErr.error || text;
    } catch {
      errorMsg = text;
    }

    console.error("❌ Create room error:", errorMsg);
    throw new Error(errorMsg);
  }

  const data = await res.json();
  console.log(`✅ Joined room: ${data.payload.roomId}`)
}