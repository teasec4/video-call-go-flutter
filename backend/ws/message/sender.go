package message

import (
	"github.com/gorilla/websocket"
)

// MessageSender отправляет сообщения через WebSocket
type MessageSender struct {
	logger Logger
}

func NewMessageSender(logger Logger) *MessageSender {
	return &MessageSender{
		logger: logger,
	}
}

// SendToClient отправляет сообщение конкретному клиенту
func (ms *MessageSender) SendToClient(conn *websocket.Conn, msgBytes []byte) error {
	if msgBytes == nil {
		return nil
	}
	return conn.WriteMessage(websocket.TextMessage, msgBytes)
}

// SendToClients отправляет сообщение нескольким клиентам
func (ms *MessageSender) SendToClients(clients map[string]*websocket.Conn, msgBytes []byte) {
	if msgBytes == nil {
		return
	}
	for _, conn := range clients {
		if err := conn.WriteMessage(websocket.TextMessage, msgBytes); err != nil {
			ms.logger.Println("Failed to send message:", err)
		}
	}
}

// SendToClientsExcept отправляет сообщение всем, кроме одного
func (ms *MessageSender) SendToClientsExcept(clients map[string]*websocket.Conn, excludeID string, msgBytes []byte) {
	if msgBytes == nil {
		return
	}
	for id, conn := range clients {
		if id != excludeID {
			if err := conn.WriteMessage(websocket.TextMessage, msgBytes); err != nil {
				ms.logger.Println("Failed to send message:", err)
			}
		}
	}
}
