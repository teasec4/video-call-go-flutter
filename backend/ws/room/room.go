package room

import (
	"callserver/config"
	"callserver/ws/client"
	"sync"

	"github.com/google/uuid"
)

type Room struct {
	ID      string
	Clients map[string]*client.Client
	mu      sync.RWMutex
}

type RoomManager struct {
	rooms map[string]*Room
	mu    sync.RWMutex
}

func NewRoomManager() *RoomManager {
	return &RoomManager{
		rooms: make(map[string]*Room),
	}
}

// CreateRoom создает новую комнату и возвращает её UUID
func (rm *RoomManager) CreateRoom() string {
	rm.mu.Lock()
	defer rm.mu.Unlock()

	roomID := uuid.New().String()
	rm.rooms[roomID] = &Room{
		ID:      roomID,
		Clients: make(map[string]*client.Client),
	}

	return roomID
}

// JoinRoom добавляет клиента в комнату, максимум MaxPeersPerRoom клиента
func (rm *RoomManager) JoinRoom(roomID string, c *client.Client) (bool, int) {
	rm.mu.RLock()
	room, exists := rm.rooms[roomID]
	rm.mu.RUnlock()

	if !exists {
		return false, 0
	}

	room.mu.Lock()
	defer room.mu.Unlock()

	// Если уже в комнате максимум клиентов
	if len(room.Clients) >= config.MaxPeersPerRoom {
		return false, len(room.Clients)
	}

	room.Clients[c.Id] = c
	c.RoomId = roomID

	return true, len(room.Clients)
}

// LeaveRoom удаляет клиента из комнаты
func (rm *RoomManager) LeaveRoom(c *client.Client) {
	if c.RoomId == "" {
		return
	}

	roomID := c.RoomId
	c.RoomId = ""

	rm.mu.Lock()
	room, exists := rm.rooms[roomID]
	rm.mu.Unlock()

	if !exists {
		return
	}

	room.mu.Lock()
	isEmpty := false
	{
		delete(room.Clients, c.Id)
		isEmpty = len(room.Clients) == 0
	}
	room.mu.Unlock()

	// Удаляем комнату, если она пуста
	if isEmpty {
		rm.mu.Lock()
		delete(rm.rooms, roomID)
		rm.mu.Unlock()
	}
}

// GetRoom возвращает комнату по ID
func (rm *RoomManager) GetRoom(roomID string) *Room {
	rm.mu.RLock()
	defer rm.mu.RUnlock()
	return rm.rooms[roomID]
}

// GetRoomClients возвращает список клиентов в комнате
func (rm *RoomManager) GetRoomClients(roomID string) []*client.Client {
	rm.mu.RLock()
	room, exists := rm.rooms[roomID]
	rm.mu.RUnlock()

	if !exists {
		return nil
	}

	room.mu.RLock()
	defer room.mu.RUnlock()

	var clients []*client.Client
	for _, c := range room.Clients {
		clients = append(clients, c)
	}

	return clients
}

// GetRoomClientCount возвращает количество клиентов в комнате
func (rm *RoomManager) GetRoomClientCount(roomID string) int {
	rm.mu.RLock()
	room, exists := rm.rooms[roomID]
	rm.mu.RUnlock()

	if !exists {
		return 0
	}

	room.mu.RLock()
	defer room.mu.RUnlock()

	return len(room.Clients)
}

// RoomExists проверяет существует ли комната
func (rm *RoomManager) RoomExists(roomID string) bool {
	rm.mu.RLock()
	defer rm.mu.RUnlock()
	_, exists := rm.rooms[roomID]
	return exists
}
