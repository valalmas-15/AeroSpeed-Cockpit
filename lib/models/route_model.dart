import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

enum ManeuverType {
  depart,
  turnLeft,
  turnRight,
  turnSlightLeft,
  turnSlightRight,
  straight,
  roundabout,
  uTurn,
  arrive;

  IconData get icon {
    switch (this) {
      case ManeuverType.depart:
        return Icons.navigation;
      case ManeuverType.turnLeft:
        return Icons.turn_left;
      case ManeuverType.turnRight:
        return Icons.turn_right;
      case ManeuverType.turnSlightLeft:
        return Icons.turn_slight_left;
      case ManeuverType.turnSlightRight:
        return Icons.turn_slight_right;
      case ManeuverType.straight:
        return Icons.straight;
      case ManeuverType.roundabout:
        return Icons.roundabout_right;
      case ManeuverType.uTurn:
        return Icons.u_turn_left;
      case ManeuverType.arrive:
        return Icons.flag;
    }
  }
}

class RouteStep {
  final String instruction;
  final String streetName;
  final double distanceMeters;
  final double durationSeconds;
  final ManeuverType maneuver;
  final LatLng point;

  const RouteStep({
    required this.instruction,
    required this.streetName,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.maneuver,
    required this.point,
  });

  String get formattedDistance {
    if (distanceMeters >= 1000) {
      return '${(distanceMeters / 1000).toStringAsFixed(1)} km';
    }
    return '${distanceMeters.toStringAsFixed(0)} m';
  }
}

class NavigationRoute {
  final String originName;
  final String destinationName;
  final LatLng? originPoint;
  final LatLng? destinationPoint;
  final List<LatLng> polylinePoints;
  final List<RouteStep> steps;
  final double totalDistanceMeters;
  final double totalDurationSeconds;
  final int currentStepIndex;

  const NavigationRoute({
    required this.originName,
    required this.destinationName,
    this.originPoint,
    this.destinationPoint,
    required this.polylinePoints,
    required this.steps,
    required this.totalDistanceMeters,
    required this.totalDurationSeconds,
    this.currentStepIndex = 0,
  });

  double get totalDistanceKm => totalDistanceMeters / 1000;
  int get totalMinutes => (totalDurationSeconds / 60).round();

  RouteStep? get currentStep {
    if (steps.isEmpty) return null;
    if (currentStepIndex >= 0 && currentStepIndex < steps.length) {
      return steps[currentStepIndex];
    }
    return steps.first;
  }

  String get formattedRemainingDistance {
    if (totalDistanceMeters >= 1000) {
      return '${totalDistanceKm.toStringAsFixed(1)} km';
    }
    return '${totalDistanceMeters.toStringAsFixed(0)} m';
  }

  String get formattedDuration {
    if (totalMinutes >= 60) {
      final hours = totalMinutes ~/ 60;
      final mins = totalMinutes % 60;
      return '${hours}h ${mins}m';
    }
    return '$totalMinutes min';
  }

  String get formattedEta {
    final now = DateTime.now();
    final arrival = now.add(Duration(seconds: totalDurationSeconds.round()));
    final hourStr = arrival.hour.toString().padLeft(2, '0');
    final minStr = arrival.minute.toString().padLeft(2, '0');
    return '$hourStr:$minStr';
  }

  NavigationRoute copyWith({
    String? originName,
    String? destinationName,
    LatLng? originPoint,
    LatLng? destinationPoint,
    List<LatLng>? polylinePoints,
    List<RouteStep>? steps,
    double? totalDistanceMeters,
    double? totalDurationSeconds,
    int? currentStepIndex,
  }) {
    return NavigationRoute(
      originName: originName ?? this.originName,
      destinationName: destinationName ?? this.destinationName,
      originPoint: originPoint ?? this.originPoint,
      destinationPoint: destinationPoint ?? this.destinationPoint,
      polylinePoints: polylinePoints ?? this.polylinePoints,
      steps: steps ?? this.steps,
      totalDistanceMeters: totalDistanceMeters ?? this.totalDistanceMeters,
      totalDurationSeconds: totalDurationSeconds ?? this.totalDurationSeconds,
      currentStepIndex: currentStepIndex ?? this.currentStepIndex,
    );
  }
}
