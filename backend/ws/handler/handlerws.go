package handler

import (
	"callserver/config"
	"callserver/types"
	"callserver/ws/client"
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
	Broadcast      chan []byte
	messageStore   *messageStore
}

func NewHandlerFromConfig(config *config.Config, clientManager *client.ClientManager) *HandlerWebSocket {
	return &HandlerWebSocket{
		Upgrader:       config.Upgrader,
		ClientManager:  clientManager,
		Broadcast:      config.Broadcast,
		messageStore:   &messageStore{},
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
		case "chat":
			h.messageStore.SaveMessage(&msg)
			chatBytes, err := h.marshalChatMessage(msg.From, msg.Payload)
			if err != nil {
				log.Println("Failed to marshal chat message:", err)
				continue
			}
			h.Broadcast <- chatBytes

		case "list-peers":
			h.ClientManager.SendPeerList(newClient)

		case "offer", "answer", "ice-candidate":
			if msg.To == "" {
				log.Println("ERROR: No 'to' field in", msg.Type)
				continue
			}

			peer := h.ClientManager.Get(msg.To)
			if peer == nil {
				log.Println("Peer not found:", msg.To)
				continue
			}

			response := map[string]interface{}{
				"type":    msg.Type,
				"from":    newClient.Id,
				"payload": msg.Payload,
			}
			respBytes, err := json.Marshal(response)
			if err != nil {
				log.Println("Failed to marshal response:", err)
				continue
			}

			err = peer.Conn.WriteMessage(websocket.TextMessage, respBytes)
			if err != nil {
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
