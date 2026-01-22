class SignalingMessage {
  final String type;
  final String? from;
  final String? to;
  final String? roomId;
  final dynamic payload;

  SignalingMessage({
    required this.type,
    this.from,
    this.to,
    this.roomId,
    this.payload,
  });

  factory SignalingMessage.fromJson(Map<String, dynamic> json) {
    return SignalingMessage(
      type: json['type'] as String,
      from: json['from'] as String?,
      to: json['to'] as String?,
      roomId: json['roomId'] as String?,
      payload: json['payload'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      if (from != null) 'from': from,
      if (to != null) 'to': to,
      if (roomId != null) 'roomId': roomId,
      if (payload != null) 'payload': payload,
    };
  }
}
