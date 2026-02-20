package api

import (
	"callserver/ws/handler"
	"net/http"

	"github.com/go-chi/chi/v5"
)

func NewRouter(wsHandler *handler.HandlerWebSocket, httpHandler *handler.RoomHandler) http.Handler{
	r := chi.NewRouter()
	
	// middleware 
	// r.Use()
	
	r.HandleFunc("/", httpHandler.HandleRoom)
	
	return r
}