enum SpeedUnit { kmh, mph }

class SpeedData {
  final double currentSpeed; // Always stored in km/h internally
  final double maxSpeed;
  final double avgSpeed;
  final double totalDistanceKm;
  final Duration tripDuration;
  final double speedLimit; // e.g. 100 km/h
  final double altitude; // Altitude above sea level in meters
  final double totalAscentMeters; // Cumulative elevation gain
  final double totalDescentMeters; // Cumulative elevation loss
  final double heading; // Degrees 0-360
  final double accuracy; // Meters
  final SpeedUnit unit;
  final bool isGpsActive;

  const SpeedData({
    this.currentSpeed = 0.0,
    this.maxSpeed = 0.0,
    this.avgSpeed = 0.0,
    this.totalDistanceKm = 0.0,
    this.tripDuration = Duration.zero,
    this.speedLimit = 60.0,
    this.altitude = 0.0,
    this.totalAscentMeters = 0.0,
    this.totalDescentMeters = 0.0,
    this.heading = 0.0,
    this.accuracy = 0.0,
    this.unit = SpeedUnit.kmh,
    this.isGpsActive = false,
  });

  // Display speed according to selected unit
  double get displaySpeed {
    if (unit == SpeedUnit.mph) {
      return currentSpeed * 0.621371;
    }
    return currentSpeed;
  }

  double get displayMaxSpeed {
    if (unit == SpeedUnit.mph) {
      return maxSpeed * 0.621371;
    }
    return maxSpeed;
  }

  double get displayAvgSpeed {
    if (unit == SpeedUnit.mph) {
      return avgSpeed * 0.621371;
    }
    return avgSpeed;
  }

  double get displayDistance {
    if (unit == SpeedUnit.mph) {
      return totalDistanceKm * 0.621371;
    }
    return totalDistanceKm;
  }

  // Elevation, Total Ascent & Total Descent (meters in metric, feet in imperial)
  double get displayElevation {
    if (unit == SpeedUnit.mph) {
      return altitude * 3.28084;
    }
    return altitude;
  }

  double get displayAscent {
    if (unit == SpeedUnit.mph) {
      return totalAscentMeters * 3.28084;
    }
    return totalAscentMeters;
  }

  double get displayDescent {
    if (unit == SpeedUnit.mph) {
      return totalDescentMeters * 3.28084;
    }
    return totalDescentMeters;
  }

  String get unitLabel => unit == SpeedUnit.kmh ? 'KM/H' : 'MPH';
  String get distanceLabel => unit == SpeedUnit.kmh ? 'km' : 'mi';
  String get elevationUnitLabel => unit == SpeedUnit.mph ? 'ft' : 'm';

  bool get isSpeedLimitExceeded => currentSpeed > speedLimit;

  SpeedData copyWith({
    double? currentSpeed,
    double? maxSpeed,
    double? avgSpeed,
    double? totalDistanceKm,
    Duration? tripDuration,
    double? speedLimit,
    double? altitude,
    double? totalAscentMeters,
    double? totalDescentMeters,
    double? heading,
    double? accuracy,
    SpeedUnit? unit,
    bool? isGpsActive,
  }) {
    return SpeedData(
      currentSpeed: currentSpeed ?? this.currentSpeed,
      maxSpeed: maxSpeed ?? this.maxSpeed,
      avgSpeed: avgSpeed ?? this.avgSpeed,
      totalDistanceKm: totalDistanceKm ?? this.totalDistanceKm,
      tripDuration: tripDuration ?? this.tripDuration,
      speedLimit: speedLimit ?? this.speedLimit,
      altitude: altitude ?? this.altitude,
      totalAscentMeters: totalAscentMeters ?? this.totalAscentMeters,
      totalDescentMeters: totalDescentMeters ?? this.totalDescentMeters,
      heading: heading ?? this.heading,
      accuracy: accuracy ?? this.accuracy,
      unit: unit ?? this.unit,
      isGpsActive: isGpsActive ?? this.isGpsActive,
    );
  }
}
