package handler

import (
	"callserver/ws/room"
	"encoding/json"
	"fmt"
	"net/http"
)

// type for create or join
type ReqType string
type ResType string

const (
	typeCreate ReqType = "create"
	typeJoin ReqType = "join"
	
	typeCreated ResType = "created"
	typeJoined ResType = "joined"
)

type reqData struct{
	RoomId string `json:"roomId"`
	ClientId string `json:"clientId"`
}

type resData struct{
	RoomId string `json:"roomId"`
}

// create or join room req
type reqToRoomManager struct{
	Type ReqType `json:"type"`
	Payload reqData `json:"payload"`
}

type resFromRoomManager struct{
	Type ResType `json:"type"`
	Payload resData `json:"payload"`
}

type RoomHandler struct{
	RM *room.RoomManager
}

func NewRoomHandler(rm *room.RoomManager) *RoomHandler{
	return &RoomHandler{
		RM: rm,
	}
}

// Константы валидации
const (
	maxBodySize      = 1 << 20       // 1MB
)

func (rh *RoomHandler) HandleRoom(w http.ResponseWriter, r *http.Request) {
	// Check Content-Length before reading body
	if r.ContentLength == 0 {
		http.Error(w, "request body is required", http.StatusBadRequest)
		return
	}
	// check POST method
	if r.Method != http.MethodPost {
	    http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
	    return
	}

	// Check if roomId is present to route to the right handler
	// We'll peek at the request to determine routing without consuming the body
	var req reqToRoomManager
	r.Body = http.MaxBytesReader(w, r.Body, maxBodySize)
	// Check empty body
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "invalid json body", http.StatusBadRequest)
		return
	}
	
	if !req.Type.IsValid() {
    http.Error(w, "invalid type of request", http.StatusBadRequest)
    return
}
	switch req.Type{
		case typeCreate:
			rh.handleCreateRoomWithRequest(w, r, req.Payload)
			
		case typeJoin:
			rh.handleJoinRoomWithRequest(w, r, req.Payload)
		
		default:
			http.Error(w, "invalid type of request", http.StatusBadRequest)
			return
	}

}

func (rh *RoomHandler) handleCreateRoomWithRequest(w http.ResponseWriter, r *http.Request, req reqData) {
	if req.ClientId == "" {
    http.Error(w, "clientId is required", http.StatusBadRequest)
    return
}
	
	roomId := rh.RM.CreateRoom(req.ClientId)
	
	// Add the client to the room
	err := rh.RM.JoinRoom(roomId, req.ClientId)
	if err != nil {
		http.Error(w, fmt.Sprintf("error joining room: %v", err), http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	
	responseJson := resFromRoomManager{
		Type: typeCreated,
		Payload: resData{
			RoomId: roomId,
		},
	}
	json.NewEncoder(w).Encode(responseJson)
}

func (rh *RoomHandler) handleJoinRoomWithRequest(w http.ResponseWriter, r *http.Request, req reqData) {
	if req.RoomId == "" {
    http.Error(w, "roomId is required", http.StatusBadRequest)
    return
}
	room, err := rh.RM.GetRoom(req.RoomId)
	if err != nil {
		fmt.Printf("❌ GetRoom error: %v\n", err)
		http.Error(w, fmt.Sprintf("error getting room: %v", err), http.StatusBadRequest)
		return
	}
	if room == nil {
		http.Error(w, "room not found", http.StatusNotFound)
		return
	}
	err = rh.RM.JoinRoom(req.RoomId, req.ClientId)
	if err != nil{
		http.Error(w, fmt.Sprintf("error creating room: %v", err), http.StatusBadRequest)
		return
	}
	fmt.Printf("✅ JoinRoom success: clientId=%s, roomId=%s\n", req.ClientId, req.RoomId)
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	
	response := resFromRoomManager{
		Type: typeJoined,
		Payload: resData{
			RoomId: room.ID,
		},
	}
	json.NewEncoder(w).Encode(response)
	
}

func (t ReqType) IsValid()bool{
	switch t{
		case typeCreate, typeJoin:
		return true
		default:
		return false
	}
}