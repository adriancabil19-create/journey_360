/// A saved place with a geofence radius (MD section 16).
class Place {
  const Place({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.radiusMeters = 150,
  });

  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final double radiusMeters;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'lat': latitude,
        'lng': longitude,
        'radius_m': radiusMeters,
      };

  factory Place.fromJson(Map<String, dynamic> json) => Place(
        id: json['id'] as String,
        name: json['name'] as String,
        latitude: (json['lat'] as num).toDouble(),
        longitude: (json['lng'] as num).toDouble(),
        radiusMeters: (json['radius_m'] as num?)?.toDouble() ?? 150,
      );
}
