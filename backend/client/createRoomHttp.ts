const API_URL = "http://localhost:8080";

export async function createRoom(userId:string) : Promise<string> {
  const res = await fetch(`${API_URL}/createroom`, {
    method: 'POST',
    headers: {
      "Content-Type": "application/json",
    },
    body:JSON.stringify({userId})
  })
  
  if (!res.ok) {
    const err = await res.json();
    throw new Error(err.error || "failed to create room");
  }
  
  const data: { roomId: string } = await res.json();
  return data.roomId; 
}