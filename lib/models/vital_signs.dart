import 'package:flutter/material.dart';

enum HeartRateZone {
  resting,
  fatBurn,
  cardio,
  peak;

  String get label {
    switch (this) {
      case HeartRateZone.resting:
        return 'WARM UP';
      case HeartRateZone.fatBurn:
        return 'FAT BURN';
      case HeartRateZone.cardio:
        return 'CARDIO';
      case HeartRateZone.peak:
        return 'PEAK / ANAEROBIC';
    }
  }

  Color get color => zoneColor(false);

  Color zoneColor(bool isFun) {
    if (!isFun) {
      switch (this) {
        case HeartRateZone.resting:
          return const Color(0xFFCBD5E1);
        case HeartRateZone.fatBurn:
          return const Color(0xFFE2E8F0);
        case HeartRateZone.cardio:
          return const Color(0xFFFFFFFF);
        case HeartRateZone.peak:
          return const Color(0xFFEF4444);
      }
    }
    switch (this) {
      case HeartRateZone.resting:
        return const Color(0xFF00E5FF); // Cool Cyan (Warm Up)
      case HeartRateZone.fatBurn:
        return const Color(0xFF10B981); // Emerald Green (Fat Burn)
      case HeartRateZone.cardio:
        return const Color(0xFFF59E0B); // Amber Gold (Cardio)
      case HeartRateZone.peak:
        return const Color(0xFFEF4444); // Crimson Red (Peak / Anaerobic)
    }
  }
}

class HeartRateDataPoint {
  final DateTime timestamp;
  final int bpm;

  HeartRateDataPoint({required this.timestamp, required this.bpm});
}

class VitalSigns {
  final int heartRate; // Current BPM
  final int minHeartRate;
  final int maxHeartRate;
  final int avgHeartRate;
  final double caloriesBurned; // kcal
  final double burnRatePerHour; // kcal/h
  final bool isConnected;
  final String deviceName;
  final int batteryLevel; // 0 - 100%
  final List<HeartRateDataPoint> history;

  const VitalSigns({
    this.heartRate = 0,
    this.minHeartRate = 0,
    this.maxHeartRate = 0,
    this.avgHeartRate = 0,
    this.caloriesBurned = 0.0,
    this.burnRatePerHour = 0.0,
    this.isConnected = false,
    this.deviceName = 'Amazfit Active 2',
    this.batteryLevel = 85,
    this.history = const [],
  });

  HeartRateZone get zone {
    if (heartRate < 100) return HeartRateZone.resting;
    if (heartRate < 130) return HeartRateZone.fatBurn;
    if (heartRate < 160) return HeartRateZone.cardio;
    return HeartRateZone.peak;
  }

  VitalSigns copyWith({
    int? heartRate,
    int? minHeartRate,
    int? maxHeartRate,
    int? avgHeartRate,
    double? caloriesBurned,
    double? burnRatePerHour,
    bool? isConnected,
    String? deviceName,
    int? batteryLevel,
    List<HeartRateDataPoint>? history,
  }) {
    return VitalSigns(
      heartRate: heartRate ?? this.heartRate,
      minHeartRate: minHeartRate ?? this.minHeartRate,
      maxHeartRate: maxHeartRate ?? this.maxHeartRate,
      avgHeartRate: avgHeartRate ?? this.avgHeartRate,
      caloriesBurned: caloriesBurned ?? this.caloriesBurned,
      burnRatePerHour: burnRatePerHour ?? this.burnRatePerHour,
      isConnected: isConnected ?? this.isConnected,
      deviceName: deviceName ?? this.deviceName,
      batteryLevel: batteryLevel ?? this.batteryLevel,
      history: history ?? this.history,
    );
  }
}
