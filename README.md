# Video Call App

Simple peer-to-peer video call application built with Flutter (frontend) and Go (backend).

## Prerequisites

- **Frontend**: Flutter SDK
- **Backend**: Go 1.16+

## Project Structure

```
├── frontend/      # Flutter web/mobile app
├── backend/       # Go WebSocket signaling server
└── README.md
```

## Getting Started

### Backend

1. Navigate to the backend directory:
   ```bash
   cd backend
   ```

2. Run the server:
   ```bash
   go run main.go
   ```

The server will start on `0.0.0.0:8081` and handle WebSocket connections at `ws://localhost:8081/ws`.

### Frontend

1. Navigate to the frontend directory:
   ```bash
   cd frontend
   ```

2. Get dependencies:
   ```bash
   flutter pub get
   ```

3. Run on web:
   ```bash
   flutter run -d chrome
   ```

Or run on mobile:
   ```bash
   flutter run -d ios
   # or
   flutter run -d android
   ```

## How It Works

1. Two clients connect to the signaling server
2. Exchange offer/answer via WebSocket
3. Exchange ICE candidates
4. Establish P2P WebRTC connection
5. Stream audio/video directly between peers

## Features

- Peer-to-peer video calling
- Real-time chat
- Automatic peer discovery
- ICE candidate buffering
