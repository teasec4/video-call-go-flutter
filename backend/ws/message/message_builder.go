package message

import (
	"encoding/json"
)

// Response представляет стандартный ответ сервера
type Response struct {
	Type    string                 `json:"type"`
	Payload map[string]interface{} `json:"payload"`
}

// MessageBuilder помогает создавать JSON сообщения без дублирования
type MessageBuilder struct {
	logger Logger
}

// Logger интерфейс для логирования
type Logger interface {
	Println(v ...interface{})
}

func NewMessageBuilder(logger Logger) *MessageBuilder {
	return &MessageBuilder{
		logger: logger,
	}
}

// BuildResponse создает стандартный response с обработкой ошибок
func (mb *MessageBuilder) BuildResponse(msgType string, payload map[string]interface{}) []byte {
	response := Response{
		Type:    msgType,
		Payload: payload,
	}

	bytes, err := json.Marshal(response)
	if err != nil {
		mb.logger.Println("Failed to marshal response:", msgType, "error:", err)
		return nil
	}

	return bytes
}

// BuildErrorResponse создает error response
func (mb *MessageBuilder) BuildErrorResponse(errorMsg string) []byte {
	return mb.BuildResponse("room-error", map[string]interface{}{
		"error": errorMsg,
	})
}

// BuildRoomCreatedResponse создает room-created response
func (mb *MessageBuilder) BuildRoomCreatedResponse(roomID string) []byte {
	return mb.BuildResponse("room-created", map[string]interface{}{
		"roomId": roomID,
	})
}

// BuildRoomJoinedResponse создает room-joined response
func (mb *MessageBuilder) BuildRoomJoinedResponse(roomID, peerID string, peerCount int) []byte {
	return mb.BuildResponse("room-joined", map[string]interface{}{
		"roomId":    roomID,
		"peerId":    peerID,
		"peerCount": peerCount,
	})
}

// BuildPeerNotificationResponse создает peer notification (peer-joined/peer-left)
func (mb *MessageBuilder) BuildPeerNotificationResponse(msgType, peerID string) []byte {
	return mb.BuildResponse(msgType, map[string]interface{}{
		"peerId": peerID,
	})
}

// BuildSignalingResponse создает signaling response (offer/answer/ice-candidate)
func (mb *MessageBuilder) BuildSignalingResponse(msgType, fromID string, payload json.RawMessage) []byte {
	return mb.BuildResponse(msgType, map[string]interface{}{
		"from":    fromID,
		"payload": payload,
	})
}

// BuildClientIdResponse создает client-id response
func (mb *MessageBuilder) BuildClientIdResponse(clientID string) []byte {
	return mb.BuildResponse("client-id", map[string]interface{}{
		"id": clientID,
	})
}

// BuildPeerListResponse создает peer-list response
func (mb *MessageBuilder) BuildPeerListResponse(peerIDs []string) []byte {
	return mb.BuildResponse("peer-list", map[string]interface{}{
		"peers": peerIDs,
	})
}

// BuildChatResponse создает chat response
func (mb *MessageBuilder) BuildChatResponse(fromID string, payload json.RawMessage) []byte {
	return mb.BuildResponse("chat", map[string]interface{}{
		"from":    fromID,
		"payload": payload,
	})
}
