package handler

import (
	"callserver/types"
	"callserver/ws/room"
	"encoding/json"
	"log"
	"net/http"
	"github.com/gorilla/websocket"
)

type HandlerWebSocket struct {
	Upgrader    websocket.Upgrader
	RoomManager *room.RoomManager
}

func NewHandlerWS(rm *room.RoomManager) *HandlerWebSocket {
	return &HandlerWebSocket{
		Upgrader: websocket.Upgrader{
			CheckOrigin: func(r *http.Request) bool {
				return true
			},
		},
		RoomManager: rm,
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

	var join types.Message
	if err := json.Unmarshal(firstMsg, &join); err != nil {
		log.Println("Failed to unmarshal registration:", err)
		return
	}
	if join.Type != types.TypeJoin {
		sendError(conn, "First message must be join")
		return
	}

	if err := join.Validate(); err != nil {
		log.Println("Validation error:", err)
		sendError(conn, err.Error())
		return
	}

	clientId := join.ClientID
	roomId := join.RoomID

	client := &types.Client{
		Id:   clientId,
		Conn: conn,
	}
	h.RoomManager.JoinRoom(roomId, client)
	log.Println("✅ Client joined:", clientId, "Room:", roomId)
	
	// Send joined confirmation
	joined := types.Message{
		Type:   types.TypeJoined,
		RoomID: roomId,
	}
	conn.WriteMessage(websocket.TextMessage, mustJSON(joined))
	
	for {
		_, msgBytes, err := conn.ReadMessage()		
		if err != nil {
			log.Println("Client disconnected:", clientId)
			// Broadcast user-left message BEFORE removing the client from the room
			leftMsg := types.Message{
				Type: types.TypeUserLeft,
				From: clientId,
			}
			h.RoomManager.BroadcastToRoom(roomId, mustJSON(leftMsg))
			h.RoomManager.LeaveRoom(roomId, client)
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
		case types.TypeChat:
			// Echo back with from field
			response := types.Message{
				Type:    types.TypeChat,
				From:    clientId,
				Payload: msg.Payload,
			}
			h.RoomManager.BroadcastToRoom(roomId, mustJSON(response))
		}
	}
}

func sendError(conn *websocket.Conn, errMsg string) {
	msg := types.Message{
		Type:    types.TypeError,
		Payload: []byte(`"` + errMsg + `"`),
	}
	conn.WriteMessage(websocket.TextMessage, mustJSON(msg))
}

func mustJSON(v any) []byte {
	data, err := json.Marshal(v)
	if err != nil {
		panic(err) 
	}
	return data
}


