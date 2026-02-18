package room

import (
	"fmt"
	"log"
	"sync"

	"github.com/google/uuid"
	"github.com/gorilla/websocket"
)

type Client struct {
	Conn *websocket.Conn
	Id   string
}

type Room struct {
	ID      string
	Clients map[string]*Client
	mu      sync.RWMutex
}

type RoomManager struct {
	Rooms map[string]*Room
	mu    sync.RWMutex
}

func NewRoomManager() *RoomManager {
	return &RoomManager{
		Rooms: map[string]*Room{},
	}
}

// BroadcastToRoom sends a message to all clients in the room.
// If a write fails, the connection is closed to prevent dead connections.
func (r *Room) BroadcastToRoom(msg []byte) error {
	r.mu.RLock()
	clients := make([]*Client, 0, len(r.Clients))
	for _, c := range r.Clients {
		clients = append(clients, c)
	}
	r.mu.RUnlock()

	for _, c := range clients {
		// Skip clients without connection
		if c.Conn == nil {
			continue
		}
		if err := c.Conn.WriteMessage(websocket.TextMessage, msg); err != nil {
			log.Println("Write error for client", c.Id, ":", err)
			return err
		}
	}
	return nil
}

// CreateRoom creates a new room with a unique UUID.
func (rm *RoomManager) CreateRoom(clientId string) string {
	rm.mu.Lock()
	defer rm.mu.Unlock()
	// generate roomId
	roomID := uuid.New().String()
	
	rm.Rooms[roomID] = &Room{
		ID:      roomID,
		Clients: map[string]*Client{},
	}

	log.Printf("room_created room_id=%s", roomID)
	return roomID
}


// JoinRoom adds a client to the room.
func (rm *RoomManager) JoinRoom(roomID string, clientId string) error {
	room, err := rm.GetRoom(roomID)
	if err != nil{
		log.Println("Get room error for room", roomID, ":", err)
		return err
	}

	room.mu.Lock()
	defer room.mu.Unlock()

	room.Clients[clientId] = &Client{
		Id: clientId,
	}

	return nil
}

func (rm *RoomManager) AttachClient(roomID, clientID string, conn *websocket.Conn) error {
    room, err := rm.GetRoom(roomID)
    if err != nil {
        return err
    }

    room.mu.Lock()
    defer room.mu.Unlock()

    client, exists := room.Clients[clientID]
    if !exists {
        // Create client if not exists
        client = &Client{
            Id:   clientID,
            Conn: conn,
        }
        room.Clients[clientID] = client
    } else {
        // Attach connection to existing client
        client.Conn = conn
    }

    return nil
}

// LeaveRoom removes a client from the room and deletes the room if empty.
func (rm *RoomManager) LeaveRoom(roomID string, c *Client) {
	room, err := rm.GetRoom(roomID)
	if err != nil{
		log.Println("Get room error for room", roomID, ":", err)
		return 
	}

	room.mu.Lock()
	delete(room.Clients, c.Id)
	isEmpty := len(room.Clients) == 0
	room.mu.Unlock()

	// Delete room if empty
	if isEmpty {
		rm.mu.Lock()
		delete(rm.Rooms, roomID)
		rm.mu.Unlock()
		log.Printf("room_deleted room_id=%s", roomID)
	}
}

// GetRoom returns a room by ID. Returns nil if not found.
func (rm *RoomManager) GetRoom(roomID string) (*Room, error){
	rm.mu.RLock()
	defer rm.mu.RUnlock()
	room, exists := rm.Rooms[roomID]
	if !exists {
		return nil, fmt.Errorf("Room does not exist")
	}
	return room, nil
}

// GetClientInRoom находит клиента в комнате по ID
func (rm *RoomManager) GetClientInRoom(roomID, clientID string) *Client {
	room, err := rm.GetRoom(roomID)
	if err != nil{
		log.Println("Get room error for room", roomID, ":", err)
		return nil
	}
    
    room.mu.RLock()
    defer room.mu.RUnlock()
    
    return room.Clients[clientID]  // ← О(1) вместо O(n)
}

// CloseAllConnection closes all client connections and clears the room manager.
func (rm *RoomManager) CloseAllConnection() {
	rm.mu.RLock()
	rooms := make([]*Room, 0, len(rm.Rooms))
	for _, room := range rm.Rooms {
		rooms = append(rooms, room)
	}
	rm.mu.RUnlock()

	// Close connections outside of lock to prevent deadlocks
	for _, room := range rooms {
		room.mu.RLock()
		clients := make([]*Client, 0, len(room.Clients))
		for _, client := range room.Clients {
			clients = append(clients, client)
			
		}
		room.mu.RUnlock()
		for _, client := range clients{
			client.Conn.Close()
			log.Printf("connection_closed client_id=%s room_id=%s", client.Id, room.ID)
		}
	}
}

