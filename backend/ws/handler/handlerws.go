package handler

import (
	"callserver/config"
	"callserver/types"
	"callserver/ws/client"
	"context"
	"encoding/json"
	"log"
	"net/http"

	"github.com/gorilla/websocket"
)

type HandlerWebSocket struct {
	Upgrader       websocket.Upgrader
	ClientManager  *client.ClientManager
	Broadcast      chan []byte
}

func NewHandlerFromConfig(config *config.Config, clientManager *client.ClientManager) *HandlerWebSocket {
	return &HandlerWebSocket{
		Upgrader:      config.Upgrader,
		ClientManager: clientManager,
		Broadcast:     config.Broadcast,
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

	// new client
	newClient := client.NewClient(conn)

	// add client to list of clients
	h.ClientManager.Add(newClient)

	log.Println("Client connected:", newClient.Id, "\nTotal clients:", len(h.ClientManager.List()))

	// send client back their id
	h.ClientManager.SendClientTheirId(newClient)

	// notify every peer, second is true if joined and false if left
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

		// Validate message
		if err := msg.Validate(); err != nil {
			log.Println("Validation error:", err)
			continue
		}

		switch msg.Type {
		case "chat":
			chatMsg := map[string]interface{}{
				"type":    "chat",
				"from":    newClient.Id,
				"payload": msg.Payload,
			}
			chatBytes, err := json.Marshal(chatMsg)
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

func (h *HandlerWebSocket) StartBroadcaster(ctx context.Context) {
	go func() {
		for {
			select {
			case <-ctx.Done():
				close(h.Broadcast)
				return
			case msg := <-h.Broadcast:
				for _, c := range h.ClientManager.List() {
					err := c.Conn.WriteMessage(websocket.TextMessage, msg)
					if err != nil {
						log.Println("Broadcast error:", err)
					}
				}
			}
		}
	}()
}
