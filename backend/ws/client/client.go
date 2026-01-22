package client

import (
	"encoding/json"
	"log"
	"sync"

	"github.com/google/uuid"
	"github.com/gorilla/websocket"
)

type Client struct{
	Conn *websocket.Conn
	Id string
}

type ClientManager struct{
	clients map[string]*Client
	mu sync.RWMutex
}

func NewClientManager() *ClientManager{
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

func (m *ClientManager) NotifyPeer (newPeer *Client, isJoin bool){
	msgType := "peer-left"
	if(isJoin){
		msgType = "peer-joined"
	}
	
	notification := map[string]string{
		"type": msgType,
		"id":   newPeer.Id,
	}
	notifyBytes, _ := json.Marshal(notification)
	
	for _, client := range m.clients{
		err := client.Conn.WriteMessage(websocket.TextMessage, notifyBytes)
		if err != nil{
			log.Println("Failed to notify peer-joined:", err)
		}
	}
}

func (m *ClientManager) SendClientTheirId(client *Client){
	msg := map[string]string{"type": "client-id", "id": client.Id}
	msgBytes, _ := json.Marshal(msg)
	client.Conn.WriteMessage(websocket.TextMessage, msgBytes)
}

func (m *ClientManager) SendPeerList(client *Client){
	m.mu.RLock()
    defer m.mu.RUnlock()
    var peerIDs []string
    for _, client := range m.clients{
   		peerIDs = append(peerIDs, client.Id)
    }
   	response := map[string]interface{}{
		"type":  "peer-list",
		"peers": peerIDs,
	}
	responseBytes, _ := json.Marshal(response)
	client.Conn.WriteMessage(websocket.TextMessage, responseBytes)
}

func NewClient(conn *websocket.Conn) *Client{
	return &Client{
		Conn: conn,
		Id: uuid.New().String(),
	}
}