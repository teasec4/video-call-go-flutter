# Video Call App - Development Plan

## Project Status

**Last Update**: February 6, 2026  
**Stage**: MVP with Room System (In Progress)
**Current Phase**: Core Features Implementation

## Completed (February 6, 2026)

### Frontend Architecture
- [x] Project structure refactoring (modular screens/services/widgets)
- [x] Riverpod state management integration
- [x] CallController with StateNotifier
- [x] Multi-screen navigation system
- [x] Start screen implementation
- [x] Room screen implementation
- [x] Home/Call screen implementation
- [x] WebRTC service initialization improvements
- [x] Basic error handling

### Features
- [x] Video calls (peer-to-peer)
- [x] Audio calls
- [x] Text chat
- [x] Room creation and joining
- [x] ICE candidates management
- [x] Microphone toggle during calls
- [x] Local and remote video rendering
- [x] Client ID generation and display
- [x] Multi-screen navigation flow

### Backend (Room System)
- [x] Room creation endpoint
- [x] Room joining endpoint
- [x] Peer notification on join/leave
- [x] Room message routing
- [x] Peer count tracking

## Current Phase: Stabilization & Polish (February 6-8, 2026)

### High Priority
- [ ] **UI/UX Polish**
  - Improve start screen design
  - Add loading states and spinners
  - Better error messages and dialogs
  - Mobile-responsive layouts
  - Dark mode support (optional)

- [ ] **Testing & Bug Fixes**
  - Test room creation/joining flow
  - Test peer connection establishment
  - Test message routing in rooms
  - Test call termination and cleanup
  - Handle edge cases (connection loss, reconnection)

- [ ] **Error Handling**
  - Graceful handling of WebSocket disconnections
  - Retry logic for failed operations
  - User-friendly error messages
  - Connection status indicators

- [ ] **Backend Robustness**
  - Message validation
  - Timeout handling
  - Clean up stale room sessions
  - Logging and monitoring

### Medium Priority
- [ ] Camera toggle during calls
- [ ] Call status indicators
- [ ] Improved video area layout
- [ ] Connection quality display
- [ ] Chat message timestamps

### Low Priority
- [ ] Screen sharing
- [ ] Call recording
- [ ] Chat history persistence
- [ ] User profiles and names
- [ ] Themes and styling customization

## File Structure

### Frontend (lib/)
```
lib/
├── main.dart                          # App entry point
├── screens/
│   ├── start_screen.dart             # Initial screen with room options
│   ├── room_screen.dart              # Create/join room interface
│   └── home_screen.dart              # Video call and chat interface
├── services/
│   ├── signaling_service.dart        # WebSocket communication
│   ├── webrtc_service.dart           # WebRTC peer connection
│   └── media_service.dart            # Camera/microphone access
├── providers/
│   └── call_controller.dart          # Riverpod state management
├── models/
│   └── message_model.dart            # Signaling message structure
└── widgets/
    ├── video_area.dart               # Local/remote video display
    ├── chat_area.dart                # Messages display
    ├── message_input.dart            # Chat input field
    └── call_controls.dart            # Mic/end call buttons
```

### Backend (cmd/server/)
```
cmd/server/
├── main.go                           # Server entry point
├── hub.go                            # WebSocket connection management
├── room.go                           # Room management logic
└── message.go                        # Message types and routing
```

## Timeline

### Phase 1: Stabilization (Current - February 6-8, 2026)
**Goal**: Polish features and fix bugs
- UI/UX improvements
- Comprehensive testing
- Error handling enhancements
- Performance optimization

### Phase 2: Features Enhancement (February 9-12, 2026)
**Goal**: Add quality-of-life features
- Camera toggle
- Status indicators
- Better chat experience
- Mobile optimizations

### Phase 3: Production Ready (February 13+)
**Goal**: Deploy and maintain
- Final testing on all platforms
- Performance profiling
- Deployment setup
- Documentation

## Known Issues & TODOs

| Issue | Priority | Status | Notes |
|-------|----------|--------|-------|
| Context usage in async operations | Medium | FIXED | Fixed use_build_context_synchronously warnings |
| Deprecated withOpacity calls | Low | TODO | Replace with withValues() |
| Print statements in production | Low | LINTING | Use logging framework |
| Mobile responsive layout | Medium | TODO | Test on different screen sizes |
| WebSocket reconnection logic | High | TODO | Add auto-reconnect |
| Error dialogs on failed operations | Medium | TODO | Improve UX |

## Success Metrics

### Functionality
- [x] Users can create rooms
- [x] Users can join rooms via room ID
- [x] P2P video/audio calls within rooms
- [x] Text chat functionality
- [ ] Graceful error handling (in progress)
- [ ] Stable WebSocket connections

### Code Quality
- [x] Modular file structure (max ~400 lines per file)
- [x] Separate services for concerns (WebRTC, Signaling, Media)
- [x] State management with Riverpod
- [ ] Comprehensive error handling
- [ ] Unit tests for critical paths

### Performance
- [ ] Signaling response time < 100ms
- [ ] Call setup time < 2 seconds
- [ ] No UI lag on any platform
- [ ] Memory usage < 200MB

### User Experience
- [ ] Intuitive flow (Start → Room → Call)
- [ ] Clear error messages
- [ ] Visual indicators for connection status
- [ ] Smooth transitions between screens

## Testing Checklist

- [ ] Single-peer call flow (create room + join)
- [ ] Text messaging during call
- [ ] Microphone toggle during call
- [ ] Call termination and cleanup
- [ ] WebSocket disconnection handling
- [ ] Invalid room ID handling
- [ ] Browser back button handling
- [ ] Mobile orientation changes
- [ ] Network interruption recovery

## Resources

**Repository**: https://github.com/teasec4/video-call-go-flutter  

**Deployment**:
- Backend: 0.0.0.0:8081 
- Frontend (web): http://localhost:3000/
- Frontend (Android): APK build
- Frontend (iOS): IPA build

**Key Dependencies**:
- Flutter 3.x
- flutter_webrtc: ^0.9.x
- flutter_riverpod: ^2.x
- web_socket_channel: ^2.x
- Go 1.21+
- gorilla/websocket: ^1.5.x

## Next Steps

1. **Immediate** (Today)
   - Fix deprecated withOpacity calls
   - Add comprehensive error handling to room operations
   - Test full room creation/joining flow

2. **Short-term** (This week)
   - Add WebSocket reconnection logic
   - Improve UI responsiveness
   - Test on mobile devices

3. **Medium-term** (Next week)
   - Implement additional features
   - Performance optimization
   - Prepare for deployment
