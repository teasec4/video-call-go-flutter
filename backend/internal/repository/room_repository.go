package repository

import (
	"callserver/internal/domain"
	"log"
	"sync"

	"github.com/gorilla/websocket"
)

// InMemoryRoomRepository реализация RoomRepository с хранилищем в памяти
type InMemoryRoomRepository struct {
	rooms map[string]*domain.Room
	mu    sync.RWMutex
}

// NewInMemoryRoomRepository создаёт новый InMemoryRoomRepository
func NewInMemoryRoomRepository() domain.RoomRepository {
	return &InMemoryRoomRepository{
		rooms: make(map[string]*domain.Room),
	}
}

// CreateRoom создаёт новую комнату
func (repo *InMemoryRoomRepository) CreateRoom(roomID string) (*domain.Room, error) {
	repo.mu.Lock()
	defer repo.mu.Unlock()
	
	if _, exists := repo.rooms[roomID]; exists {
		return nil, domain.ErrRoomAlreadyExists
	}
	
	room := &domain.Room{
		ID:      roomID,
		Clients: make(map[string]*domain.Client),
	}
	
	repo.rooms[roomID] = room
	log.Printf("room_created room_id=%s", roomID)
	
	return room, nil
}

// GetRoom получает комнату по ID
func (repo *InMemoryRoomRepository) GetRoom(roomID string) (*domain.Room, error) {
	repo.mu.RLock()
	defer repo.mu.RUnlock()
	
	room, exists := repo.rooms[roomID]
	if !exists {
		return nil, domain.ErrRoomNotFound
	}
	
	return room, nil
}

// DeleteRoom удаляет комнату
func (repo *InMemoryRoomRepository) DeleteRoom(roomID string) error {
	repo.mu.Lock()
	defer repo.mu.Unlock()
	
	if _, exists := repo.rooms[roomID]; !exists {
		return domain.ErrRoomNotFound
	}
	
	delete(repo.rooms, roomID)
	log.Printf("room_deleted room_id=%s", roomID)
	
	return nil
}

// AddClientToRoom добавляет клиента в комнату
func (repo *InMemoryRoomRepository) AddClientToRoom(roomID, clientID string) error {
	repo.mu.RLock()
	room, exists := repo.rooms[roomID]
	repo.mu.RUnlock()
	
	if !exists {
		return domain.ErrRoomNotFound
	}
	
	room.Clients[clientID] = &domain.Client{
		ID: clientID,
	}
	
	log.Printf("client_added_to_room room_id=%s client_id=%s", roomID, clientID)
	return nil
}

// AttachConnectionToClient присоединяет WebSocket соединение к клиенту
func (repo *InMemoryRoomRepository) AttachConnectionToClient(roomID, clientID string, conn *websocket.Conn) error {
	repo.mu.RLock()
	room, exists := repo.rooms[roomID]
	repo.mu.RUnlock()
	
	if !exists {
		return domain.ErrRoomNotFound
	}
	
	client, exists := room.Clients[clientID]
	if !exists {
		// Создаём клиента, если его ещё нет
		client = &domain.Client{
			ID:   clientID,
			Conn: conn,
		}
		room.Clients[clientID] = client
	} else {
		// Присоединяем соединение к существующему клиенту
		client.Conn = conn
	}
	
	log.Printf("connection_attached room_id=%s client_id=%s", roomID, clientID)
	return nil
}

// RemoveClientFromRoom удаляет клиента из комнаты
func (repo *InMemoryRoomRepository) RemoveClientFromRoom(roomID, clientID string) error {
	repo.mu.RLock()
	room, exists := repo.rooms[roomID]
	repo.mu.RUnlock()
	
	if !exists {
		return domain.ErrRoomNotFound
	}
	
	client, exists := room.Clients[clientID]
	if !exists {
		return domain.ErrClientNotFound
	}
	
	// Закрываем соединение, если оно существует
	if client.Conn != nil {
		_ = client.Conn.Close()
	}
	
	delete(room.Clients, clientID)
	log.Printf("client_removed_from_room room_id=%s client_id=%s", roomID, clientID)
	
	return nil
}

// GetClientFromRoom получает клиента из комнаты
func (repo *InMemoryRoomRepository) GetClientFromRoom(roomID, clientID string) (*domain.Client, error) {
	repo.mu.RLock()
	room, exists := repo.rooms[roomID]
	repo.mu.RUnlock()
	
	if !exists {
		return nil, domain.ErrRoomNotFound
	}
	
	client, exists := room.Clients[clientID]
	if !exists {
		return nil, domain.ErrClientNotFound
	}
	
	return client, nil
}

// GetAllClientsInRoom получает всех клиентов в комнате
func (repo *InMemoryRoomRepository) GetAllClientsInRoom(roomID string) ([]*domain.Client, error) {
	repo.mu.RLock()
	room, exists := repo.rooms[roomID]
	repo.mu.RUnlock()
	
	if !exists {
		return nil, domain.ErrRoomNotFound
	}
	
	// Берём снимок clients под прямым доступом (без отдельной блокировки)
	clients := make([]*domain.Client, 0, len(room.Clients))
	for _, client := range room.Clients {
		clients = append(clients, client)
	}
	
	return clients, nil
}

// CloseAllConnections закрывает все соединения
func (repo *InMemoryRoomRepository) CloseAllConnections() error {
	repo.mu.RLock()
	rooms := make([]*domain.Room, 0, len(repo.rooms))
	for _, room := range repo.rooms {
		rooms = append(rooms, room)
	}
	repo.mu.RUnlock()
	
	// Закрываем все соединения
	for _, room := range rooms {
		clients := make([]*domain.Client, 0, len(room.Clients))
		for _, client := range room.Clients {
			clients = append(clients, client)
		}
		
		for _, client := range clients {
			if client.Conn != nil {
				_ = client.Conn.Close()
				log.Printf("connection_closed client_id=%s room_id=%s", client.ID, room.ID)
			}
		}
	}
	
	// Очищаем все комнаты
	repo.mu.Lock()
	repo.rooms = make(map[string]*domain.Room)
	repo.mu.Unlock()
	
	return nil
}
