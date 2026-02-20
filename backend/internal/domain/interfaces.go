package domain

import "github.com/gorilla/websocket"

// RoomRepository интерфейс для работы с комнатами
type RoomRepository interface {
	// CreateRoom создаёт новую комнату
	CreateRoom(roomID string) (*Room, error)
	
	// GetRoom получает комнату по ID
	GetRoom(roomID string) (*Room, error)
	
	// DeleteRoom удаляет комнату
	DeleteRoom(roomID string) error
	
	// AddClientToRoom добавляет клиента в комнату
	AddClientToRoom(roomID, clientID string) error
	
	// AttachConnectionToClient присоединяет WebSocket соединение к клиенту
	AttachConnectionToClient(roomID, clientID string, conn *websocket.Conn) error
	
	// RemoveClientFromRoom удаляет клиента из комнаты
	RemoveClientFromRoom(roomID, clientID string) error
	
	// GetClientFromRoom получает клиента из комнаты
	GetClientFromRoom(roomID, clientID string) (*Client, error)
	
	// GetAllClientsInRoom получает всех клиентов в комнате
	GetAllClientsInRoom(roomID string) ([]*Client, error)
	
	// CloseAllConnections закрывает все соединения
	CloseAllConnections() error
}

// RoomService интерфейс для бизнес-логики работы с комнатами
type RoomService interface {
	// CreateAndJoinRoom создаёт комнату и добавляет клиента
	CreateAndJoinRoom(clientID string) (string, error)
	
	// JoinRoom добавляет клиента в существующую комнату
	JoinRoom(roomID, clientID string) error
	
	// LeaveRoom удаляет клиента из комнаты
	LeaveRoom(roomID, clientID string) error
	
	// AttachClientConnection присоединяет WebSocket соединение
	AttachClientConnection(roomID, clientID string, conn *websocket.Conn) error
	
	// BroadcastToRoom отправляет сообщение всем клиентам в комнате
	BroadcastToRoom(roomID string, msg *Message) error
	
	// GetRoom получает информацию о комнате
	GetRoom(roomID string) (*Room, error)
}
