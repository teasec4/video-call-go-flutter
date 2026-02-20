package api

import (
	"callserver/internal/handler"
	"net/http"

	"github.com/go-chi/chi/v5"
	"github.com/go-chi/cors"
)

func NewRouter(wsHandler *handler.HandlerWebSocket, httpHandler *handler.RoomHandler) http.Handler{
	r := chi.NewRouter()
	
	// middleware.
	r.Use(cors.Handler(cors.Options{
			AllowedOrigins:   []string{"*"},
			AllowedMethods:   []string{"GET", "POST", "PUT", "DELETE", "OPTIONS"},
			AllowedHeaders:   []string{"*"},
			AllowCredentials: false,
			MaxAge:           300,
		}))
	
	r.HandleFunc("/room", httpHandler.HandleRoom)
	r.HandleFunc("/ws", wsHandler.HandleConnection)
	return r
}