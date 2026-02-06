package config

// Room configuration constants
const (
	// MaxPeersPerRoom максимальное количество пиров в комнате
	MaxPeersPerRoom = 2
	
	// MessageBufferSize размер буфера для сообщений
	MessageBufferSize = 1000
)

// Error messages
const (
	ErrRoomNotFound   = "Room not found"
	ErrRoomFull       = "Room is full"
	ErrInvalidPayload = "Invalid payload"
	ErrPeerNotFound   = "Peer not found"
)

// Message types
const (
	MessageTypeCreateRoom    = "create-room"
	MessageTypeJoinRoom      = "join-room"
	MessageTypeLeaveRoom     = "leave-room"
	MessageTypeRoomCreated   = "room-created"
	MessageTypeRoomJoined    = "room-joined"
	MessageTypeRoomError     = "room-error"
	MessageTypePeerJoined    = "peer-joined"
	MessageTypePeerLeft      = "peer-left"
	MessageTypeChat          = "chat"
	MessageTypeListPeers     = "list-peers"
	MessageTypeClientId      = "client-id"
	MessageTypePeerList      = "peer-list"
	MessageTypeOffer         = "offer"
	MessageTypeAnswer        = "answer"
	MessageTypeIceCandidate  = "ice-candidate"
)
