export type ClientMessage =
  | JoinRoomMessage
  | ChatMessage;

export type ServerMessage =
  | JoinedMessage
  | ErrorMessage
  | ChatMessage;
  
export interface JoinRoomMessage {
  type: "join";
  clientId: string;
  roomId: string;
}

export interface JoinedMessage {
  type: "joined";
  roomId: string;
}

export interface ErrorMessage {
  type: "error";
  payload: string;  // в Go отправляется payload, а не reason
}

export interface ChatMessage {
  type: "chat";
  from: string;
  payload: string | object;  // может быть строка или JSON объект
}