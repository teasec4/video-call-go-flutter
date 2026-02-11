package handler

import (
	"callserver/ws/room"
	"encoding/json"
	"fmt"
	"net/http"
	"regexp"
	"strings"
)

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
	w.Header().Set("Access-Control-Allow-Origin", "*")
	w.Header().Set("Access-Control-Allow-Methods", "POST, GET, OPTIONS")
	w.Header().Set("Access-Control-Allow-Headers", "Content-Type")

	if r.Method == http.MethodOptions {
		w.WriteHeader(http.StatusOK)
		return
	}

	// Limit request body size
	r.Body = http.MaxBytesReader(w, r.Body, maxBodySize)

	var req CreateRoomJoinRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		fmt.Println("❌ Decode error:", err)
		http.Error(w, "invalid json body", http.StatusBadRequest)
		return
	}
	if req.RoomId == "" {
		rh.CreateRoom(w, r)
	} else {
		rh.JoinRoom(w, r)
	}
}

func (rh *RoomHandler) CreateRoom(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Access-Control-Allow-Origin", "*")
	w.Header().Set("Access-Control-Allow-Methods", "POST, GET, OPTIONS")
	w.Header().Set("Access-Control-Allow-Headers", "Content-Type")

	if r.Method == http.MethodOptions {
		w.WriteHeader(http.StatusOK)
		return
	}

	fmt.Println("✅ Request received:", r.Method, r.URL.Path)

	// Limit request body size
	r.Body = http.MaxBytesReader(w, r.Body, maxBodySize)

	var req CreateRoomRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		fmt.Println("❌ Decode error:", err)
		http.Error(w, "invalid json body", http.StatusBadRequest)
		return
	}

	// Validate clientId
	if err := validateClientId(req.ClientId); err != nil {
		fmt.Println("❌ Validation error:", err)
		http.Error(w, fmt.Sprintf("invalid clientId: %v", err), http.StatusBadRequest)
		return
	}

	roomId := rh.RM.CreateRoom()

	fmt.Println("✅ Room created:", roomId)

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	json.NewEncoder(w).Encode(map[string]string{"roomId": roomId})
}

func (rh *RoomHandler) JoinRoom(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Access-Control-Allow-Origin", "*")
	w.Header().Set("Access-Control-Allow-Methods", "POST, GET, OPTIONS")
	w.Header().Set("Access-Control-Allow-Headers", "Content-Type")

	if r.Method == http.MethodOptions {
		w.WriteHeader(http.StatusOK)
		return
	}

	fmt.Println("✅ Request received:", r.Method, r.URL.Path)

	// Limit request body size
	r.Body = http.MaxBytesReader(w, r.Body, maxBodySize)

	var req CreateRoomJoinRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		fmt.Println("❌ Decode error:", err)
		http.Error(w, "invalid json body", http.StatusBadRequest)
		return
	}

	// Validate clientId
	if err := validateClientId(req.ClientId); err != nil {
		fmt.Println("❌ Validation error:", err)
		http.Error(w, fmt.Sprintf("invalid clientId: %v", err), http.StatusBadRequest)
		return
	}

	// Validate roomId
	if err := validateRoomId(req.RoomId); err != nil {
		fmt.Println("❌ Validation error:", err)
		http.Error(w, fmt.Sprintf("invalid roomId: %v", err), http.StatusBadRequest)
		return
	}

	room := rh.RM.GetRoom(req.RoomId)
	if room == nil {
		http.Error(w, "room not found", http.StatusNotFound)
		return
	}

	fmt.Println("✅ Joined room:", room.ID)

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(map[string]string{"status": "ok"})
}