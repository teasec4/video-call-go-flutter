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
	Clients []*types.Client
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


func (rm *RoomManager) CreateRoom(client *types.Client) string {
	rm.mu.Lock()
	defer rm.mu.Unlock()

	roomID := uuid.New().String()
	rm.Rooms[roomID] = &Room{
		ID:      roomID,
		Clients: []*types.Client{client},
		Messages: []*types.Message{},
	}
	
	fmt.Println("✅ Created Room:", roomID, "with Client:", client.Id)
	return roomID
}

func (rm *RoomManager) JoinRoom(roomID string, c *types.Client) {
	rm.mu.RLock()
	room, exists := rm.Rooms[roomID]
	rm.mu.RUnlock()

	if !exists {
		log.Println("ERROR: Room not found:", roomID)
		return
	}

	room.mu.Lock()
	defer room.mu.Unlock()

	room.Clients = append(room.Clients, c)

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
	// Находим и удаляем клиента
	for i, client := range room.Clients {
		if client.Id == c.Id {
			room.Clients = append(room.Clients[:i], room.Clients[i+1:]...)
			break
		}
	}
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
	room := rm.GetRoom(roomID)
	if room == nil {
		return nil
	}

	room.mu.RLock()
	defer room.mu.RUnlock()

	for _, c := range room.Clients {
		if c.Id == clientID {
			return c
		}
	}

	return nil
}

