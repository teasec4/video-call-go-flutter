package types

import (
	"encoding/json"
	"fmt"

	"github.com/gorilla/websocket"
)

type Client struct {
	Conn *websocket.Conn
	Id   string
}

// Message type for EVERYTHING throw WS
type MessageType string

const (
	TypeJoin        MessageType = "join"
	TypeJoined      MessageType = "joined"
	TypeError       MessageType = "error"
	TypeChat        MessageType = "chat"
	TypeUserLeft    MessageType = "user-left"
	TypeOffer       MessageType = "offer"
	TypeAnswer      MessageType = "answer"
	TypeIceCandidate MessageType = "ice_candidate"
)

// Единая структура сообщения для всех типов
type Message struct {
	Type    MessageType     `json:"type"`
	From    string          `json:"from,omitempty"`
	To      string          `json:"to,omitempty"`
	ClientID string         `json:"clientId,omitempty"` // Для join сообщений
	RoomID   string         `json:"roomId,omitempty"`    // Для join/joined сообщений
	Payload json.RawMessage `json:"payload,omitempty"`
}

func (m *Message) Validate() error {
	if m.Type == "" {
		return fmt.Errorf("message type is required")
	}

	switch m.Type {
	case TypeJoin:
		if m.ClientID == "" || m.RoomID == "" {
			return fmt.Errorf("join requires clientId and roomId")
		}
	case TypeChat:
		if len(m.Payload) == 0 {
			return fmt.Errorf("chat message requires payload")
		}
	case TypeOffer, TypeAnswer:
		if len(m.Payload) == 0 {
			return fmt.Errorf("%s requires payload (SDP)", m.Type)
		}
	case TypeIceCandidate:
		if len(m.Payload) == 0 {
			return fmt.Errorf("ice_candidate requires payload")
		}
	case TypeJoined, TypeError, TypeUserLeft:
		// No additional validation needed
	default:
		return fmt.Errorf("unknown message type: %s", m.Type)
	}

	return nil
}