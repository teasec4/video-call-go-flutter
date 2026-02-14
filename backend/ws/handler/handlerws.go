package handler

import (
	"callserver/types"
	"callserver/ws/room"
	"encoding/json"
	"fmt"
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

// No timeouts for WebSocket connections - allow long-lived connections

func (h *HandlerWebSocket) HandleConnection(w http.ResponseWriter, r *http.Request) {
	log.Println("WebSocket request from:", r.RemoteAddr, "Host:", r.Header.Get("Host"))

	conn, err := h.Upgrader.Upgrade(w, r, nil)
	if err != nil {
		log.Println("WebSocket upgrade error:", err)
		return
	}
	defer conn.Close()
	
	ctx := r.Context()

	// Don't set any timeouts - allow long-lived connections



	// Read first message (join registration)
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

	// Validate clientId format
	if err := validateClientId(clientId); err != nil {
		errMsg := fmt.Sprintf("invalid clientId: %v", err)
		log.Printf("validation_error client_id=%s error=%v", clientId, err)
		sendError(conn, errMsg)
		return
	}

	// Validate roomId format
	if err := validateRoomId(roomId); err != nil {
		errMsg := fmt.Sprintf("invalid roomId: %v", err)
		log.Printf("validation_error room_id=%s error=%v", roomId, err)
		sendError(conn, errMsg)
		return
	}

	client := &types.Client{
		Id:   clientId,
		Conn: conn,
	}
	h.RoomManager.JoinRoom(roomId, client)
	log.Printf("client_joined client_id=%s room_id=%s remote_addr=%s", clientId, roomId, r.RemoteAddr)

	// Send joined confirmation
	joined := types.Message{
		Type:   types.TypeJoined,
		RoomID: roomId,
	}
	joinedBytes := mustJSON(joined)
	log.Printf("📤 Sending joined message: %s", string(joinedBytes))
	
	if err := conn.WriteMessage(websocket.TextMessage, joinedBytes); err != nil {
		log.Printf("write_error client_id=%s error=%v", clientId, err)
		conn.Close()
		return
	}
	
	for {
		// Check if context is cancelled (server shutting down)
		select {
		case <-ctx.Done():
			log.Printf("client_disconnected (shutdown) client_id=%s room_id=%s", clientId, roomId)
			h.RoomManager.LeaveRoom(roomId, client)
			return
		default:
		}

		_, msgBytes, err := conn.ReadMessage()
		if err != nil {
			log.Printf("client_disconnected client_id=%s room_id=%s error=%v", clientId, roomId, err)
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
			log.Printf("unmarshal_error client_id=%s error=%v", clientId, err)
			continue
		}

		msg.From = clientId

		if err := msg.Validate(); err != nil {
			log.Printf("validation_error client_id=%s message_type=%s error=%v", clientId, msg.Type, err)
			continue
		}

		switch msg.Type {
		case types.TypeChat:
			fmt.Printf("📨 Received chat from %s: %s\n", clientId, string(msg.Payload))
			// Echo back with from field
			response := types.Message{
				Type:    types.TypeChat,
				From:    clientId,
				Payload: msg.Payload,
			}
			respBytes := mustJSON(response)
			fmt.Printf("📤 Broadcasting to room %s: %s\n", roomId, string(respBytes))
			h.RoomManager.BroadcastToRoom(roomId, respBytes)
		}
	}
}

func sendError(conn *websocket.Conn, errMsg string) {
	msg := types.Message{
		Type:    types.TypeError,
		Payload: []byte(`"` + errMsg + `"`),
	}
	if err := conn.WriteMessage(websocket.TextMessage, mustJSON(msg)); err != nil {
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


