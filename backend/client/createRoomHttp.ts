const API_URL = "http://localhost:8081";

export async function createRoom(userId:string) : Promise<string> {
  const res = await fetch(`${API_URL}/createroom`, {
    method: 'POST',
    headers: {
      "Content-Type": "application/json",
    },
    body:JSON.stringify({"clientId" : userId})
  })
  
  console.log(`response: ${res}`)
  
  if (!res.ok) {
    const text = await res.text();
    let errorMsg = "failed to create room";
    
    try {
      const jsonErr = JSON.parse(text);
      errorMsg = jsonErr.error || text;
    } catch {
      errorMsg = text;
    }
    
    console.log('Error response:', errorMsg);
    throw new Error(errorMsg);
  }
  
  const data: { roomId: string } = await res.json();
  return data.roomId; 
}