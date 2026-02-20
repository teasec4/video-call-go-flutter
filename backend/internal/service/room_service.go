package service

import (
	"callserver/internal/domain"
	"encoding/json"
	"log"

	"github.com/google/uuid"
	"github.com/gorilla/websocket"
)

// RoomServiceImpl реализация Domain Service для комнат
type RoomServiceImpl struct {
	roomRepo domain.RoomRepository
}

// NewRoomService создаёт новый RoomService
func NewRoomService(roomRepo domain.RoomRepository) domain.RoomService {
	return &RoomServiceImpl{
		roomRepo: roomRepo,
	}
}

// CreateAndJoinRoom создаёт новую комнату и добавляет клиента
func (rs *RoomServiceImpl) CreateAndJoinRoom(clientID string) (string, error) {
	// Генерируем уникальный ID для комнаты
	roomID := uuid.New().String()
	
	// Создаём комнату
	_, err := rs.roomRepo.CreateRoom(roomID)
	if err != nil {
		log.Printf("failed to create room: %v", err)
		return "", err
	}
	
	// Добавляем клиента в комнату
	err = rs.roomRepo.AddClientToRoom(roomID, clientID)
	if err != nil {
		log.Printf("failed to add client to room: %v", err)
		_ = rs.roomRepo.DeleteRoom(roomID)
		return "", err
	}
	
	log.Printf("room_created room_id=%s client_id=%s", roomID, clientID)
	return roomID, nil
}

// JoinRoom добавляет клиента в существующую комнату
func (rs *RoomServiceImpl) JoinRoom(roomID, clientID string) error {
	// Проверяем, что комната существует
	_, err := rs.roomRepo.GetRoom(roomID)
	if err != nil {
		log.Printf("room not found: %v", err)
		return domain.ErrRoomNotFound
	}
	
	// Добавляем клиента в комнату
	err = rs.roomRepo.AddClientToRoom(roomID, clientID)
	if err != nil {
		log.Printf("failed to add client to room: %v", err)
		return err
	}
	
	log.Printf("client_joined room_id=%s client_id=%s", roomID, clientID)
	return nil
}

// LeaveRoom удаляет клиента из комнаты
func (rs *RoomServiceImpl) LeaveRoom(roomID, clientID string) error {
	// Удаляем клиента
	err := rs.roomRepo.RemoveClientFromRoom(roomID, clientID)
	if err != nil {
		log.Printf("failed to remove client from room: %v", err)
		return err
	}
	
	// Проверяем, осталась ли комната пустой
	clients, err := rs.roomRepo.GetAllClientsInRoom(roomID)
	if err != nil {
		log.Printf("failed to get clients from room: %v", err)
		return err
	}
	
	// Удаляем комнату, если она пустая
	if len(clients) == 0 {
		err = rs.roomRepo.DeleteRoom(roomID)
		if err != nil {
			log.Printf("failed to delete room: %v", err)
			return err
		}
		log.Printf("room_deleted (empty) room_id=%s", roomID)
	}
	
	log.Printf("client_left room_id=%s client_id=%s", roomID, clientID)
	return nil
}

// AttachClientConnection присоединяет WebSocket соединение к клиенту
func (rs *RoomServiceImpl) AttachClientConnection(roomID, clientID string, conn *websocket.Conn) error {
	err := rs.roomRepo.AttachConnectionToClient(roomID, clientID, conn)
	if err != nil {
		log.Printf("failed to attach connection to client: %v", err)
		return domain.ErrWebSocketConnection
	}
	return nil
}

// BroadcastToRoom отправляет сообщение всем клиентам в комнате
func (rs *RoomServiceImpl) BroadcastToRoom(roomID string, msg *domain.Message) error {
	// Получаем всех клиентов в комнате
	clients, err := rs.roomRepo.GetAllClientsInRoom(roomID)
	if err != nil {
		log.Printf("failed to get clients from room: %v", err)
		return err
	}
	
	// Маршализуем сообщение в JSON
	msgBytes, err := json.Marshal(msg)
	if err != nil {
		log.Printf("failed to marshal message: %v", err)
		return domain.ErrInvalidMessage
	}
	
	// Отправляем сообщение каждому клиенту
	for _, client := range clients {
		if client.Conn == nil {
			continue
		}
		if err := client.Conn.WriteMessage(websocket.TextMessage, msgBytes); err != nil {
			log.Printf("failed to send message to client %s: %v", client.ID, err)
			// Закрываем соединение при ошибке отправки
			_ = client.Conn.Close()
		}
	}
	
	return nil
}

// GetRoom получает информацию о комнате
func (rs *RoomServiceImpl) GetRoom(roomID string) (*domain.Room, error) {
	room, err := rs.roomRepo.GetRoom(roomID)
	if err != nil {
		log.Printf("room not found: %v", err)
		return nil, domain.ErrRoomNotFound
	}
	return room, nil
}
