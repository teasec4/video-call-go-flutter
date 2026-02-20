package handler

import (
	"callserver/internal/domain"
	"encoding/json"
	"fmt"
	"log"
	"net/http"

	"github.com/gorilla/websocket"
)

type HandlerWebSocket struct {
	Upgrader    websocket.Upgrader
	RoomService domain.RoomService
}

func NewHandlerWS(roomService domain.RoomService) *HandlerWebSocket {
	return &HandlerWebSocket{
		Upgrader: websocket.Upgrader{
			CheckOrigin: func(r *http.Request) bool {
				// origin := r.Header.Get("Origin")
				// return origin == "https://myfrontend.com"
				return true
			},
		},
		RoomService: roomService,
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

	ctx := r.Context()

	// Read first message
	_, firstMsg, err := conn.ReadMessage()
	if err != nil {
		log.Println("Failed to read first message:", err)
		return
	}

	var join domain.Message
	if err := json.Unmarshal(firstMsg, &join); err != nil {
		log.Println("Failed to unmarshal message(first):", err)
		return
	}

	clientId := join.Payload.From
	roomId, ok := join.Payload.Data["roomId"]
	if !ok || roomId == "" {
		sendError(conn, "empty data")
		return
	}

	// attach client with service
	err = h.RoomService.AttachClientConnection(roomId, clientId, conn)
	if err != nil {
		sendError(conn, err.Error())
		return
	}

	switch join.Type {
	case domain.MessageTypeJoin:
		joined := domain.Message{
			Type: domain.MessageTypeJoined,
			Payload: domain.MessagePayload{
				From: "server",
				To:   join.Payload.From,
				Data: map[string]string{
					"type": "joined",
				},
			},
		}
		joinedBytes := mustJSON(joined)
		log.Printf("Sending joined message: %s", string(joinedBytes))

		if err := conn.WriteMessage(websocket.TextMessage, joinedBytes); err != nil {
			log.Printf("write_error client_id=%s error=%v", join.Payload.From, err)
			conn.Close()
			return
		}
	default:
		sendError(conn, "First message must be join")
		return
	}

	// get room
	room, err := h.RoomService.GetRoom(roomId)
	if err != nil {
		log.Printf("GetRoom error: %v", err)
		sendError(conn, "room not found")
		return
	}

	for {
		// Check if context is cancelled (server shutting down)
		select {
		case <-ctx.Done():
			log.Printf("client_disconnected (shutdown) client_id=%s room_id=%s", clientId, roomId)
			return
		default:
		}

		_, msgBytes, err := conn.ReadMessage()
		if err != nil {
			log.Printf("client_disconnected client_id=%s room_id=%s error=%v", clientId, roomId, err)
			sendError(conn, "problem read message")
			break
		}

		var msg domain.Message
		if err := json.Unmarshal(msgBytes, &msg); err != nil {
			log.Printf("unmarshal_error client_id=%s error=%v", clientId, err)
			continue
		}

		switch msg.Type {
		case domain.MessageTypeChat:
			fmt.Printf("📨 Received chat from %s: %s\n", clientId, string(msg.Payload.From))
			fmt.Printf("📤 Broadcasting to room %s: %s\n", roomId, string(msg.Payload.Data["msg"]))
			if room != nil {
				_ = h.RoomService.BroadcastToRoom(roomId, &msg)
			}

		case domain.MessageTypeOffer:
			fmt.Printf("📬 Received offer from %s in room %s\n", clientId, roomId)

		case domain.MessageTypeAnswer:
			fmt.Printf("📬 Received answer from %s in room %s\n", clientId, roomId)

		case domain.MessageTypeIceCandidate:
			fmt.Printf("🧊 Received ICE candidate from %s in room %s\n", clientId, roomId)

		default:
			log.Printf("unknown_message_type client_id=%s message_type=%s", clientId, msg.Type)
		}
	}
}

func sendError(conn *websocket.Conn, errMsg string) {
	msg2 := domain.Message{
		Type: domain.MessageTypeError,
		Payload: domain.MessagePayload{
			From: "server",
			To:   "user",
			Data: map[string]string{
				"error": errMsg,
			},
		},
	}
	if err := conn.WriteMessage(websocket.TextMessage, mustJSON(msg2)); err != nil {
		log.Println("Failed to send error message:", err)
		conn.Close()
	}
}

func mustJSON(v any) []byte {
	data, err := json.Marshal(v)
	if err != nil {
		panic(err)
	}
	return data
}
