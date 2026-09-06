class SosAlert {
  const SosAlert({
    required this.id,
    required this.senderId,
    required this.circleId,
    required this.message,
    required this.status,
    required this.createdAt,
    this.latitude,
    this.longitude,
  });

  final String id;
  final String senderId;
  final String circleId;
  final String message;
  final String status;
  final DateTime createdAt;
  final double? latitude;
  final double? longitude;

  bool get isActive => status == 'active';

  factory SosAlert.fromJson(Map<String, dynamic> json) => SosAlert(
        id: json['id'] as String,
        senderId: json['sender_id'] as String,
        circleId: json['circle_id'] as String,
        message: (json['message'] as String?) ?? 'Emergency alert',
        status: (json['status'] as String?) ?? 'active',
        createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
        latitude: (json['lat'] as num?)?.toDouble(),
        longitude: (json['lng'] as num?)?.toDouble(),
      );
}