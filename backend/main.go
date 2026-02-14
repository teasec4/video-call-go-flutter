package main

import (
	"context"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"callserver/middleware"
	"callserver/ws/handler"
	"callserver/ws/room"
)

func main() {
	// room manager
	rm := room.NewRoomManager()
	
	// ws handler
	h := handler.NewHandlerWS(rm)
	
	// http handler
	rh := handler.NewRoomHandler(rm)
	
	http.HandleFunc("/ws", h.HandleConnection)
	http.HandleFunc("/room", rh.HandleRoom)
	
	// deprecated 
	http.HandleFunc("/createroom", rh.CreateRoom)
	http.HandleFunc("/joinroom", rh.JoinRoom)

	// Apply CORS middleware
	corsHandler := middleware.CorsMiddleware(http.DefaultServeMux)

	server := &http.Server{
		Addr:    "0.0.0.0:8081",
		Handler: corsHandler,
	}

	// Graceful shutdown
	go func() {
		sigChan := make(chan os.Signal, 1)
		signal.Notify(sigChan, os.Interrupt, syscall.SIGTERM)
		<-sigChan

		log.Println("Shutdown signal received, closing connections...")
		rm.CloseAllConnection()

		log.Println("Shutting down HTTP server...")
		shutdownCtx, shutdownCancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer shutdownCancel()
		if err := server.Shutdown(shutdownCtx); err != nil {
			log.Printf("Server shutdown error: %v", err)
		}
		log.Println("Server shutdown complete")
	}()

	log.Printf("server_started addr=%s", server.Addr)
	log.Fatal(server.ListenAndServe())
}
