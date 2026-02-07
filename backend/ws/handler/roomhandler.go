package handler

import (
	"callserver/ws/room"
	"encoding/json"
	"fmt"
	"net/http"
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

func (rh *RoomHandler) CreateRoom(w http.ResponseWriter, r *http.Request){
	w.Header().Set("Access-Control-Allow-Origin", "*")
	w.Header().Set("Access-Control-Allow-Methods", "POST, GET, OPTIONS")
	w.Header().Set("Access-Control-Allow-Headers", "Content-Type")
	
	if r.Method == http.MethodOptions {
		w.WriteHeader(http.StatusOK)
		return
	}

	fmt.Println("✅ Request received:", r.Method, r.URL.Path)
	
	var req CreateRoomRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		fmt.Println("❌ Decode error:", err)
		http.Error(w, "invalid json body", http.StatusBadRequest)
		return
	}

	if req.ClientId == "" {
		fmt.Println("❌ ClientId is empty")
		http.Error(w, "clientId is required", http.StatusBadRequest)
		return
	}

	roomId := rh.RM.CreateRoom()
	
	fmt.Println("✅ Room created:", roomId)
	
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	json.NewEncoder(w).Encode(map[string]string{"roomId": roomId})
}

func (rh *RoomHandler) JoinRoom(w http.ResponseWriter, r *http.Request){
	w.Header().Set("Access-Control-Allow-Origin", "*")
	w.Header().Set("Access-Control-Allow-Methods", "POST, GET, OPTIONS")
	w.Header().Set("Access-Control-Allow-Headers", "Content-Type")
	
	if r.Method == http.MethodOptions {
		w.WriteHeader(http.StatusOK)
		return
	}
	
	fmt.Println("✅ Request received:", r.Method, r.URL.Path)
	
	var req CreateRoomJoinRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		fmt.Println("❌ Decode error:", err)
		http.Error(w, "invalid json body", http.StatusBadRequest)
		return
	}

	if req.ClientId == ""{
		fmt.Println("❌ ClientId is empty")
		http.Error(w, "clientId is required", http.StatusBadRequest)
		return
	}
	if req.RoomId == ""{
		fmt.Println("❌ RoomId is empty")
		http.Error(w, "RoomId is required", http.StatusBadRequest)
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