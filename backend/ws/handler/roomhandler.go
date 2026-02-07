package handler

import (
	"callserver/ws/room"
	"encoding/json"
	"fmt"
	"net/http"
)

type RoomHandler struct{
	RM *room.RoomManager
}

func NewRoomHandler(rm *room.RoomManager) *RoomHandler{
	return &RoomHandler{
		RM: rm,
	}
}

func (rh *RoomHandler) CreateRoom(w http.ResponseWriter, r *http.Request){
	fmt.Println("✅ Request received:", r.Method, r.URL.Path)
	w.Header().Set("Access-Control-Allow-Origin", "*")
	w.Header().Set("Access-Control-Allow-Methods", "POST, GET, OPTIONS")
	w.Header().Set("Access-Control-Allow-Headers", "Content-Type")
	
	roomId := rh.RM.CreateRoom()
	fmt.Println("✅ Room created:", roomId)
	
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated) // <- ДОБАВЬ ЭТО
	err := json.NewEncoder(w).Encode(map[string]string{"roomId": roomId})
	if err != nil {
		fmt.Println("❌ Error encoding response:", err)
	}
	fmt.Println("✅ Response sent")


}

func (rh *RoomHandler) JoinRoom(w http.ResponseWriter, r *http.Request){
	
}