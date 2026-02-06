# Video Call App - Concept

## Description
An application for peer-to-peer video calling with text chat support using WebRTC. Users can create or join rooms to establish video/audio connections with other participants. Uses a WebSocket signaling server for exchanging initialization data and managing room state.

## Technology Stack

### Frontend
- **Framework**: Flutter
- **WebRTC**: flutter_webrtc
- **State Management**: Flutter Riverpod
- **Signaling**: web_socket_channel
- **Platforms**: Web, iOS, Android

### Backend
- **Language**: Go
- **WebSocket**: gorilla/websocket
- **Architecture**: Signaling and Room management server (does not process media)

## Core Components

### 1. Signaling Server (Backend)
Manages the exchange of signaling messages and room sessions:
- Generates unique client IDs
- Creates and manages rooms
- Routes WebRTC offer/answer/ICE-candidates between peers
- Maintains list of connected peers per room
- Delivers chat messages within rooms

**Port**: 8081  
**Endpoint**: `/ws`

### 2. Frontend Application
Multi-screen client application:

#### Start Screen
- First screen users see when launching the app
- Shows user's unique client ID (once initialized)
- Two main actions: "Create Room" or "Join Room"
- Clean, minimal UI with app branding

#### Room Screen
- **Create Room**: Generates new room ID and waits for peer to join
- **Join Room**: Allows pasting existing room ID to join
- Displays current room status and peer count
- Shows "Start Call" button when peer joins
- Enables transition to video call experience

#### Home Screen (Call Screen)
- Video display area (local and remote)
- Text chat panel (collapsible)
- Call controls (microphone toggle, end call)
- Message input and sending

## Features

### Implemented ✓
- [x] Video calls (peer-to-peer)
- [x] Audio calls
- [x] Text chat
- [x] Room creation and joining
- [x] ICE candidates buffering
- [x] Microphone toggle during calls
- [x] Local and remote video rendering
- [x] Multi-screen navigation (Start → Room → Call)
- [x] Client ID generation and display

### Planned
- [ ] Camera toggle during calls
- [ ] UI/UX enhancements
- [ ] Screen sharing
- [ ] Call recording
- [ ] Enhanced error handling and recovery
- [ ] Connection quality indicators

## Application Flow

```
Launch App
    ↓
[Start Screen] - Show client ID, choose action
    ↓
    ├─→ Create Room → [Room Screen] → Share Room ID → Wait for peer
    │                      ↓
    │              Peer joins room
    │                      ↓
    │             [Start Call] button enabled
    │                      ↓
    └──────→ [Home Screen] ← Join Room (via Room ID)
                    ↓
            P2P WebRTC Call + Chat
```

## Data Flows

```
Client A               Signaling Server              Client B
    |                          |                          |
    |--- WebSocket connect ----|                          |
    |                          |--- WebSocket connect ----|
    |                          |                          |
    |--- create-room --------->|                          |
    |<-- room-created ---------|                          |
    |   (gets room ID)         |                          |
    |                          |<-- join-room ------------|
    |                          |   (with room ID)         |
    |<-- peer-joined -----------|                          |
    |                          |--- peer-joined -------->|
    |                          |                          |
    |-- offer message -------->|                          |
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
| create-room | Client | Server | Request to create new room |
| room-created | Server | Client | Room created with ID |
| join-room | Client | Server | Request to join existing room |
| room-joined | Server | Client | Successfully joined room |
| room-error | Server | Client | Error joining room |
| peer-joined | Server | All in room | Notification of peer joining |
| peer-left | Server | All in room | Notification of peer leaving |
| leave-room | Client | Server | Request to leave room |
| offer | Client | Peer | WebRTC offer SDP |
| answer | Client | Peer | WebRTC answer SDP |
| ice-candidate | Client | Peer | ICE candidate for P2P connection |
| chat | Client | Peers | Text message in room |

## Navigation Structure

```
StartScreen
├── onCreateRoom → RoomScreen (create mode)
└── onJoinRoom → RoomScreen (join mode)
        │
        └── onStartCall → HomeScreen (call active)
                    │
                    └── onEndCall → RoomScreen
                    └── onLeaveRoom → StartScreen
```
