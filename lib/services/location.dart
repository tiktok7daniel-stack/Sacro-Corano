import 'package:geolocator/geolocator.dart';

class Place {
  const Place(this.nameAr, this.nameEn, this.lat, this.lng);
  final String nameAr;
  final String nameEn;
  final double lat;
  final double lng;
  String name(String lang) => lang == 'ar' ? nameAr : nameEn;
}

/// Offline city list for users who decline location access.
const cities = <Place>[
  Place('مكة المكرمة', 'Makkah', 21.4225, 39.8262),
  Place('المدينة المنورة', 'Madinah', 24.4672, 39.6111),
  Place('الرياض', 'Riyadh', 24.7136, 46.6753),
  Place('جدة', 'Jeddah', 21.4858, 39.1925),
  Place('القاهرة', 'Cairo', 30.0444, 31.2357),
  Place('الإسكندرية', 'Alexandria', 31.2001, 29.9187),
  Place('دبي', 'Dubai', 25.2048, 55.2708),
  Place('أبوظبي', 'Abu Dhabi', 24.4539, 54.3773),
  Place('الكويت', 'Kuwait City', 29.3759, 47.9774),
  Place('الدوحة', 'Doha', 25.2854, 51.5310),
  Place('المنامة', 'Manama', 26.2285, 50.5860),
  Place('مسقط', 'Muscat', 23.5880, 58.3829),
  Place('عمّان', 'Amman', 31.9454, 35.9284),
  Place('القدس', 'Jerusalem', 31.7767, 35.2345),
  Place('دمشق', 'Damascus', 33.5138, 36.2765),
  Place('بيروت', 'Beirut', 33.8938, 35.5018),
  Place('بغداد', 'Baghdad', 33.3152, 44.3661),
  Place('الخرطوم', 'Khartoum', 15.5007, 32.5599),
  Place('تونس', 'Tunis', 36.8065, 10.1815),
  Place('الجزائر', 'Algiers', 36.7538, 3.0588),
  Place('الدار البيضاء', 'Casablanca', 33.5731, -7.5898),
  Place('الرباط', 'Rabat', 34.0209, -6.8416),
  Place('طرابلس', 'Tripoli', 32.8872, 13.1913),
  Place('صنعاء', 'Sanaa', 15.3694, 44.1910),
  Place('إسطنبول', 'Istanbul', 41.0082, 28.9784),
  Place('كوالالمبور', 'Kuala Lumpur', 3.1390, 101.6869),
  Place('جاكرتا', 'Jakarta', -6.2088, 106.8456),
  Place('كراتشي', 'Karachi', 24.8607, 67.0011),
  Place('لاهور', 'Lahore', 31.5204, 74.3587),
  Place('دكا', 'Dhaka', 23.8103, 90.4125),
  Place('ميلانو', 'Milano', 45.4642, 9.1900),
  Place('روما', 'Roma', 41.9028, 12.4964),
  Place('لندن', 'London', 51.5072, -0.1276),
  Place('باريس', 'Paris', 48.8566, 2.3522),
  Place('برلين', 'Berlin', 52.5200, 13.4050),
  Place('مدريد', 'Madrid', 40.4168, -3.7038),
  Place('بروكسل', 'Brussels', 50.8503, 4.3517),
  Place('أمستردام', 'Amsterdam', 52.3676, 4.9041),
  Place('ستوكهولم', 'Stockholm', 59.3293, 18.0686),
  Place('نيويورك', 'New York', 40.7128, -74.0060),
  Place('تورونتو', 'Toronto', 43.6532, -79.3832),
  Place('سيدني', 'Sydney', -33.8688, 151.2093),
];

enum LocationFailure { serviceDisabled, denied, deniedForever, timeout }

class LocationResult {
  const LocationResult.ok(this.lat, this.lng) : failure = null;
  const LocationResult.fail(this.failure)
      : lat = null,
        lng = null;
  final double? lat;
  final double? lng;
  final LocationFailure? failure;
  bool get ok => failure == null;
}

/// Coarse location is enough for prayer times and qibla (±1 km).
class LocationService {
  static Future<LocationResult> current() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return const LocationResult.fail(LocationFailure.serviceDisabled);
    }
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
    if (perm == LocationPermission.denied) return const LocationResult.fail(LocationFailure.denied);
    if (perm == LocationPermission.deniedForever) return const LocationResult.fail(LocationFailure.deniedForever);
    try {
      final last = await Geolocator.getLastKnownPosition();
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.low, timeLimit: Duration(seconds: 15)),
      ).catchError((Object e) {
        if (last != null) return last;
        throw e;
      });
      return LocationResult.ok(pos.latitude, pos.longitude);
    } catch (_) {
      return const LocationResult.fail(LocationFailure.timeout);
    }
  }

  static Future<void> openSettings() => Geolocator.openAppSettings();

  /// Nearest city from the offline list, used as a readable place name.
  static Place nearestCity(double lat, double lng) {
    Place best = cities.first;
    var bestD = double.infinity;
    for (final c in cities) {
      final d = (c.lat - lat) * (c.lat - lat) + (c.lng - lng) * (c.lng - lng);
      if (d < bestD) {
        bestD = d;
        best = c;
      }
    }
    return best;
  }
}
