package main

import (
	"callserver/config"
	"context"

	"callserver/ws/handler"
	"callserver/ws/room"
	"fmt"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"
)

func main() {
	cfg := config.ConfigInit()
	
	// client manager
	rm := room.NewRoomManager()
	
	// ws handler
	h := handler.NewHandlerWS(cfg, rm)
	
	// http handler
	rh := handler.NewRoomHandler(rm)
	


	http.HandleFunc("/ws", h.HandleConnection)
	http.HandleFunc("/createroom", rh.CreateRoom)
	http.HandleFunc("/joinroom", rh.JoinRoom)

	server := &http.Server{
		Addr: "0.0.0.0:8081",
	}

	// Graceful shutdown
	go func() {
		sigChan := make(chan os.Signal, 1)
		signal.Notify(sigChan, os.Interrupt, syscall.SIGTERM)
		<-sigChan

		log.Println("Shutdown signal received, closing connections...")
		rm.CloseAllConnection()

		shutdownCtx, shutdownCancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer shutdownCancel()
		server.Shutdown(shutdownCtx)
	}()

	fmt.Println("Server starting on 0.0.0.0:8081")
	log.Fatal(server.ListenAndServe())
}
