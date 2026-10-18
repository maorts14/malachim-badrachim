import 'package:rescue_app/models/message_sender.dart';

class Message {
  final int id;
  final MessageSender sender;
  final String title;
  final String text;
  final String? voiceFile;
  final String? voiceUrl;
  final double? latitude;
  final double? longitude;
  final int? alertId;
  final int? groupId;
  final DateTime timestamp;

  const Message({
    required this.id,
    required this.sender,
    required this.title,
    required this.text,
    this.voiceFile,
    this.voiceUrl,
    this.latitude,
    this.longitude,
    this.alertId,
    this.groupId,
    required this.timestamp,
  });

  factory Message.empty() {
    return Message(
      id: 0,
      sender: const MessageSender(
        id: 0,
        username: '',
        email: '',
        role: '',
      ),
      title: '',
      text: '',
      voiceFile: null,
      voiceUrl: null,
      latitude: null,
      longitude: null,
      timestamp: DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'] as int,
      sender: MessageSender.fromJson(json['sender'] as Map<String, dynamic>),
      title: json['title'] as String,
      text: json['text'] as String,
      voiceFile: json['voice_file'] as String?,
      voiceUrl: json['voice_url'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      alertId: json['alert'] as int?,
      groupId: json['group'] as int?,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sender': sender.toJson(),
      'title': title,
      'text': text,
      'voice_file': voiceFile,
      'voice_url': voiceUrl,
      'latitude': latitude,
      'longitude': longitude,
      'alert': alertId,
      'group': groupId,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}
