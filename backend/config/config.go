package config

import (
	"net/http"

	"github.com/gorilla/websocket"
)

type Config struct{
	Upgrader websocket.Upgrader
	Broadcast chan[]byte
}

func ConfigInit() *Config{
	var upgrader = websocket.Upgrader{
		CheckOrigin: func(r *http.Request) bool {
			return true
		},
	}
	
	return &Config{
		Upgrader: upgrader,
		Broadcast: make(chan []byte, 100),
	}
}