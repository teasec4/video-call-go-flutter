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

	var join types.JoinRoomMessage
	if err := json.Unmarshal(firstMsg, &join); err != nil {
		log.Println("Failed to unmarshal registration:", err)
		return
	}
	if join.Type != types.TypeJoin {
		conn.WriteMessage(
			websocket.TextMessage,
			mustJSON(types.ErrorMessage{
				Type:    types.TypeError,
				Payload: "First message must be join",
			}),
		)
		return
	}

	clientId := join.ClientID
	roomId := join.RoomID

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
	
	// Send joined confirmation
	joined := types.JoinedMessage{
		Type: types.TypeJoined,
		RoomID: roomId,
	}
	conn.WriteMessage(websocket.TextMessage, mustJSON(joined))
	
	for {
		_, msgBytes, err := conn.ReadMessage()		
		if err != nil {
			log.Println("Client disconnected:", clientId)
			// Broadcast user-left message BEFORE removing the client from the room
			h.RoomManager.BroadcastToRoom(roomId, []byte(`{"type":"user-left","from":"`+clientId+`"}`))
			h.RoomManager.LeaveRoom(roomId, client)
			break
		}
		
		decodedMessage, _ := types.DecodeClientMessage(msgBytes)
		log.Println(decodedMessage)

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
			// for future WebRTC 
		}
	}
}

func mustJSON(v any) []byte {
	data, err := json.Marshal(v)
	if err != nil {
		panic(err) 
	}
	return data
}


