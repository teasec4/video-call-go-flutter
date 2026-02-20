package domain

// DomainError базовая ошибка домена
type DomainError struct {
	Code    string
	Message string
}

func (e *DomainError) Error() string {
	return e.Message
}

// Predefined errors
var (
	ErrRoomNotFound = &DomainError{
		Code:    "ROOM_NOT_FOUND",
		Message: "room not found",
	}
	
	ErrClientNotFound = &DomainError{
		Code:    "CLIENT_NOT_FOUND",
		Message: "client not found",
	}
	
	ErrRoomAlreadyExists = &DomainError{
		Code:    "ROOM_ALREADY_EXISTS",
		Message: "room already exists",
	}
	
	ErrClientAlreadyInRoom = &DomainError{
		Code:    "CLIENT_ALREADY_IN_ROOM",
		Message: "client already in room",
	}
	
	ErrInvalidMessage = &DomainError{
		Code:    "INVALID_MESSAGE",
		Message: "invalid message",
	}
	
	ErrWebSocketConnection = &DomainError{
		Code:    "WEBSOCKET_CONNECTION_ERROR",
		Message: "websocket connection failed",
	}
)
