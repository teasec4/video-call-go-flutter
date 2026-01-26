package main

import (
	"callserver/config"
	"callserver/ws/client"
	"callserver/ws/handler"
	"context"
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
	cm := client.NewClientManager()
	h := handler.NewHandlerFromConfig(cfg, cm)

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	h.StartBroadcaster(ctx)

	http.HandleFunc("/ws", h.HandleConnection)

	server := &http.Server{
		Addr: "0.0.0.0:8081",
	}

	// Graceful shutdown
	go func() {
		sigChan := make(chan os.Signal, 1)
		signal.Notify(sigChan, os.Interrupt, syscall.SIGTERM)
		<-sigChan

		log.Println("Shutdown signal received, closing connections...")
		cancel()

		shutdownCtx, shutdownCancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer shutdownCancel()
		server.Shutdown(shutdownCtx)
	}()

	fmt.Println("Server starting on 0.0.0.0:8081")
	log.Fatal(server.ListenAndServe())
}
