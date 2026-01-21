package main

import (
	"fmt"
	"log"
	"net/http"
	"github.com/gorilla/websocket"
)

var upgrader = websocket.Upgrader{
	CheckOrigin: func(r *http.Request) bool {
		return true
	},
}

func wsHandler(w http.ResponseWriter, r *http.Request){
	conn, err := upgrader.Upgrade(w, r, nil)
	if err != nil{
		log.Print("upgrade error:", err)
		return
	}
	defer conn.Close()
	
	log.Println("client connected")
	
	for{
		msgType, msg, err := conn.ReadMessage()
		if err != nil{
			log.Println("read error: ", err)
			return
		}
		log.Printf("recived: %s\n", msg)
		
		err = conn.WriteMessage(msgType, msg)
		if err != nil{
			log.Println("write error:", err)
			return
		}
	}
}

func main(){
	
	http.HandleFunc("/ws", wsHandler)
	
	fmt.Println("Server starting on :8080")
	log.Fatal(http.ListenAndServe(":8080", nil))
}