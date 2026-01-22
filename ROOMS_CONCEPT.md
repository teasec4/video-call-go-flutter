# Room System - Concept & Architecture

## Overview

Transform the video call system from direct peer-to-peer discovery to a room-based system where multiple participants can join named rooms and conduct group video calls.

## Current vs. Proposed Architecture

### Current Flow
```
Client A connects → Gets ID → Sees all other clients in list → Calls specific peer → P2P connection
```

### Proposed Flow
```
Client A connects → Gets ID → Joins/Creates Room → Sees room members → Can call any room member → P2P connections with each member
```

## Room Structure

### Room Entity
```
Room {
  id: string              // unique room identifier
  name: string            // human-readable name
  createdAt: timestamp    // creation time
  host: clientID          // creator of the room
  maxParticipants: int    // optional limit (0 = unlimited)
  participants: []        // list of client IDs in room
  metadata: {             // optional
    description: string
    private: bool
  }
}
```

### Room States

```
EMPTY → ACTIVE → IN_CALL → ACTIVE → EMPTY
  ↓        ↑                   ↓
  └─────────────────────────────┘
```

- **EMPTY**: Room exists but no participants
- **ACTIVE**: Participants in room, no active calls
- **IN_CALL**: At least 2 participants in video/audio call

## Client Lifecycle

### 1. Connect Phase
```
Client connects via WebSocket
    ↓
Server sends: { "type": "client-id", "id": "uuid" }
    ↓
Client ready for room operations
```

### 2. Pre-Room Phase
Options:
- **Option A**: Join existing room
- **Option B**: Create new room
- **Option C**: List available rooms

### 3. Room Phase
```
Client in room receives:
- List of current room members
- Notifications when members join/leave
- Signaling for calls within room
```

### 4. Call Phase (within room)
```
Client A initiates call with Client B (both in same room)
    ↓
Client A sends offer to Client B via signaling server
    ↓
P2P connection established
    ↓
Both still in room, other members can initiate calls with them
```

## Signaling Messages

### Room Management

#### 1. Create Room
**Client → Server**
```json
{
  "type": "create-room",
  "payload": {
    "name": "Team Meeting",
    "maxParticipants": 10
  }
}
```

**Server → Client**
```json
{
  "type": "room-created",
  "room": {
    "id": "room-uuid",
    "name": "Team Meeting",
    "createdAt": "2026-01-22T10:30:00Z",
    "host": "client-uuid",
    "maxParticipants": 10,
    "participants": ["client-uuid"]
  }
}
```

#### 2. Join Room
**Client → Server**
```json
{
  "type": "join-room",
  "payload": {
    "roomId": "room-uuid"
  }
}
```

**Server → Client (joiner)**
```json
{
  "type": "room-joined",
  "room": {
    "id": "room-uuid",
    "participants": ["client-1", "client-2", "client-3"]
  }
}
```

**Server → Room Members**
```json
{
  "type": "member-joined",
  "roomId": "room-uuid",
  "memberId": "new-client-uuid",
  "participants": ["client-1", "client-2", "new-client-uuid"]
}
```

#### 3. Leave Room
**Client → Server**
```json
{
  "type": "leave-room",
  "payload": {
    "roomId": "room-uuid"
  }
}
```

**Server → Room Members**
```json
{
  "type": "member-left",
  "roomId": "room-uuid",
  "memberId": "leaving-client-uuid",
  "participants": ["client-1", "client-2"]
}
```

#### 4. List Rooms
**Client → Server**
```json
{
  "type": "list-rooms"
}
```

**Server → Client**
```json
{
  "type": "rooms-list",
  "rooms": [
    {
      "id": "room-1",
      "name": "Team Meeting",
      "participantCount": 3
    },
    {
      "id": "room-2",
      "name": "Design Review",
      "participantCount": 2
    }
  ]
}
```

### In-Room Signaling (same as before)

#### Offer/Answer/ICE
**Client A → Server (marked with roomId)**
```json
{
  "type": "offer",
  "roomId": "room-uuid",
  "to": "client-b-uuid",
  "payload": {
    "sdp": "...",
    "type": "offer"
  }
}
```

**Server → Client B** (if in same room)
```json
{
  "type": "offer",
  "from": "client-a-uuid",
  "payload": {
    "sdp": "...",
    "type": "offer"
  }
}
```

### Chat in Room

**Client → Server**
```json
{
  "type": "chat",
  "roomId": "room-uuid",
  "payload": "Hello everyone!"
}
```

**Server → All Room Members**
```json
{
  "type": "chat",
  "roomId": "room-uuid",
  "from": "client-uuid",
  "payload": "Hello everyone!"
}
```

## Backend Architecture Overview

```
backend/
├── main.go                 // Entry point, HTTP server setup
├── server/
│   ├── server.go          // Server struct and initialization
│   ├── handlers.go        // HTTP/WebSocket handlers
│   └── middleware.go      // CORS, logging, etc.
├── rooms/
│   ├── room.go            // Room entity and methods
│   ├── manager.go         // Room lifecycle management
│   └── repository.go      // Room storage operations
├── clients/
│   ├── client.go          // Client entity and methods
│   ├── manager.go         // Client lifecycle management
│   └── registry.go        // Client lookup and storage
├── signaling/
│   ├── message.go         // Message structures
│   ├── router.go          // Message routing logic
│   └── handler.go         // Message handling
├── chat/
│   ├── message.go         // Chat message entity
│   └── store.go           // Message persistence
├── logger/
│   └── logger.go          // Centralized logging
└── config/
    └── config.go          // Configuration management
```

## Key Design Decisions

### 1. Room Isolation
- Messages are scoped to rooms
- Clients only see participants in their room
- Can't call someone in different room

### 2. Multiple Active Calls
- Each room member can have independent P2P calls with others
- 3 people in room = 3 potential simultaneous calls
- No server-side call management (server only routes signals)

### 3. Room Persistence
- Rooms auto-delete when last member leaves
- OR rooms persist for X minutes after becoming empty
- (Decision needed: Ephemeral vs. Persistent)

### 4. Room Discovery
- Option A: List all public rooms
- Option B: Join by room ID only (private by default)
- Option C: Hybrid (public & private rooms)

### 5. Error Handling
- If room doesn't exist → error
- If room is full → error
- If member disconnects → auto-remove from room
- If offer to non-existent member → error with routing

## Sequence Diagram: Multi-person Call in Room

```
Client A (room-1)    Server    Client B (room-1)    Client C (room-1)
    |                   |            |                      |
    |--- join-room ------|            |                      |
    |                   |--- broadcast member-joined ------->|
    |                   |--- broadcast member-joined ------->|
    |                   |            |                      |
    |                   |<------- broadcast member-joined ---|
    |<---- member-joined (B, C)------|                      |
    |                   |            |<--- broadcast --------|
    |                   |<------ broadcast member-joined ----|
    |                   |            |                      |
    |--- offer to B -----|            |                      |
    |                   |---- offer to B --->|               |
    |                   |            |                      |
    |                   |<---- answer to A --|               |
    |<--- answer --------|            |                      |
    |                   |            |                      |
    |=== P2P: A ↔ B ===|            |                      |
    |                   |            |                      |
    |--- offer to C -----|            |                      |
    |                   |---- offer to C -------->|           |
    |                   |            |           |           |
    |                   |<----- answer to A ------|           |
    |<--- answer --------|            |                      |
    |                   |            |                      |
    |=== P2P: A ↔ C ===|            |                      |
    |                   |            |                      |
```

## Backward Compatibility

### Migration Strategy (Optional)
1. Keep old "direct peer" mode for backward compatibility
2. Add new "room-based" mode
3. Send feature flag in `client-id` message
4. Clients choose which mode to use

### Message Format Considerations
```
Old message:
{
  "type": "offer",
  "to": "peer-id",
  "payload": {...}
}

New message (room-aware):
{
  "type": "offer",
  "roomId": "room-id",  // NEW
  "to": "peer-id",
  "payload": {...}
}
```

Server can handle both: if roomId present → route within room, else use old logic.

## Testing Scenarios

1. **Single room, 2 participants**: A and B join room, establish call
2. **Single room, 3+ participants**: A, B, C in room, A calls B and C separately
3. **Multiple rooms**: A in room-1, B in room-2, can't call each other
4. **Join/Leave**: A joins, B joins, A leaves, B still in room
5. **Room auto-cleanup**: All leave → room deleted
6. **Error cases**: Join non-existent room, call non-existent member, full room

## Future Enhancements

- [ ] Room permissions (mute others, remove participants)
- [ ] Room recording
- [ ] Persistent room history
- [ ] Room passwords
- [ ] Scheduled rooms
- [ ] Room analytics
- [ ] Call queuing in full rooms
