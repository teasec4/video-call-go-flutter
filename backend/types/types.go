package types

import (
	"encoding/json"
	"fmt"

	"github.com/gorilla/websocket"
)




type Client struct {
	Conn   *websocket.Conn
	Id     string
}

type Message struct {
	Type    string          `json:"type"`
	From    string          `json:"from"`
	To      string          `json:"to,omitempty"`
	Payload json.RawMessage `json:"payload"`
}

func (m *Message) Validate() error {
	if m.Type == "" {
		return fmt.Errorf("message type is required")
	}

	switch m.Type {
	case "chat":
		if len(m.Payload) == 0 {
			return fmt.Errorf("chat message requires payload")
		}
	case "offer", "answer", "ice-candidate":
		if m.To == "" {
			return fmt.Errorf("%s requires 'to' field", m.Type)
		}
		if len(m.Payload) == 0 {
			return fmt.Errorf("%s requires payload", m.Type)
		}
	case "create-room", "join-room", "leave-room", "list-peers":
		// no validation needed
	default:
		return fmt.Errorf("unknown message type: %s", m.Type)
	}

	return nil
}

type MessageType string

const(
	TypeJoin MessageType = "join"
	TypeJoined MessageType = "joined"
	TypeError  MessageType = "error"
	TypeChat   MessageType = "chat"
)

type BaseMessage struct{
	Type MessageType `json:"type"`
}

type JoinRoomMessage struct {
	Type     MessageType `json:"type"`
	ClientID string      `json:"clientId"`
	RoomID   string      `json:"roomId"`
}

type JoinedMessage struct {
	Type   MessageType `json:"type"`
	RoomID string      `json:"roomId"`
}

type ChatMessage struct {
	Type    MessageType      `json:"type"`
	From    string           `json:"from"`
	Payload json.RawMessage  `json:"payload"`
}

type ErrorMessage struct {
	Type    MessageType `json:"type"`
	Payload string      `json:"payload"`
}

func DecodeClientMessage(data []byte) (any, error) {
	var base BaseMessage
	if err := json.Unmarshal(data, &base); err != nil {
		return nil, err
	}

	switch base.Type {
	case TypeJoin:
		var msg JoinRoomMessage
		err := json.Unmarshal(data, &msg)
		return msg, err

	case TypeChat:
		var msg ChatMessage
		err := json.Unmarshal(data, &msg)
		return msg, err

	default:
		return nil, fmt.Errorf("unknown message type: %s", base.Type)
	}
}