package handler

import (
	"callserver/config"
	"callserver/types"
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
	
	// Читаем первое сообщение с регистрацией
	_, firstMsg, err := conn.ReadMessage()
	if err != nil {
		log.Println("Failed to read first message:", err)
		return
	}

	var regMsg map[string]string
	if err := json.Unmarshal(firstMsg, &regMsg); err != nil {
		log.Println("Failed to unmarshal registration:", err)
		return
	}

	clientId := regMsg["clientId"]
	roomId := regMsg["roomId"]

	if clientId == "" || roomId == "" {
		log.Println("ERROR: Missing clientId or roomId")
		conn.WriteMessage(websocket.TextMessage, []byte(`{"type":"error","payload":"Missing clientId or roomId"}`))
		return
	}
	
	client := &types.Client{
		Id:   clientId,
		Conn: conn,
	}
	h.RoomManager.JoinRoom(roomId, client)
	log.Println("✅ Client joined:", clientId, "Room:", roomId)


	for {
		_, msgBytes, err := conn.ReadMessage()
		if err != nil {
			log.Println("Client disconnected:", clientId)
			h.RoomManager.LeaveRoom(roomId, client)
			h.RoomManager.BroadcastToRoom(roomId, []byte(`{"type":"user-left","from":"`+clientId+`"}`))
			break
		}

		var msg types.Message
		if err := json.Unmarshal(msgBytes, &msg); err != nil {
			log.Println("Failed to unmarshal message:", err)
			continue
		}

		msg.From = clientId

		if err := msg.Validate(); err != nil {
			log.Println("Validation error:", err)
			continue
		}

		switch msg.Type {
		case "chat":
		response := map[string]interface{}{
			"type":    "chat",
			"from":    clientId,
			"payload": msg.Payload,
		}
		respBytes, _ := json.Marshal(response)
		h.RoomManager.BroadcastToRoom(roomId, respBytes)


		case "offer", "answer", "ice-candidate":
	
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



