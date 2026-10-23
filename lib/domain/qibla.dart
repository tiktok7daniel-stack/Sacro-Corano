import 'dart:math' as math;

/// Kaaba coordinates (Masjid al-Haram).
const kaabaLat = 21.422487;
const kaabaLng = 39.826206;

double _rad(double d) => d * math.pi / 180;
double _deg(double r) => r * 180 / math.pi;

/// Initial great-circle bearing from (lat, lng) to the Kaaba, in degrees
/// clockwise from true north (0..360).
double qiblaBearing(double lat, double lng) {
  final phi1 = _rad(lat);
  final phi2 = _rad(kaabaLat);
  final dLambda = _rad(kaabaLng - lng);
  final y = math.sin(dLambda);
  final x = math.cos(phi1) * math.tan(phi2) - math.sin(phi1) * math.cos(dLambda);
  return (_deg(math.atan2(y, x)) + 360) % 360;
}

/// Great-circle distance in kilometres (haversine).
double distanceKm(double lat1, double lng1, double lat2, double lng2) {
  const r = 6371.0088;
  final dPhi = _rad(lat2 - lat1);
  final dLambda = _rad(lng2 - lng1);
  final a = math.pow(math.sin(dPhi / 2), 2) +
      math.cos(_rad(lat1)) * math.cos(_rad(lat2)) * math.pow(math.sin(dLambda / 2), 2);
  return 2 * r * math.asin(math.sqrt(a));
}

double distanceToKaabaKm(double lat, double lng) => distanceKm(lat, lng, kaabaLat, kaabaLng);

/// Smallest signed angle (degrees, -180..180) to rotate [from] onto [to].
double angleDelta(double from, double to) {
  var d = (to - from) % 360;
  if (d > 180) d -= 360;
  if (d < -180) d += 360;
  return d;
}

/// Exponential smoothing on a circle, avoiding the 359°→0° jump.
double smoothHeading(double previous, double next, {double factor = 0.15}) =>
    (previous + angleDelta(previous, next) * factor + 360) % 360;
