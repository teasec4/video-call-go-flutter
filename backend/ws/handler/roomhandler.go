package handler

import (
	"callserver/ws/room"
	"encoding/json"
	"fmt"
	"net/http"
	"regexp"
	"strings"
)

// Request types
type CreateRoomRequest struct {
	ClientId string `json:"clientId"`
}

type CreateRoomJoinRequest struct{
	RoomId string `json:"roomId"`
	ClientId string `json:"clientId"`
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
	maxClientIdLen   = 36            // UUID length
	minClientIdLen   = 1
	maxRoomIdLen     = 36            // UUID length
	minRoomIdLen     = 1
)

// UUID regex pattern: 8-4-4-4-12 hex digits
var uuidPattern = regexp.MustCompile(`^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$`)

// validateClientId validates the format and length of clientId
func validateClientId(clientId string) error {
	clientId = strings.TrimSpace(clientId)

	if len(clientId) == 0 {
		return fmt.Errorf("clientId is required")
	}

	if len(clientId) > maxClientIdLen {
		return fmt.Errorf("clientId too long (max %d characters)", maxClientIdLen)
	}

	// Allow any alphanumeric characters, hyphens, and underscores
	if !regexp.MustCompile(`^[a-zA-Z0-9_-]+$`).MatchString(clientId) {
		return fmt.Errorf("clientId contains invalid characters (only alphanumeric, hyphen, underscore allowed)")
	}

	return nil
}

// validateRoomId validates the format and length of roomId
func validateRoomId(roomId string) error {
	roomId = strings.TrimSpace(roomId)

	if len(roomId) == 0 {
		return fmt.Errorf("roomId is required")
	}

	if len(roomId) > maxRoomIdLen {
		return fmt.Errorf("roomId too long (max %d characters)", maxRoomIdLen)
	}

	// RoomId should be a valid UUID
	if !uuidPattern.MatchString(strings.ToLower(roomId)) {
		return fmt.Errorf("roomId must be a valid UUID")
	}

	return nil
}

func (rh *RoomHandler) HandleRoom(w http.ResponseWriter, r *http.Request) {
	// Check Content-Length before reading body
	if r.ContentLength == 0 {
		http.Error(w, "request body is required", http.StatusBadRequest)
		return
	}

	// Check if roomId is present to route to the right handler
	// We'll peek at the request to determine routing without consuming the body
	var req CreateRoomJoinRequest
	r.Body = http.MaxBytesReader(w, r.Body, maxBodySize)
	
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "invalid json body", http.StatusBadRequest)
		return
	}
	
	if req.RoomId == "" {
		rh.handleCreateRoomWithRequest(w, r, req)
	} else {
		rh.handleJoinRoomWithRequest(w, r, req)
	}
}

func (rh *RoomHandler) handleCreateRoomWithRequest(w http.ResponseWriter, r *http.Request, req CreateRoomJoinRequest) {
	// Validate clientId
	if err := validateClientId(req.ClientId); err != nil {
		fmt.Printf("❌ ClientId validation error: %v\n", err)
		http.Error(w, fmt.Sprintf("invalid clientId: %v", err), http.StatusBadRequest)
		return
	}

	roomId := rh.RM.CreateRoom()

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	json.NewEncoder(w).Encode(map[string]string{"roomId": roomId})
}

func (rh *RoomHandler) handleJoinRoomWithRequest(w http.ResponseWriter, r *http.Request, req CreateRoomJoinRequest) {
	// Validate clientId
	if err := validateClientId(req.ClientId); err != nil {
		fmt.Printf("❌ ClientId validation error: %v\n", err)
		http.Error(w, fmt.Sprintf("invalid clientId: %v", err), http.StatusBadRequest)
		return
	}

	// Validate roomId
	if err := validateRoomId(req.RoomId); err != nil {
		fmt.Printf("❌ RoomId validation error: %v\n", err)
		http.Error(w, fmt.Sprintf("invalid roomId: %v", err), http.StatusBadRequest)
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

	fmt.Printf("✅ JoinRoom success: clientId=%s, roomId=%s\n", req.ClientId, req.RoomId)
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(map[string]string{"status": "ok"})
}

func (rh *RoomHandler) CreateRoom(w http.ResponseWriter, r *http.Request) {
	// Check Content-Length before reading body
	if r.ContentLength == 0 {
		http.Error(w, "request body is required", http.StatusBadRequest)
		return
	}

	// Limit request body size
	r.Body = http.MaxBytesReader(w, r.Body, maxBodySize)

	var req CreateRoomRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "invalid json body", http.StatusBadRequest)
		return
	}

	// Validate clientId
	if err := validateClientId(req.ClientId); err != nil {
		http.Error(w, fmt.Sprintf("invalid clientId: %v", err), http.StatusBadRequest)
		return
	}

	roomId := rh.RM.CreateRoom()

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	json.NewEncoder(w).Encode(map[string]string{"roomId": roomId})
}

func (rh *RoomHandler) JoinRoom(w http.ResponseWriter, r *http.Request) {
	// Check Content-Length before reading body
	if r.ContentLength == 0 {
		http.Error(w, "request body is required", http.StatusBadRequest)
		return
	}

	// Limit request body size
	r.Body = http.MaxBytesReader(w, r.Body, maxBodySize)

	var req CreateRoomJoinRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		fmt.Printf("❌ JSON decode error: %v\n", err)
		http.Error(w, "invalid json body", http.StatusBadRequest)
		return
	}

	fmt.Printf("📥 JoinRoom request: clientId=%s, roomId=%s\n", req.ClientId, req.RoomId)

	// Validate clientId
	if err := validateClientId(req.ClientId); err != nil {
		fmt.Printf("❌ ClientId validation error: %v\n", err)
		http.Error(w, fmt.Sprintf("invalid clientId: %v", err), http.StatusBadRequest)
		return
	}

	// Validate roomId
	if err := validateRoomId(req.RoomId); err != nil {
		fmt.Printf("❌ RoomId validation error: %v\n", err)
		http.Error(w, fmt.Sprintf("invalid roomId: %v", err), http.StatusBadRequest)
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

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	// need to implement Joined message for client checking
	json.NewEncoder(w).Encode(map[string]string{"type": "joined"})
}