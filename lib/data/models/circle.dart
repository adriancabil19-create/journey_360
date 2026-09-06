import '../../core/utils/initials.dart';

/// A family / friend group for location sharing (MD section 14).
class Circle {
  const Circle({
    required this.id,
    required this.name,
    required this.inviteCode,
    this.memberCount = 1,
    this.ownerId,
    this.createdAt,
  });

  final String id;
  final String name;
  final String inviteCode;
  final int memberCount;
  final String? ownerId;
  final DateTime? createdAt;

  String get initials => initialsOf(name);

  factory Circle.fromJson(Map<String, dynamic> json) => Circle(
        id: json['id'] as String,
        name: json['name'] as String,
        inviteCode: (json['invite_code'] as String?) ?? '',
        memberCount: (json['member_count'] as num?)?.toInt() ?? 1,
        ownerId: json['owner_id'] as String?,
        createdAt:
            DateTime.tryParse(json['created_at'] as String? ?? '')?.toLocal(),
      );
}

/// A member row within a circle, including their last-known position.
class CircleMember {
  const CircleMember({
    required this.userId,
    required this.displayName,
    this.role = 'member',
    this.isSelf = false,
    this.latitude,
    this.longitude,
    this.batteryLevel,
    this.isSharing = false,
    this.lastSeenAt,
  });

  final String userId;
  final String displayName;
  final String role;
  final bool isSelf;
  final double? latitude;
  final double? longitude;
  final int? batteryLevel;
  final bool isSharing;
  final DateTime? lastSeenAt;

  String get initials => initialsOf(displayName);

  bool get isOnline {
    final t = lastSeenAt;
    if (t == null) return false;
    return DateTime.now().difference(t) < const Duration(minutes: 5);
  }

  factory CircleMember.fromJson(
    Map<String, dynamic> json, {
    String? selfId,
  }) {
    final userId = json['user_id'] as String;
    return CircleMember(
      userId: userId,
      displayName: (json['display_name'] as String?) ?? 'Member',
      role: (json['role'] as String?) ?? 'member',
      isSelf: selfId != null && selfId == userId,
      latitude: (json['current_lat'] as num?)?.toDouble(),
      longitude: (json['current_lng'] as num?)?.toDouble(),
      batteryLevel: (json['battery_level'] as num?)?.toInt(),
      isSharing: json['is_sharing_location'] as bool? ?? false,
      lastSeenAt:
          DateTime.tryParse(json['last_seen_at'] as String? ?? '')?.toLocal(),
    );
  }
}
