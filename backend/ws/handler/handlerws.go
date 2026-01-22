package handler

import (
	"callserver/config"
	"callserver/types"
	"callserver/ws/client"
	"encoding/json"
	"log"
	"net/http"

	"github.com/gorilla/websocket"
)

type HandlerWebSocket struct{
	Upgrader websocket.Upgrader
	ClientManager *client.ClientManager
	Broadcast chan[]byte
}

func NewHandlerFromConfig(config *config.Config, clientManager *client.ClientManager) *HandlerWebSocket{
	return &HandlerWebSocket{
		Upgrader: config.Upgrader,
		ClientManager: clientManager,
		Broadcast: config.Broadcast,
	}
}

func (h *HandlerWebSocket) HandleConnection(w http.ResponseWriter, r *http.Request){
	log.Println("WebSocket request from:", r.RemoteAddr, "Host:", r.Header.Get("Host"))
	
	conn, err := h.Upgrader.Upgrade(w, r, nil)
	if err != nil {
		log.Println("WebSocket upgrade error:", err)
		return
	}
	defer conn.Close()
	
	// new client
	client := client.NewClient(conn)
	 
	// add client to list of client
	h.ClientManager.Add(client)
	
	log.Println("Client connected:", client.Id, "\nTotal clients:", len(h.ClientManager.List()))
	 
	// send client back their id
	h.ClientManager.SendClientTheirId(client)
	
	// notify every peer, second is true if joined and false if left
	h.ClientManager.NotifyPeer(client, true)
	
	defer func(){
		h.ClientManager.Remove(client.Id)
		log.Println("Client disconnected:", client.Id, "\nTotal clients:", len(h.ClientManager.List()))
		h.ClientManager.NotifyPeer(client, false)
	}()
	
	for {
		_, msgBytes, err := conn.ReadMessage()
		if err != nil{
			break
		}
		
		var msg types.Message
		if err := json.Unmarshal(msgBytes, &msg); err != nil {
			log.Println("Failed to unmarshal message:", err)
			continue
		}
		msg.From = client.Id
		
		switch msg.Type{
			case "chat":
		 		chatMsg := map[string]interface{}{
						"type":    "chat",
						"from":    client.Id,
						"payload": msg.Payload,
					}
				chatBytes, _ := json.Marshal(chatMsg)
				h.Broadcast <- chatBytes
			case "list-peers":
				h.ClientManager.SendPeerList(client)
			case "offer", "answer", "ice-candidate":
				if msg.To == "" {
					log.Println("ERROR: No 'to' field in", msg.Type)
					continue
				}
				
				peer := h.ClientManager.Get(msg.To)
				if peer == nil {
					log.Println("Peer not found:", msg.To)
					continue
				}
				
				response := map[string]interface{}{
					"type":    msg.Type,
					"from":    client.Id,
					"payload": msg.Payload,
				}
				respBytes, _ := json.Marshal(response)
				
				err := peer.Conn.WriteMessage(websocket.TextMessage, respBytes)
				if err != nil {
					log.Println("Failed to send message to peer:", err)
				} else {
					log.Println("Successfully sent", msg.Type, "to peer:", msg.To[:8])
				}
		}
	}
}

func (h *HandlerWebSocket) StartBroadcaster() {
    go func() {
        for msg := range h.Broadcast {
            for _, c := range h.ClientManager.List() {
                c.Conn.WriteMessage(websocket.TextMessage, msg)
            }
        }
    }()
}




