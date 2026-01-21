package main

import (
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"sync"

	"github.com/google/uuid"
	"github.com/gorilla/websocket"
)

type Client struct {
	conn   *websocket.Conn
	id     string
}

type Message struct {
	Type    string          `json:"type"`
	From    string          `json:"from"`
	To      string          `json:"to,omitempty"`
	Payload json.RawMessage `json:"payload"`
}

var (
	clients   = make(map[string]*Client)
	clientsMu sync.RWMutex
	broadcast = make(chan []byte, 100)
)

var upgrader = websocket.Upgrader{
	CheckOrigin: func(r *http.Request) bool {
		return true
	},
}


func main() {
	go broadcastMessages()

	http.HandleFunc("/ws", handleWebSocket)

	fmt.Println("Server starting on 0.0.0.0:8081")
	log.Fatal(http.ListenAndServe("0.0.0.0:8081", nil))
}

func handleWebSocket(w http.ResponseWriter, r *http.Request) {
	log.Println("WebSocket request from:", r.RemoteAddr, "Host:", r.Header.Get("Host"))
	
	conn, err := upgrader.Upgrade(w, r, nil)
	if err != nil {
		log.Println("WebSocket upgrade error:", err)
		return
	}
	defer conn.Close()

	clientID := uuid.New().String()
	client := &Client{
		conn: conn,
		id:   clientID,
	}

	clientsMu.Lock()
	clients[clientID] = client
	clientsMu.Unlock()

	log.Println("Client connected:", clientID, "\nTotal clients:", len(clients))

	// Send client their ID
	idMsg := map[string]string{"type": "client-id", "id": clientID}
	idBytes, _ := json.Marshal(idMsg)
	conn.WriteMessage(websocket.TextMessage, idBytes)

	// Notify all other clients about new peer
	notifyPeerJoined(clientID)

	defer func() {
		clientsMu.Lock()
		delete(clients, clientID)
		clientsMu.Unlock()
		log.Println("Client disconnected:", clientID, "Total clients:", len(clients))

		// Notify all other clients about peer leaving
		notifyPeerLeft(clientID)
	}()

	for {
		_, msgBytes, err := conn.ReadMessage()
		if err != nil {
			break
		}

		log.Println("DEBUG: Received raw message, length:", len(msgBytes), "first 100 chars:", string(msgBytes[:min(100, len(msgBytes))]))

		var msg Message
		if err := json.Unmarshal(msgBytes, &msg); err != nil {
			log.Println("Failed to unmarshal message:", err)
			continue
		}
		log.Println("DEBUG: Unmarshaled type:", msg.Type)

		msg.From = clientID

		// Route based on message type
		switch msg.Type {
		case "chat":
			// Broadcast chat messages to all with sender info
			chatMsg := map[string]interface{}{
				"type":    "chat",
				"from":    clientID,
				"payload": msg.Payload,
			}
			chatBytes, _ := json.Marshal(chatMsg)
			broadcast <- chatBytes
		case "offer", "answer", "ice-candidate":
			// Send to specific peer
			log.Println("DEBUG: Received", msg.Type, "from", clientID[:8], "to field:", msg.To)
			if msg.To != "" {
				log.Println("Routing", msg.Type, "from", clientID[:8], "to", msg.To[:8])
				// Create message with from field for peer
				peerMsg := map[string]interface{}{
					"type":    msg.Type,
					"from":    clientID,
					"payload": msg.Payload,
				}
				peerMsgBytes, _ := json.Marshal(peerMsg)
				sendToPeer(msg.To, peerMsgBytes)
			} else {
				log.Println("ERROR: No 'to' field in", msg.Type)
			}
		case "list-peers":
			// Send list of connected peers
			sendPeerList(client)
		}
	}
}

func sendToPeer(peerID string, msgBytes []byte) {
	clientsMu.RLock()
	peer, exists := clients[peerID]
	totalClients := len(clients)
	clientsMu.RUnlock()

	if exists {
		var msg Message
		json.Unmarshal(msgBytes, &msg)
		
		if msg.Type == "offer" || msg.Type == "answer" {
			log.Println("DEBUG: Sending", msg.Type, "- payload length:", len(msg.Payload), "bytes")
			log.Println("DEBUG: Full response:", string(msgBytes[:min(200, len(msgBytes))]))
		}
		
		log.Println("Sending", msg.Type, "message to peer:", peerID[:8])
		err := peer.conn.WriteMessage(websocket.TextMessage, msgBytes)
		if err != nil {
			log.Println("Failed to send message to peer:", peerID, err)
		} else {
			log.Println("Successfully sent", msg.Type, "to peer:", peerID[:8])
		}
	} else {
		log.Println("Peer not found:", peerID, "Total clients:", totalClients)
	}
}

func sendPeerList(client *Client) {
	clientsMu.RLock()
	defer clientsMu.RUnlock()

	var peerIDs []string
	for id := range clients {
		if id != client.id {
			peerIDs = append(peerIDs, id)
		}
	}

	response := map[string]interface{}{
		"type":  "peer-list",
		"peers": peerIDs,
	}
	responseBytes, _ := json.Marshal(response)
	client.conn.WriteMessage(websocket.TextMessage, responseBytes)
}

func notifyPeerJoined(newPeerID string) {
	clientsMu.RLock()
	defer clientsMu.RUnlock()

	notification := map[string]string{
		"type": "peer-joined",
		"id":   newPeerID,
	}
	notifyBytes, _ := json.Marshal(notification)

	for id, client := range clients {
		if id != newPeerID {
			err := client.conn.WriteMessage(websocket.TextMessage, notifyBytes)
			if err != nil {
				log.Println("Failed to notify peer-joined:", err)
			}
		}
	}
}

func notifyPeerLeft(leftPeerID string) {
	clientsMu.RLock()
	defer clientsMu.RUnlock()

	notification := map[string]string{
		"type": "peer-left",
		"id":   leftPeerID,
	}
	notifyBytes, _ := json.Marshal(notification)

	for _, client := range clients {
		err := client.conn.WriteMessage(websocket.TextMessage, notifyBytes)
		if err != nil {
			log.Println("Failed to notify peer-left:", err)
		}
	}
}

func broadcastMessages() {
	for msg := range broadcast {
		clientsMu.RLock()
		for _, client := range clients {
			err := client.conn.WriteMessage(websocket.TextMessage, msg)
			if err != nil {
				log.Println("Failed to broadcast:", err)
			}
		}
		clientsMu.RUnlock()
	}
}
