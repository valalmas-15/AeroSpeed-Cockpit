import 'dart:convert';
import 'package:latlong2/latlong.dart';
import 'speed_data.dart';

enum SessionStatus {
  idle, // Sesi belum dimulai
  running, // Sesi sedang berjalan dan merekam data
  paused, // Sesi sedang dijeda (perekaman data berhenti)
}

/// Model data lengkap untuk satu sesi latihan / berkendara yang disimpan
class WorkoutSession {
  final String id;
  final DateTime startTime;
  final DateTime endTime;
  final Duration duration;
  final double totalDistanceKm;
  final double avgSpeedKmh;
  final double maxSpeedKmh;
  final double totalAscentMeters;
  final double totalDescentMeters;
  final double calories;
  final SpeedUnit speedUnit;

  // Data Navigasi & Lokasi
  final String routeName;
  final String? startLocation;
  final String? destinationLocation;
  final List<LatLng> routePoints;
  final String? routeThumbnailPath;

  // Data Tanda Vital (Amazfit / BLE)
  final int avgHeartRate;
  final int maxHeartRate;
  final int minHeartRate;
  final int lastStress;
  final int lastSpo2;
  final bool wasWatchConnected;

  const WorkoutSession({
    required this.id,
    required this.startTime,
    required this.endTime,
    required this.duration,
    required this.totalDistanceKm,
    required this.avgSpeedKmh,
    required this.maxSpeedKmh,
    required this.totalAscentMeters,
    required this.totalDescentMeters,
    required this.calories,
    this.speedUnit = SpeedUnit.kmh,
    required this.routeName,
    this.startLocation,
    this.destinationLocation,
    this.routePoints = const [],
    this.routeThumbnailPath,
    required this.avgHeartRate,
    required this.maxHeartRate,
    required this.minHeartRate,
    required this.lastStress,
    required this.lastSpo2,
    required this.wasWatchConnected,
  });

  bool get hasRoute => routePoints.isNotEmpty;

  // Display formats
  double get displayDistance =>
      speedUnit == SpeedUnit.mph ? totalDistanceKm * 0.621371 : totalDistanceKm;

  double get displayAvgSpeed =>
      speedUnit == SpeedUnit.mph ? avgSpeedKmh * 0.621371 : avgSpeedKmh;

  double get displayMaxSpeed =>
      speedUnit == SpeedUnit.mph ? maxSpeedKmh * 0.621371 : maxSpeedKmh;

  double get displayAscent =>
      speedUnit == SpeedUnit.mph ? totalAscentMeters * 3.28084 : totalAscentMeters;

  double get displayDescent =>
      speedUnit == SpeedUnit.mph ? totalDescentMeters * 3.28084 : totalDescentMeters;

  String get distanceUnitLabel => speedUnit == SpeedUnit.kmh ? 'km' : 'mi';
  String get speedUnitLabel => speedUnit == SpeedUnit.kmh ? 'KM/H' : 'MPH';
  String get elevationUnitLabel => speedUnit == SpeedUnit.mph ? 'ft' : 'm';

  String get formattedDuration {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;

    if (hours > 0) {
      return '${hours}j ${minutes.toString().padLeft(2, '0')}m ${seconds.toString().padLeft(2, '0')}s';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'startTime': startTime.millisecondsSinceEpoch,
      'endTime': endTime.millisecondsSinceEpoch,
      'durationSeconds': duration.inSeconds,
      'totalDistanceKm': totalDistanceKm,
      'avgSpeedKmh': avgSpeedKmh,
      'maxSpeedKmh': maxSpeedKmh,
      'totalAscentMeters': totalAscentMeters,
      'totalDescentMeters': totalDescentMeters,
      'calories': calories,
      'speedUnit': speedUnit == SpeedUnit.mph ? 'mph' : 'kmh',
      'routeName': routeName,
      'startLocation': startLocation,
      'destinationLocation': destinationLocation,
      'routePoints': routePoints.map((p) => [p.latitude, p.longitude]).toList(),
      'routeThumbnailPath': routeThumbnailPath,
      'avgHeartRate': avgHeartRate,
      'maxHeartRate': maxHeartRate,
      'minHeartRate': minHeartRate,
      'lastStress': lastStress,
      'lastSpo2': lastSpo2,
      'wasWatchConnected': wasWatchConnected,
    };
  }

  factory WorkoutSession.fromMap(Map<String, dynamic> map) {
    return WorkoutSession(
      id: map['id'] as String? ?? DateTime.now().millisecondsSinceEpoch.toString(),
      startTime: DateTime.fromMillisecondsSinceEpoch(map['startTime'] as int? ?? 0),
      endTime: DateTime.fromMillisecondsSinceEpoch(map['endTime'] as int? ?? 0),
      duration: Duration(seconds: map['durationSeconds'] as int? ?? 0),
      totalDistanceKm: (map['totalDistanceKm'] as num?)?.toDouble() ?? 0.0,
      avgSpeedKmh: (map['avgSpeedKmh'] as num?)?.toDouble() ?? 0.0,
      maxSpeedKmh: (map['maxSpeedKmh'] as num?)?.toDouble() ?? 0.0,
      totalAscentMeters: (map['totalAscentMeters'] as num?)?.toDouble() ?? 0.0,
      totalDescentMeters: (map['totalDescentMeters'] as num?)?.toDouble() ?? 0.0,
      calories: (map['calories'] as num?)?.toDouble() ?? 0.0,
      speedUnit: map['speedUnit'] == 'mph' ? SpeedUnit.mph : SpeedUnit.kmh,
      routeName: map['routeName'] as String? ?? 'Berkendara Bebas',
      startLocation: map['startLocation'] as String?,
      destinationLocation: map['destinationLocation'] as String?,
      routePoints: (map['routePoints'] as List<dynamic>?)
              ?.map((pt) {
                if (pt is List && pt.length >= 2) {
                  return LatLng(
                    (pt[0] as num).toDouble(),
                    (pt[1] as num).toDouble(),
                  );
                } else if (pt is Map) {
                  return LatLng(
                    (pt['lat'] as num).toDouble(),
                    (pt['lng'] as num).toDouble(),
                  );
                }
                return null;
              })
              .whereType<LatLng>()
              .toList() ??
          const [],
      routeThumbnailPath: map['routeThumbnailPath'] as String?,
      avgHeartRate: map['avgHeartRate'] as int? ?? 0,
      maxHeartRate: map['maxHeartRate'] as int? ?? 0,
      minHeartRate: map['minHeartRate'] as int? ?? 0,
      lastStress: map['lastStress'] as int? ?? 0,
      lastSpo2: map['lastSpo2'] as int? ?? 0,
      wasWatchConnected: map['wasWatchConnected'] as bool? ?? false,
    );
  }

  String toJson() => json.encode(toMap());

  factory WorkoutSession.fromJson(String source) =>
      WorkoutSession.fromMap(json.decode(source) as Map<String, dynamic>);
}

