package store

import (
	"callserver/types"
	"sync"
)

type Storer struct{
	mu       sync.RWMutex
	Messages []types.Message
	RoomId string
}

func NewStorer(roomId string) *Storer{
	return &Storer{
		Messages: []types.Message{},
		RoomId: roomId,
	}
}

func (s *Storer) StoreMessageFromRoom(msg *types.Message) (bool, string){
	s.Messages = append(s.Messages, *msg)
	return true, ""
}