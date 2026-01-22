package main

import (
	"callserver/config"
	"callserver/ws/client"
	"callserver/ws/handler"
	"fmt"
	"log"
	"net/http"

)


func main() {
	cfg := config.ConfigInit()
	cm := client.NewClientManager()
	h := handler.NewHandlerFromConfig(cfg, cm)
	h.StartBroadcaster()

	http.HandleFunc("/ws", h.HandleConnection)

	fmt.Println("Server starting on 0.0.0.0:8081")
	log.Fatal(http.ListenAndServe("0.0.0.0:8081", nil))
}

