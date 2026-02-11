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

func (rm* RoomManager) BroadcastToRoom(roomId string, msg []byte){
	rm.mu.RLock()
	room, exists := rm.Rooms[roomId]
	rm.mu.RUnlock()
	
	if !exists {
		return
	}
	
	room.mu.RLock()
	defer room.mu.RUnlock()
	for _, c := range room.Clients{
		if err := c.Conn.WriteMessage(websocket.TextMessage, msg); err != nil {
			log.Println("Broadcast error:", err)
		}
	}
}


func (rm *RoomManager) CreateRoom() string {
	rm.mu.Lock()
	defer rm.mu.Unlock()

	roomID := uuid.New().String()
	rm.Rooms[roomID] = &Room{
		ID:      roomID,
		Clients: map[string]*types.Client{},
		Messages: []*types.Message{},
	}
	
	fmt.Println("✅ Created Room:", roomID)
	return roomID
}


func (rm *RoomManager) JoinRoom(roomID string, c *types.Client) error {
	rm.mu.RLock()
	room, exists := rm.Rooms[roomID]
	rm.mu.RUnlock()

	if !exists {
		log.Println("ERROR: Room not found:", roomID)
		return fmt.Errorf("room not found")
	}
	// TASK: add ERROR for client
	// return bool, error

	room.mu.Lock()
	defer room.mu.Unlock()

	room.Clients[c.Id] = c

	return nil
}

// LeaveRoom удаляет клиента из комнаты
func (rm *RoomManager) LeaveRoom(roomID string, c *types.Client) {
	rm.mu.Lock()
	room, exists := rm.Rooms[roomID]
	rm.mu.Unlock()

	if !exists {
		return
	}

	room.mu.Lock()
	delete(room.Clients, c.Id)  // ← Удаляем из map
	isEmpty := len(room.Clients) == 0
	room.mu.Unlock()

	// Удаляем комнату, если она пуста
	if isEmpty {
		rm.mu.Lock()
		delete(rm.Rooms, roomID)
		rm.mu.Unlock()
		fmt.Println("🗑️ Room deleted:", roomID)
	}
}

// GetRoom возвращает комнату по ID
func (rm *RoomManager) GetRoom(roomID string) *Room {
	rm.mu.RLock()
	defer rm.mu.RUnlock()
	return rm.Rooms[roomID]
}

// GetClientInRoom находит клиента в комнате по ID
func (rm *RoomManager) GetClientInRoom(roomID, clientID string) *types.Client {
    rm.mu.RLock()
    room, exists := rm.Rooms[roomID]
    rm.mu.RUnlock()
    
    if !exists {
        return nil
    }
    
    room.mu.RLock()
    defer room.mu.RUnlock()
    
    return room.Clients[clientID]  // ← О(1) вместо O(n)
}

func (rm *RoomManager) CloseAllConnection(){
	rm.mu.RLock()
	defer rm.mu.RUnlock()
	
	for _, room := range rm.Rooms{
		room.mu.RLock()
		for _, client := range room.Clients{
			client.Conn.Close()
			fmt.Println("Close Conncetion with: ", client.Id)
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

