# Video Call App - Concept

## Description
An application for peer-to-peer video calling with text chat support. Uses WebRTC for direct connection between participants and a WebSocket signaling server for exchanging initialization data.

## Technology Stack

### Frontend
- **Framework**: Flutter
- **WebRTC**: flutter_webrtc
- **Signaling**: web_socket_channel
- **Platforms**: Web, iOS, Android

### Backend
- **Language**: Go
- **WebSocket**: gorilla/websocket
- **Architecture**: Signaling server (does not process media)

## Core Components

### 1. Signaling Server (Backend)
Manages the exchange of signaling messages between clients:
- Generates unique client IDs
- Routes WebRTC offer/answer/ICE-candidates
- Maintains list of connected peers
- Delivers chat messages

**Port**: 8081  
**Endpoint**: `/ws`

### 2. Frontend Application
Client application for video calling:
- Capturing media from your device (camera + microphone)
- Initiating/receiving calls
- Sending and receiving video/audio streams
- Text chat with other clients
- Media management (microphone enable/disable toggle)

## Features

### Implemented ✓
- [x] Video calls (peer-to-peer)
- [x] Audio calls
- [x] Text chat
- [x] Automatic peer discovery
- [x] ICE candidates buffering
- [x] Microphone toggle during calls
- [x] Displaying list of available peers
- [x] Local and remote video

### Planned
- [ ] Rooms/Sessions (instead of direct peer list)
- [ ] UI Improvements
- [ ] Code structure refactoring
- [ ] Camera toggle
- [ ] Screen sharing
- [ ] Call recording
- [ ] Enhanced error handling

## Data Flows

```
Client A               Signaling Server              Client B
    |                          |                          |
    |---- WebSocket connect ---|                          |
    |---- client-id message ----|                          |
    |                          |---- WebSocket connect ---|
    |                          |---- client-id message ----|
    |                          |                          |
    | (sees Client B in list)    (sees Client A in list)
    |                          |                          |
    |-- initiate call -------->|                          |
    |       offer              |---- offer message ------->|
    |                          |                          |
    |                          |<---- answer message ------|
    |<------- answer --------------|                      |
    |                          |                          |
    |<---- ICE candidates ---->|---- ICE candidates ----->|
    |                          |<---- ICE candidates -----|
    |                          |                          |
    |========== P2P WebRTC Connection ===========|          |
    |              Video/Audio/Data              ---------|
    |                          |                          |
```

## Signaling Messages

| Type | From | To | Description |
|------|------|----|----|
| client-id | Server | Client | Send client ID |
| peer-list | Server | Client | List of available peers |
| peer-joined | Server | All | Notification of new peer joining |
| peer-left | Server | All | Notification of peer disconnecting |
| offer | Client | Peer | WebRTC offer SDP |
| answer | Client | Peer | WebRTC answer SDP |
| ice-candidate | Client | Peer | ICE candidate for P2P connection |
| chat | Client | All | Text message |
