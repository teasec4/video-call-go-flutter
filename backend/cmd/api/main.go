package main

import (
	"context"
	"log"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"callserver/internal/api"
	"callserver/internal/handler"
	"callserver/internal/repository"
	"callserver/internal/service"
)

func main() {
	// set up logger
	logger := slog.New(slog.NewJSONHandler(os.Stdout, nil))
	slog.SetDefault(logger)
	
	// initialize repository layer
	roomRepo := repository.NewInMemoryRoomRepository()
	
	// initialize service layer
	roomService := service.NewRoomService(roomRepo)
	
	// ws handler
	wh := handler.NewHandlerWS(roomService)
	
	// http handler
	rh := handler.NewRoomHandler(roomService)
	
	// router with middleware
	router := api.NewRouter(wh, rh)
	
	server := &http.Server{
		Addr:    "0.0.0.0:8081",
		Handler: router,
	}

	// Graceful shutdown
	go func() {
		sigChan := make(chan os.Signal, 1)
		signal.Notify(sigChan, os.Interrupt, syscall.SIGTERM)
		<-sigChan

		log.Println("Shutdown signal received, closing connections...")
		_ = roomRepo.CloseAllConnections()

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
