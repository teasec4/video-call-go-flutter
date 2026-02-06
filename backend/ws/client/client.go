package client

import (
	"encoding/json"
	"log"
	"sync"

	"github.com/google/uuid"
	"github.com/gorilla/websocket"
)

type Client struct {
	Conn   *websocket.Conn
	Id     string
	RoomId string
}

type ClientManager struct {
	clients map[string]*Client
	mu      sync.RWMutex
}

func NewClientManager() *ClientManager {
	return &ClientManager{
		clients: make(map[string]*Client),
	}
}

func (m *ClientManager) Add(client *Client) {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.clients[client.Id] = client
}

func (m *ClientManager) Remove(clientID string) {
	m.mu.Lock()
	defer m.mu.Unlock()
	delete(m.clients, clientID)
}

func (m *ClientManager) Get(clientID string) *Client {
	m.mu.RLock()
	defer m.mu.RUnlock()
	return m.clients[clientID]
}

func (m *ClientManager) List() []*Client {
	m.mu.RLock()
	defer m.mu.RUnlock()
	var result []*Client
	for _, client := range m.clients {
		result = append(result, client)
	}
	return result
}

func (m *ClientManager) NotifyPeer(newPeer *Client, isJoin bool) {
	msgType := "peer-left"
	if isJoin {
		msgType = "peer-joined"
	}

	notification := map[string]interface{}{
		"type": msgType,
		"payload": map[string]string{"id": newPeer.Id},
	}
	notifyBytes, err := json.Marshal(notification)
	if err != nil {
		log.Println("Failed to marshal notification:", err)
		return
	}

	for _, c := range m.clients {
		err := c.Conn.WriteMessage(websocket.TextMessage, notifyBytes)
		if err != nil {
			log.Println("Failed to notify peer:", err)
		}
	}
}

func (m *ClientManager) SendClientTheirId(client *Client) {
	msg := map[string]interface{}{
		"type":    "client-id",
		"payload": map[string]string{"id": client.Id},
	}
	msgBytes, err := json.Marshal(msg)
	if err != nil {
		log.Println("Failed to marshal client-id:", err)
		return
	}
	err = client.Conn.WriteMessage(websocket.TextMessage, msgBytes)
	if err != nil {
		log.Println("Failed to send client-id:", err)
	}
}

func (m *ClientManager) SendPeerList(client *Client) {
	m.mu.RLock()
	defer m.mu.RUnlock()
	var peerIDs []string
	for _, c := range m.clients {
		peerIDs = append(peerIDs, c.Id)
	}
	response := map[string]interface{}{
		"type":  "peer-list",
		"peers": peerIDs,
	}
	responseBytes, err := json.Marshal(response)
	if err != nil {
		log.Println("Failed to marshal peer-list:", err)
		return
	}
	err = client.Conn.WriteMessage(websocket.TextMessage, responseBytes)
	if err != nil {
		log.Println("Failed to send peer-list:", err)
	}
}

func NewClient(conn *websocket.Conn) *Client {
	return &Client{
		Conn: conn,
		Id:   uuid.New().String(),
	}
}
