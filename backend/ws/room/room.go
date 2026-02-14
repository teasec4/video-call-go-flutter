package room

import (
	"callserver/types"
	"fmt"
	"log"
	"sync"

	"github.com/google/uuid"
	"github.com/gorilla/websocket"
)

type Room struct {
	ID      string
	Clients map[string]*types.Client
	Messages []*types.Message
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
func (rm *RoomManager) BroadcastToRoom(roomId string, msg []byte) {
	rm.mu.RLock()
	room, exists := rm.Rooms[roomId]
	rm.mu.RUnlock()

	if !exists {
		return
	}

	// Get snapshot of clients while holding lock
	room.mu.RLock()
	currentRoomClients := make([]*types.Client, 0, len(room.Clients))
	for _, c := range room.Clients {
		currentRoomClients = append(currentRoomClients, c)
	}
	room.mu.RUnlock()

	// Send messages without holding lock to prevent deadlocks
	for _, c := range currentRoomClients {
		if err := c.Conn.WriteMessage(websocket.TextMessage, msg); err != nil {
			log.Println("Write error for client", c.Id, ":", err)
			c.Conn.Close()
			// Remove client from room on write error
			rm.LeaveRoom(roomId, c)
		}
	}
}


// CreateRoom creates a new room with a unique UUID.
func (rm *RoomManager) CreateRoom() string {
	rm.mu.Lock()
	defer rm.mu.Unlock()

	roomID := uuid.New().String()
	rm.Rooms[roomID] = &Room{
		ID:      roomID,
		Clients: map[string]*types.Client{},
		Messages: []*types.Message{},
	}

	log.Printf("room_created room_id=%s", roomID)
	return roomID
}


// JoinRoom adds a client to the room.
func (rm *RoomManager) JoinRoom(roomID string, c *types.Client) error {
	rm.mu.RLock()
	room, exists := rm.Rooms[roomID]
	rm.mu.RUnlock()

	if !exists {
		log.Printf("room_not_found room_id=%s", roomID)
		return fmt.Errorf("room not found")
	}

	room.mu.Lock()
	defer room.mu.Unlock()

	room.Clients[c.Id] = c

	return nil
}

// LeaveRoom removes a client from the room and deletes the room if empty.
func (rm *RoomManager) LeaveRoom(roomID string, c *types.Client) {
	rm.mu.RLock()
	room, exists := rm.Rooms[roomID]
	rm.mu.RUnlock()

	if !exists {
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
func (rm *RoomManager) GetClientInRoom(roomID, clientID string) *types.Client {
    rm.mu.RLock()
    room, err := rm.GetRoom(roomID)
    rm.mu.RUnlock()
    
    if err != nil {
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
		for _, client := range room.Clients {
			client.Conn.Close()
			log.Printf("connection_closed client_id=%s room_id=%s", client.Id, room.ID)
		}
		room.mu.RUnlock()
	}
}

func (rm *RoomManager) GetMessageHistory(roomId string)([]*types.Message, bool){
	rm.mu.RLock()
	defer rm.mu.RUnlock()
	room, exist := rm.Rooms[roomId]
	if(!exist){
		return  nil, true
	}
	return room.Messages, false
}

