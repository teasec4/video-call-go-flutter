// union types
export type ClientMessage =
  | JoinMessage
  | ChatMessage
  | OfferMessage
  | AnswerMessage
  | IceCandidateMessage;

export type ServerMessage =
  | JoinedMessage
  | ErrorMessage
  | ChatMessage
  | OfferMessage
  | AnswerMessage
  | IceCandidateMessage;

export type WSMessageType =
  | "join"
  | "joined"
  | "error"
  | "chat"
  | "offer"
  | "answer"
  | "ice_candidate"
  | "user-left";
  
export interface ServerReqCreateRoom{
  type: "create",
  payload: {
    roomId: string,
    clientId: string,
  }
}

export interface ServerReqJoinRoom{
  type: "join",
  payload: {
    roomId: string,
    clientId: string,
  }
}

export interface ServerResRoomCreated{
  type: "created",
  payload: {
    roomId: string,
  }
}

export interface WSPayload {
  from: string;
  to: string;
  data: Record<string, string>; // строго string!
}

export interface WSMessage {
  type: WSMessageType;
  payload: WSPayload;
}

export interface JoinMessage {
  type: "join";
  payload: {
    from: string; // clientId
    to: string;   // обычно ""
    data: {
      roomId: string;
    };
  };
}

export interface JoinedMessage {
  type: "joined";
  payload: {
    from: "server";
    to: string; // clientId
    data: {
      type: string; // сейчас сервер отправляет { type: "joined" }
    };
  };
}

export interface ErrorMessage {
  type: "error";
  payload: {
    from: "server";
    to: string;
    data: {
      error: string;
    };
  };
}

export interface ChatMessage {
  type: "chat";
  payload: {
    from: string;
    to: string;
    data: {
      msg: string;
    };
  };
}


// offer answer ice 
export interface OfferMessage {
  type: "offer";
  payload: {
    from: string;
    to: string;
    data: {
      sdp: string; // сериализованный SDP
    };
  };
}

export interface AnswerMessage {
  type: "answer";
  payload: {
    from: string;
    to: string;
    data: {
      sdp: string;
    };
  };
}

export interface IceCandidateMessage {
  type: "ice_candidate";
  payload: {
    from: string;
    to: string;
    data: {
      candidate: string;
      sdpMid: string;
      sdpMLineIndex: string; // строка, не number!
    };
  };
}