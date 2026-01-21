package main

import (
	"fmt"
	"log"
	"net/http"

	"github.com/gorilla/websocket"
)

type CLient struct{
	conn *websocket.Conn
	id string
}

var clients = make(map[*CLient]bool)
var broadcast = make(chan []byte)

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
	conn, err := upgrader.Upgrade(w, r, nil)
	if err != nil {
		log.Println("WebSocket upgrade error:", err)
		return
	}
	defer conn.Close()

	client := &CLient{
		conn: conn,
		id: r.RemoteAddr,
	}
	clients[client] = true
	log.Println("Client connected. Total clients:", len(clients))

	defer func() {
		delete(clients, client)
		log.Println("client disconnected:", client.id)
	}()
	
	for {
		var msg []byte
		_, msg, err := conn.ReadMessage()
		if err != nil {
			delete(clients, client)
			log.Println("Client disconnected. Total clients:", len(clients))
			break
		}
		broadcast <- msg
	}
}

func broadcastMessages() {
	for msg := range broadcast {
		for client := range clients {
			err := client.conn.WriteMessage(websocket.TextMessage, msg)
			if err != nil {
				delete(clients, client)
				client.conn.Close()
			}
		}
	}
}
