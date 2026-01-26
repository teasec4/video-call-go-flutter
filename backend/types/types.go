package types

import (
	"encoding/json"
	"fmt"
)

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
	case "list-peers":
		// no validation needed
	default:
		return fmt.Errorf("unknown message type: %s", m.Type)
	}

	return nil
}
