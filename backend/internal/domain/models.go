package domain

import "github.com/gorilla/websocket"

// Client представляет подключённого клиента
type Client struct {
	ID   string
	Conn *websocket.Conn
}

// Room представляет комнату для видеоконференции
type Room struct {
	ID      string
	Clients map[string]*Client
}

// Message сообщение в комнате
type Message struct {
	Type    MessageType       `json:"type"`
	Payload MessagePayload    `json:"payload"`
}

type MessageType string

const (
	MessageTypeJoin         MessageType = "join"
	MessageTypeJoined       MessageType = "joined"
	MessageTypeError        MessageType = "error"
	MessageTypeChat         MessageType = "chat"
	MessageTypeUserLeft     MessageType = "user-left"
	MessageTypeOffer        MessageType = "offer"
	MessageTypeAnswer       MessageType = "answer"
	MessageTypeIceCandidate MessageType = "ice_candidate"
)

// MessagePayload структура payload сообщения
type MessagePayload struct {
	From string            `json:"from"`
	To   string            `json:"to"`
	Data map[string]string `json:"data"`
}
