package handler

import (
	"callserver/config"
	"callserver/types"
	"callserver/ws/message"
	"callserver/ws/room"
	"context"
	"encoding/json"
	"log"
	"net/http"
	"github.com/gorilla/websocket"
)

type HandlerWebSocket struct {
	Upgrader       websocket.Upgrader
	RoomManager    *room.RoomManager
	Broadcast      chan []byte
}

func NewHandlerWS(cfg *config.Config, rm *room.RoomManager) *HandlerWebSocket {
	return &HandlerWebSocket{
		Upgrader:       cfg.Upgrader,
		RoomManager:    rm,
		Broadcast:      cfg.Broadcast,
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

		//msg.From = clientId

		if err := msg.Validate(); err != nil {
			log.Println("Validation error:", err)
			continue
		}

		switch msg.Type {
		case "chat":
			chatBytes := h.msgBuilder.BuildChatResponse(msg.From, msg.Payload)
			if chatBytes != nil {
				//h.RoomManager.BroadcastToRoom(roomId, chatBytes)
			}

		case "offer", "answer", "ice-candidate":
			if msg.To == "" {
				log.Println("ERROR: No 'to' field in", msg.Type)
				continue
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
				// Broadcast to all rooms
				for _, room := range h.RoomManager.Rooms {
					h.RoomManager.BroadcastToRoom(room.ID, msg)
				}
			}
		}
	}()
}



