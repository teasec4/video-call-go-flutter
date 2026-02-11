package handler

import (
	"callserver/types"
	"callserver/ws/room"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"time"

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

// WebSocket timeout constants
const (
	readTimeout  = 60 * time.Second
	writeTimeout = 10 * time.Second
	pongWait     = 60 * time.Second
	pingInterval = (pongWait * 9) / 10
)

func (h *HandlerWebSocket) HandleConnection(w http.ResponseWriter, r *http.Request) {
	log.Println("WebSocket request from:", r.RemoteAddr, "Host:", r.Header.Get("Host"))

	conn, err := h.Upgrader.Upgrade(w, r, nil)
	if err != nil {
		log.Println("WebSocket upgrade error:", err)
		return
	}
	defer conn.Close()

	// Set connection timeouts
	conn.SetReadDeadline(time.Now().Add(readTimeout))
	conn.SetWriteDeadline(time.Now().Add(writeTimeout))
	conn.SetPongHandler(func(string) error {
		conn.SetReadDeadline(time.Now().Add(readTimeout))
		return nil
	})

	// Start ping ticker to keep connection alive
	ticker := time.NewTicker(pingInterval)
	defer ticker.Stop()

	// Goroutine for sending pings
	go func() {
		for range ticker.C {
			conn.SetWriteDeadline(time.Now().Add(writeTimeout))
			if err := conn.WriteMessage(websocket.PingMessage, nil); err != nil {
				return
			}
		}
	}()

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
		log.Println("Validation error:", errMsg)
		sendError(conn, errMsg)
		return
	}

	// Validate roomId format
	if err := validateRoomId(roomId); err != nil {
		errMsg := fmt.Sprintf("invalid roomId: %v", err)
		log.Println("Validation error:", errMsg)
		sendError(conn, errMsg)
		return
	}

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
	if err := conn.WriteMessage(websocket.TextMessage, mustJSON(joined)); err != nil {
		log.Println("Failed to send joined message:", err)
		conn.Close()
		return
	}
	
	for {
		// Update read deadline on each message
		conn.SetReadDeadline(time.Now().Add(readTimeout))

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
			// Update write deadline before sending
			conn.SetWriteDeadline(time.Now().Add(writeTimeout))
			// Echo back with from field
			response := types.Message{
				Type:    types.TypeChat,
				From:    clientId,
				Payload: msg.Payload,
			}
			respBytes := mustJSON(response)
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


