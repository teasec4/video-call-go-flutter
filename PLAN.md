# Video Call App - Development Plan

## Project Status

**Last Update**: January 22, 2026  
**Stage**: MVP (Minimum Viable Product)

## Completed (January 22, 2026)

- [x] Basic project architecture
- [x] Signaling server in Go
- [x] Frontend in Flutter (web, mobile)
- [x] WebRTC peer-to-peer video calls
- [x] Text chat
- [x] Automatic peer discovery
- [x] ICE candidates buffering
- [x] Microphone toggle during calls

## Plan for January 23, 2026

### High Priority
- [ ] **Code Structure Refactoring** (frontend)
  - Split main.dart into multiple files
  - Create separate classes for WebRTC logic
  - Create separate service for WebSocket
  - File structure:
    ```
    lib/
    ├── main.dart
    ├── screens/
    │   └── home_screen.dart
    ├── services/
    │   ├── signaling_service.dart
    │   └── webrtc_service.dart
    ├── widgets/
    │   ├── video_area.dart
    │   └── chat_area.dart
    └── models/
        └── message.dart
    ```

- [ ] **UI/UX Improvements**
  - Redesign video-to-video viewing layout
  - Improve visual representation of call state
  - Add connection quality indicators
  - Improve styling of buttons and controls

- [ ] **Room Support**
  - Add room creation/joining
  - Backend modification for room support
  - Update frontend for room selection
  - Message structure:
    ```json
    {
      "type": "join-room",
      "room": "room-id"
    }
    ```

### Medium Priority
- [ ] Camera toggle during calls
- [ ] Enhanced error handling
- [ ] WebSocket message validation on backend
- [ ] Logging and monitoring

### Low Priority
- [ ] Screen sharing
- [ ] Call recording
- [ ] Chat history
- [ ] User profiles

## Timeline

### Phase 1: Stabilization (January 23-24, 2026)
**Goal**: Clean, maintainable code and intuitive interface
- Code structure refactoring
- UI/UX improvements
- Testing and bug fixes

### Phase 2: Scalability (January 25-27, 2026)
**Goal**: Support for group calls via rooms
- Implementation of room system on backend
- Integration into frontend
- Testing multi-user scenarios

### Phase 3: Polish (January 28+)
**Goal**: Production-ready application
- Additional features (camera toggle, recording)
- Performance optimization
- Deployment

## Known Issues

| Issue | Priority | Status |
|-------|----------|--------|
| Large monolithic main.dart file | High | TODO |
| Basic UI without styling | Medium | TODO |
| No group call support | High | TODO |
| No network error handling | Medium | TODO |

## Success Metrics

- [ ] Code divided into modules (max 200 lines per file)
- [ ] Working group calls with 3+ participants in one room
- [ ] Signaling response time < 100ms
- [ ] UI runs without lag on all platforms
- [ ] 100% handling of edge cases (connection loss, reconnection, etc.)

## Contacts and Notes

**Repository**: https://github.com/teasec4/video-call-go-flutter  
**Deployment**: 
- Backend: 0.0.0.0:8081 
- Frontend (web): http://localhost/
