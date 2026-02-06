package handler

import (
	"callserver/config"
	"callserver/types"
	"callserver/ws/client"
	"callserver/ws/message"
	"callserver/ws/room"
	"context"
	"encoding/json"
	"log"
	"net/http"
	"sync"

	"github.com/gorilla/websocket"
)

type messageStore struct {
	mu       sync.RWMutex
	messages []*types.Message
}

func (ms *messageStore) SaveMessage(msg *types.Message) {
	ms.mu.Lock()
	defer ms.mu.Unlock()
	ms.messages = append(ms.messages, msg)
}

func (ms *messageStore) GetAllMessages() []*types.Message {
	ms.mu.RLock()
	defer ms.mu.RUnlock()
	result := make([]*types.Message, len(ms.messages))
	copy(result, ms.messages)
	return result
}

type HandlerWebSocket struct {
	Upgrader       websocket.Upgrader
	ClientManager  *client.ClientManager
	RoomManager    *room.RoomManager
	Broadcast      chan []byte
	messageStore   *messageStore
	msgBuilder     *message.MessageBuilder
	msgSender      *message.MessageSender
}

func NewHandlerFromConfig(cfg *config.Config, clientManager *client.ClientManager) *HandlerWebSocket {
	return &HandlerWebSocket{
		Upgrader:       cfg.Upgrader,
		ClientManager:  clientManager,
		RoomManager:    room.NewRoomManager(),
		Broadcast:      cfg.Broadcast,
		messageStore:   &messageStore{},
		msgBuilder:     message.NewMessageBuilder(log.Default()),
		msgSender:      message.NewMessageSender(log.Default()),
	}
}

func (h *HandlerWebSocket) HandleConnection(w http.ResponseWriter, r *http.Request) {
	log.Println("WebSocket request from:", r.RemoteAddr, "Host:", r.Header.Get("Host"))

	conn, err := h.Upgrader.Upgrade(w, r, nil)
	if err != nil {
		log.Println("WebSocket upgrade error:", err)
		return
	}
	defer conn.Close()

	newClient := client.NewClient(conn)
	h.ClientManager.Add(newClient)

	log.Println("Client connected:", newClient.Id, "\nTotal clients:", len(h.ClientManager.List()))

	h.ClientManager.SendClientTheirId(newClient)
	h.sendChatHistory(newClient)
	h.ClientManager.NotifyPeer(newClient, true)

	defer func() {
		h.ClientManager.Remove(newClient.Id)
		log.Println("Client disconnected:", newClient.Id, "\nTotal clients:", len(h.ClientManager.List()))
		h.ClientManager.NotifyPeer(newClient, false)
		// Удаляем клиента из комнаты при отключении
		h.RoomManager.LeaveRoom(newClient)
	}()

	for {
		_, msgBytes, err := conn.ReadMessage()
		if err != nil {
			break
		}

		var msg types.Message
		if err := json.Unmarshal(msgBytes, &msg); err != nil {
			log.Println("Failed to unmarshal message:", err)
			continue
		}

		msg.From = newClient.Id

		if err := msg.Validate(); err != nil {
			log.Println("Validation error:", err)
			continue
		}

		switch msg.Type {
		case config.MessageTypeCreateRoom:
			h.handleCreateRoom(newClient)

		case config.MessageTypeJoinRoom:
			h.handleJoinRoom(newClient, msg.Payload)

		case config.MessageTypeLeaveRoom:
			h.handleLeaveRoom(newClient)

		case config.MessageTypeChat:
			h.messageStore.SaveMessage(&msg)
			chatBytes := h.msgBuilder.BuildChatResponse(msg.From, msg.Payload)
			if chatBytes != nil {
				h.Broadcast <- chatBytes
			}

		case config.MessageTypeListPeers:
			h.ClientManager.SendPeerList(newClient)

		case config.MessageTypeOffer, config.MessageTypeAnswer, config.MessageTypeIceCandidate:
			if msg.To == "" {
				log.Println("ERROR: No 'to' field in", msg.Type)
				continue
			}

			peer := h.ClientManager.Get(msg.To)
			if peer == nil {
				log.Println("Peer not found:", msg.To)
				continue
			}

			respBytes := h.msgBuilder.BuildSignalingResponse(msg.Type, newClient.Id, msg.Payload)
			if err := h.msgSender.SendToClient(peer.Conn, respBytes); err != nil {
				log.Println("Failed to send message to peer:", err)
			} else {
				log.Println("Successfully sent", msg.Type, "to peer:", msg.To[:8])
			}
		}
	}
}

func (h *HandlerWebSocket) marshalChatMessage(from string, payload json.RawMessage) ([]byte, error) {
	return json.Marshal(map[string]interface{}{
		"type":    "chat",
		"from":    from,
		"payload": payload,
	})
}

func (h *HandlerWebSocket) sendChatHistory(client *client.Client) {
	for _, msg := range h.messageStore.GetAllMessages() {
		msgBytes, err := h.marshalChatMessage(msg.From, msg.Payload)
		if err != nil {
			log.Println("Failed to marshal history message:", err)
			continue
		}
		if err := client.Conn.WriteMessage(websocket.TextMessage, msgBytes); err != nil {
			log.Println("Failed to send history to client:", err)
			return
		}
	}
}

func (h *HandlerWebSocket) StartBroadcaster(ctx context.Context) {
	go func() {
		for {
			select {
			case <-ctx.Done():
				close(h.Broadcast)
				return
			case msg := <-h.Broadcast:
				for _, c := range h.ClientManager.List() {
					if err := c.Conn.WriteMessage(websocket.TextMessage, msg); err != nil {
						log.Println("Broadcast error:", err)
					}
				}
			}
		}
	}()
}

// handleCreateRoom создает новую комнату и отправляет UUID клиенту
func (h *HandlerWebSocket) handleCreateRoom(client *client.Client) {
	roomID := h.RoomManager.CreateRoom()
	respBytes := h.msgBuilder.BuildRoomCreatedResponse(roomID)
	
	if err := h.msgSender.SendToClient(client.Conn, respBytes); err != nil {
		log.Println("Failed to send room-created:", err)
	} else {
		log.Println("Room created:", roomID[:8])
	}
}

// handleJoinRoom присоединяет клиента к комнате
func (h *HandlerWebSocket) handleJoinRoom(client *client.Client, payload json.RawMessage) {
	var data map[string]string
	if err := json.Unmarshal(payload, &data); err != nil {
		log.Println("Failed to unmarshal join-room payload:", err)
		h.msgSender.SendToClient(client.Conn, h.msgBuilder.BuildErrorResponse(config.ErrInvalidPayload))
		return
	}

	roomID, ok := data["roomId"]
	if !ok {
		log.Println("No roomId in join-room payload")
		h.msgSender.SendToClient(client.Conn, h.msgBuilder.BuildErrorResponse(config.ErrInvalidPayload))
		return
	}

	if !h.RoomManager.RoomExists(roomID) {
		h.msgSender.SendToClient(client.Conn, h.msgBuilder.BuildErrorResponse(config.ErrRoomNotFound))
		return
	}

	success, count := h.RoomManager.JoinRoom(roomID, client)
	if !success {
		h.msgSender.SendToClient(client.Conn, h.msgBuilder.BuildErrorResponse(config.ErrRoomFull))
		return
	}

	// Отправляем подтверждение присоединения
	respBytes := h.msgBuilder.BuildRoomJoinedResponse(roomID, client.Id, count)
	h.msgSender.SendToClient(client.Conn, respBytes)

	// Уведомляем другого клиента в комнате о присоединении
	h.notifyRoomPeers(roomID, client.Id, config.MessageTypePeerJoined)

	log.Println("Client", client.Id[:8], "joined room", roomID[:8], "total in room:", count)
}

// handleLeaveRoom удаляет клиента из комнаты
func (h *HandlerWebSocket) handleLeaveRoom(client *client.Client) {
	if client.RoomId == "" {
		return
	}

	roomID := client.RoomId
	h.RoomManager.LeaveRoom(client)

	// Уведомляем оставшегося клиента
	h.notifyRoomPeers(roomID, client.Id, config.MessageTypePeerLeft)

	log.Println("Client", client.Id[:8], "left room", roomID[:8])
}

// notifyRoomPeers отправляет сообщение всем клиентам в комнате, кроме отправителя
func (h *HandlerWebSocket) notifyRoomPeers(roomID string, excludeClientID string, msgType string) {
	clients := h.RoomManager.GetRoomClients(roomID)
	notifyBytes := h.msgBuilder.BuildPeerNotificationResponse(msgType, excludeClientID)
	
	for _, c := range clients {
		if c.Id != excludeClientID {
			h.msgSender.SendToClient(c.Conn, notifyBytes)
		}
	}
}
