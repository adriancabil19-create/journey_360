/// One kilometre split of a journey.
class Split {
  const Split({
    required this.index,
    required this.distanceMeters,
    required this.seconds,
  });

  /// 1-based kilometre number.
  final int index;
  final double distanceMeters;
  final int seconds;

  /// Seconds per kilometre for this split.
  double get paceSecondsPerKm =>
      distanceMeters > 0 ? seconds / (distanceMeters / 1000) : 0;

  /// Metres per second across this split.
  double get speed => seconds > 0 ? distanceMeters / seconds : 0;

  Map<String, dynamic> toJson() => {
        'index': index,
        'distance_m': distanceMeters,
        'seconds': seconds,
      };

  factory Split.fromJson(Map<String, dynamic> json) => Split(
        index: (json['index'] as num).toInt(),
        distanceMeters: (json['distance_m'] as num).toDouble(),
        seconds: (json['seconds'] as num).toInt(),
      );
}
