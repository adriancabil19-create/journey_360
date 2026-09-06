/// Formatting helpers for distances, durations, pace and speed.
class Fmt {
  const Fmt._();

  /// Metres -> "5.42 km" (or "820 m" under 1 km).
  static String distance(double metres) {
    if (metres < 1000) return '${metres.round()} m';
    return '${(metres / 1000).toStringAsFixed(2)} km';
  }

  /// Metres -> "5.42" (kilometres, no unit).
  static String km(double metres) => (metres / 1000).toStringAsFixed(2);

  /// Seconds -> "32:18" or "1:04:11".
  static String duration(int seconds) {
    final d = Duration(seconds: seconds);
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    final mm = m.toString().padLeft(2, '0');
    final ss = s.toString().padLeft(2, '0');
    return h > 0 ? '$h:$mm:$ss' : '$mm:$ss';
  }

  /// Seconds -> "38 min" / "3h 21m" for compact summaries.
  static String durationShort(int seconds) {
    final d = Duration(seconds: seconds);
    if (d.inHours > 0) return '${d.inHours}h ${d.inMinutes.remainder(60)}m';
    return '${d.inMinutes} min';
  }

  /// Metres/second -> "5:57 /km". Returns "--:-- /km" when not moving.
  static String pace(double metresPerSecond) {
    if (metresPerSecond <= 0.1) return "--'-- /km";
    final secondsPerKm = 1000 / metresPerSecond;
    final m = secondsPerKm ~/ 60;
    final s = (secondsPerKm % 60).round();
    return "$m'${s.toString().padLeft(2, '0')} /km";
  }

  /// Seconds-per-kilometre -> "5:57 /km".
  static String paceFromSeconds(double secondsPerKm) {
    if (secondsPerKm <= 0) return "--'-- /km";
    final m = secondsPerKm ~/ 60;
    final s = (secondsPerKm % 60).round();
    return "$m'${s.toString().padLeft(2, '0')} /km";
  }

  /// Metres/second -> "8.2 km/h".
  static String speed(double metresPerSecond) {
    final kmh = metresPerSecond * 3.6;
    return '${kmh.toStringAsFixed(1)} km/h';
  }

  /// A relative "8 sec ago" / "3 min ago" / "2 h ago" label.
  static String ago(DateTime? time) {
    if (time == null) return 'unknown';
    final diff = DateTime.now().difference(time);
    if (diff.inSeconds < 60) return '${diff.inSeconds} sec ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} h ago';
    return '${diff.inDays} d ago';
  }
}
