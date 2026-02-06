package message

import (
	"encoding/json"
)

// Response представляет стандартный ответ сервера
type Response struct {
	Type    string                 `json:"type"`
	Payload map[string]interface{} `json:"payload"`
}

// ChatMessage представляет chat сообщение с from на верхнем уровне
type ChatMessage struct {
	Type    string      `json:"type"`
	From    string      `json:"from"`
	Payload interface{} `json:"payload"`
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

// BuildRoomJoinedResponseWithPeer создает room-joined response с ID другого пира в комнате
func (mb *MessageBuilder) BuildRoomJoinedResponseWithPeer(roomID, clientID, otherClientID string, peerCount int) []byte {
	return mb.BuildResponse("room-joined", map[string]interface{}{
		"roomId":        roomID,
		"peerId":        clientID,
		"connectedPeer": otherClientID,
		"peerCount":     peerCount,
	})
}

// BuildPeerNotificationResponse создает peer notification (peer-joined/peer-left)
func (mb *MessageBuilder) BuildPeerNotificationResponse(msgType, peerID string, peerCount int) []byte {
	return mb.BuildResponse(msgType, map[string]interface{}{
		"peerId":    peerID,
		"peerCount": peerCount,
	})
}

// BuildSignalingResponse создает signaling response (offer/answer/ice-candidate)
// Структура: { type: "offer/answer/ice-candidate", from: "ID", payload: {...} }
func (mb *MessageBuilder) BuildSignalingResponse(msgType, fromID string, payload json.RawMessage) []byte {
	// Распарсим payload чтобы развернуть его на верхнем уровне
	var payloadObj map[string]interface{}
	if err := json.Unmarshal(payload, &payloadObj); err != nil {
		mb.logger.Println("Failed to unmarshal payload:", err)
		return nil
	}

	// Создаём правильную структуру с from на верхнем уровне
	response := map[string]interface{}{
		"type": msgType,
		"from": fromID,
	}
	
	// Добавляем все поля из payload на верхний уровень
	for k, v := range payloadObj {
		response[k] = v
	}

	bytes, err := json.Marshal(response)
	if err != nil {
		mb.logger.Println("Failed to marshal signaling response:", err)
		return nil
	}

	return bytes
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

// BuildChatResponse создает chat response с from на верхнем уровне
func (mb *MessageBuilder) BuildChatResponse(fromID string, payload json.RawMessage) []byte {
	chatMsg := ChatMessage{
		Type:    "chat",
		From:    fromID,
		Payload: json.RawMessage(payload),
	}
	
	bytes, err := json.Marshal(chatMsg)
	if err != nil {
		mb.logger.Println("Failed to marshal chat message:", err)
		return nil
	}
	
	return bytes
}
