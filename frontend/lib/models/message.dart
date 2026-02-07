import 'dart:convert';

class Message {
  final String type;
  final String from;
  final String? to;
  final Map<String, dynamic> payload;

  Message({
    required this.type,
    required this.from,
    this.to,
    required this.payload,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      type: json['type'] as String,
      from: json['from'] as String,
      to: json['to'] as String?,
      payload: json['payload'] is String
          ? jsonDecode(json['payload'])
          : json['payload'],
    );
  }
  
  Map<String, dynamic> toJson() {
     return {
       'type': type,
       'from': from,
       if (to != null) 'to': to,
       'payload': payload,
     };
   }

   @override
   String toString() => 'Message(type: $type, from: $from, payload: $payload)';

}
