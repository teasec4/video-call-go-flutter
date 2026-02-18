package handler

import (
	"callserver/ws/room"
	"encoding/json"
	"fmt"
	"log"
	"net/http"

	"github.com/gorilla/websocket"
)

type WSMessageType string

const (
	typeJoinWs        WSMessageType = "join"
	typeJoinedWs      WSMessageType = "joined"
	typeError       WSMessageType = "error"
	typeChat        WSMessageType = "chat"
	typeUserLeft    WSMessageType = "user-left"
	typeOffer       WSMessageType = "offer"
	typeAnswer      WSMessageType = "answer"
	typeIceCandidate WSMessageType = "ice_candidate"
)

type WSPayload struct{
	From string `json:"from"`
	To string `json:"to"`
	Data map[string]string `json:"data"`
}

type WSMessage struct{
	Type WSMessageType `json:"type"`
	Payload WSPayload `json:"payload"`
}

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
	
	ctx := r.Context()

	// Read first message 
	_, firstMsg, err := conn.ReadMessage()
	if err != nil {
		log.Println("Failed to read first message:", err)
		return
	}

	var join WSMessage
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
	
	// attach client with server room manager 
	err = h.RoomManager.AttachClient(roomId, clientId, conn)
	if err != nil {
	    sendError(conn, err.Error())
	    return
	}
	
	switch join.Type{
		case typeJoinWs:
			joined := WSMessage{
				Type: typeJoinedWs,
				Payload: WSPayload{
					From: "server",
					To: join.Payload.From,
					Data: map[string]string{
						"type" : "joined",
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
	
	
	
	
	// get client and room 
	room, err := h.RoomManager.GetRoom(roomId)
	if err != nil{
		log.Printf("GetRoom error: %v", err)
		sendError(conn, "room not found")
		return
	}
	
	for {
		// Check if context is cancelled (server shutting down)
		select {
		case <-ctx.Done():
			log.Printf("client_disconnected (shutdown) client_id=%s room_id=%s", clientId, roomId)
			// h.RoomManager.LeaveRoom(roomId, client)
			return
		default:
		}

		_, msgBytes, err := conn.ReadMessage()
		if err != nil {
			log.Printf("client_disconnected client_id=%s room_id=%s error=%v", clientId, roomId, err)
			// Broadcast user-left message BEFORE removing the client from the room
			sendError(conn, "problem read message")
			break
		}

		var msg WSMessage
		if err := json.Unmarshal(msgBytes, &msg); err != nil {
			log.Printf("unmarshal_error client_id=%s error=%v", clientId, err)
			continue
		}

		switch msg.Type {
		case typeChat:
			fmt.Printf("📨 Received chat from %s: %s\n", clientId, string(msg.Payload.From))
			// Echo back with from field
			fmt.Printf("📤 Broadcasting to room %s: %s\n", roomId, string(msg.Payload.Data["msg"]))
			if room != nil {
				room.BroadcastToRoom(mustJSON(msg))
			}

		case typeOffer:
			fmt.Printf("📬 Received offer from %s in room %s\n", clientId, roomId)
			

		case typeAnswer:
			fmt.Printf("📬 Received answer from %s in room %s\n", clientId, roomId)
			

		case typeIceCandidate:
			fmt.Printf("🧊 Received ICE candidate from %s in room %s\n", clientId, roomId)
			

		default:
			log.Printf("unknown_message_type client_id=%s message_type=%s", clientId, msg.Type)
		}
	}
}

func sendError(conn *websocket.Conn, errMsg string) {
	msg2 := WSMessage{
		Type: typeError,
		Payload: WSPayload{
			From: "server",
			To: "user", // payload.from
			Data: map[string]string{
				"error" : errMsg,
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
