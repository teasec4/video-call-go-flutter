# Backend Improvements & Bug Fixes Plan

## Critical Issues (Must Fix)

### 1. **WebRTC Message Handling Not Implemented**
- **Location**: `ws/handler/handlerws.go` line 101-103
- **Issue**: offer, answer, ice-candidate cases are empty
- **Impact**: WebRTC signaling won't work
- **Solution**:
  ```go
  case "offer", "answer", "ice-candidate":
      // Forward to specific peer if 'to' field is present
      if msg.To != "" {
          targetClient := h.RoomManager.GetClientInRoom(roomId, msg.To)
          if targetClient != nil {
              respBytes, _ := json.Marshal(msg)
              targetClient.Conn.WriteMessage(websocket.TextMessage, respBytes)
          }
      }
  ```

### 2. **No Room Capacity Validation on Join**
- **Location**: `ws/handler/roomhandler.go` JoinRoom function
- **Issue**: Can join full room (MaxPeersPerRoom = 2 is not enforced)
- **Impact**: Rooms can exceed capacity
- **Solution**: Add check before allowing join
  ```go
  if len(room.Clients) >= config.MaxPeersPerRoom {
      http.Error(w, "room is full", http.StatusForbidden)
      return
  }
  ```

### 3. **Data Race in BroadcastToRoom**
- **Location**: `ws/room/room.go` BroadcastToRoom function
- **Issue**: Reads room.Clients without write lock protection
- **Impact**: Concurrent map access panic
- **Solution**: Proper locking throughout

### 4. **CORS Configuration Too Permissive**
- **Location**: `config/config.go` CheckOrigin
- **Issue**: `CheckOrigin: true` allows any origin (security risk)
- **Impact**: CSRF vulnerability in production
- **Solution**: 
  ```go
  CheckOrigin: func(r *http.Request) bool {
      // Whitelist allowed origins
      allowedOrigins := map[string]bool{
          "http://localhost:3000": true,
          // Add production URL
      }
      return allowedOrigins[r.Header.Get("Origin")]
  }
  ```

### 5. **WriteMessage Error Not Handled**
- **Location**: `ws/handler/handlerws.go` line 43
- **Issue**: If WriteMessage fails, connection stays open but won't respond
- **Impact**: Dead connections accumulate
- **Solution**: Close connection on write error
  ```go
  if err := c.Conn.WriteMessage(websocket.TextMessage, msg); err != nil {
      log.Println("Write error, closing connection:", err)
      c.Conn.Close()
      return
  }
  ```

---

## High Priority Issues

### 6. **Code Duplication: CORS Headers**
- **Location**: `ws/handler/roomhandler.go` CreateRoom & JoinRoom
- **Issue**: Identical CORS headers in two functions
- **Solution**: Create middleware
  ```go
  func corsMiddleware(next http.Handler) http.Handler {
      return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
          w.Header().Set("Access-Control-Allow-Origin", "*")
          w.Header().Set("Access-Control-Allow-Methods", "POST, GET, OPTIONS")
          w.Header().Set("Access-Control-Allow-Headers", "Content-Type")
          
          if r.Method == http.MethodOptions {
              w.WriteHeader(http.StatusOK)
              return
          }
          next.ServeHTTP(w, r)
      })
  }
  ```

### 7. **Use Constants Instead of Hardcoded Strings**
- **Location**: Multiple files
- **Issue**: Magic strings like "chat", "user-left", "offer" scattered in code
- **Impact**: Hard to maintain, easy to break
- **Solution**: Use constants from `config/constants.go`
  - Already defined but not used consistently
  - Update handlerws.go to use MessageTypeChat, MessageTypeOffer, etc.

### 8. **No Request Body Size Limit**
- **Location**: `ws/handler/roomhandler.go`
- **Issue**: Can receive arbitrarily large JSON payloads
- **Impact**: Memory exhaustion, DOS attack
- **Solution**: 
  ```go
  r.Body = http.MaxBytesReader(w, r.Body, 1<<20) // 1MB limit
  ```

### 9. **Missing Input Validation**
- **Location**: `ws/handler/roomhandler.go`
- **Issue**: ClientId could be very long or contain invalid characters
- **Solution**: Validate length and format
  ```go
  if len(req.ClientId) > 36 || len(req.ClientId) < 1 {
      http.Error(w, "invalid clientId length", http.StatusBadRequest)
      return
  }
  ```

### 10. **No WebSocket Read/Write Timeout**
- **Location**: `ws/handler/handlerws.go`
- **Issue**: Client can hang indefinitely
- **Solution**: 
  ```go
  conn.SetReadDeadline(time.Now().Add(60 * time.Second))
  conn.SetWriteDeadline(time.Now().Add(10 * time.Second))
  ```

---

## Medium Priority Issues

### 11. **Unused Room.Messages Field**
- **Location**: `ws/room/room.go` Room struct
- **Issue**: Messages slice created but never used
- **Solution**: Either implement message history or remove it

### 12. **No Graceful Shutdown for WebSocket Connections**
- **Location**: `main.go`
- **Issue**: Active connections not closed on server shutdown
- **Solution**: Track active connections and close them gracefully

### 13. **Inconsistent Error Messages**
- **Location**: `ws/handler/roomhandler.go`
- **Issue**: Mix of lowercase and capitalized error messages
- **Solution**: Standardize format (lowercase, use constants)

### 14. **No Request Logging Middleware**
- **Location**: `main.go`
- **Issue**: No structured logging of all requests
- **Solution**: Add HTTP middleware for request/response logging

### 15. **Empty Body Error Not Handled**
- **Location**: `ws/handler/roomhandler.go`
- **Issue**: json.NewDecoder can panic on nil body
- **Solution**: Check Content-Length header first

---

## Code Quality Improvements

### 16. **Replace fmt.Println with Structured Logging**
- **Location**: All files
- **Issue**: Using fmt.Println instead of log package
- **Solution**: Use `log.Printf` with consistent format or introduce a logger package

### 17. **Add Method Documentation**
- **Location**: All public functions
- **Issue**: No godoc comments
- **Solution**: 
  ```go
  // BroadcastToRoom sends a message to all clients in the specified room.
  // It returns silently if the room doesn't exist.
  func (rm *RoomManager) BroadcastToRoom(roomId string, msg []byte) {
  ```

### 18. **Extract Message Handling Logic**
- **Location**: `ws/handler/handlerws.go` HandleConnection method
- **Issue**: Function too large (100+ lines)
- **Solution**: Split into smaller functions:
  - handleChatMessage()
  - handleWebRTCMessage()
  - handleConnectionClose()

### 19. **Create Response Types**
- **Location**: `types/types.go`
- **Issue**: Using `map[string]string` for responses
- **Solution**: 
  ```go
  type CreateRoomResponse struct {
      RoomId string `json:"roomId"`
  }
  type ErrorResponse struct {
      Error string `json:"error"`
      Code  int    `json:"code"`
  }
  ```

### 20. **Add Unit Tests**
- **Location**: All packages
- **Issue**: No tests
- **Solution**: Create test files for room manager and handlers

---

## Implementation Priority

| Priority | Task | Effort | Impact |
|----------|------|--------|--------|
| 1 | Fix WebRTC message handling (#1) | 1h | Critical |
| 2 | Add room capacity validation (#2) | 30m | Critical |
| 3 | Fix data race issue (#3) | 1h | Critical |
| 4 | Handle WriteMessage errors (#5) | 30m | High |
| 5 | Fix CORS security (#4) | 1h | High |
| 6 | Use constants throughout (#7) | 1h | Medium |
| 7 | Add request size limits (#8) | 30m | Medium |
| 8 | Add timeout settings (#10) | 30m | Medium |
| 9 | Extract response types (#19) | 1h | Medium |
| 10 | Extract handler logic (#18) | 2h | Low |

---

## Testing Checklist

- [ ] Test sending multiple messages in sequence
- [ ] Test WebRTC offer/answer flow
- [ ] Test room capacity limits
- [ ] Test graceful disconnection
- [ ] Test error handling for invalid JSON
- [ ] Load test with 100+ concurrent connections
- [ ] Test CORS origin validation

