import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../models/speed_data.dart';

class GpsSpeedService {
  final _speedDataController = StreamController<SpeedData>.broadcast();
  Stream<SpeedData> get speedStream => _speedDataController.stream;

  final _positionController = StreamController<LatLng>.broadcast();
  Stream<LatLng> get positionStream => _positionController.stream;

  SpeedData _currentSpeedData = const SpeedData();
  SpeedData get currentSpeedData => _currentSpeedData;

  StreamSubscription<Position>? _positionSubscription;
  static const EventChannel _compassEventChannel = EventChannel('com.speedometer.app/compass');
  StreamSubscription? _compassSubscription;

  Position? _lastPosition;
  Position? _bearingAnchorPosition;
  DateTime? _lastPositionTime;
  DateTime? _tripStartTime;
  Timer? _tripTimer;

  // Smoothing filter
  double _filteredSpeed = 0.0;

  // Elevation, Total Ascent & Total Descent tracking
  double _totalAscentMeters = 0.0;
  double _totalDescentMeters = 0.0;
  double _lastAltitude = 0.0;

  // Simulation mode
  bool _isSimulationMode = false;
  Timer? _simDriveTimer;
  int _simIndex = 0;
  List<LatLng> _simRoute = [];
  double _simTargetSpeed = 0.0;

  GpsSpeedService() {
    _startTripTimer();
  }

  void _startTripTimer() {
    _tripTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_tripStartTime != null) {
        final duration = DateTime.now().difference(_tripStartTime!);
        _updateSpeedData(_currentSpeedData.copyWith(tripDuration: duration));
      }
    });
  }

  // Request permissions and start live GPS tracking
  Future<bool> startGpsTracking() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint("Location services are disabled.");
        return false;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint("Location permissions are denied.");
          return false;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint("Location permissions are permanently denied.");
        return false;
      }

      _tripStartTime ??= DateTime.now();

      // High-Frequency Realtime Settings for Android Cockpit (150ms interval, 0m filter)
      late LocationSettings locationSettings;
      if (defaultTargetPlatform == TargetPlatform.android) {
        locationSettings = AndroidSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          distanceFilter: 0, // Never throttle or skip when stationary/turning
          intervalDuration: const Duration(milliseconds: 150), // Ultra-fast ~6.6 updates/sec
          forceLocationManager: false,
        );
      } else {
        locationSettings = const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          distanceFilter: 0,
        );
      }

      _positionSubscription?.cancel();
      _positionSubscription = Geolocator.getPositionStream(
        locationSettings: locationSettings,
      ).listen(_handlePositionUpdate);

      // Start native hardware compass stream (instantaneous 40 FPS orientation)
      if (defaultTargetPlatform == TargetPlatform.android) {
        _compassSubscription?.cancel();
        try {
          _compassSubscription = _compassEventChannel.receiveBroadcastStream().listen(
            (dynamic event) {
              if (_isSimulationMode) return;
              if (event is num) {
                final compassHeading = event.toDouble();
                // When moving slowly or stationary, hardware compass gives instant real-time rotation
                if (_filteredSpeed < 2.0) {
                  _updateSpeedData(_currentSpeedData.copyWith(heading: compassHeading));
                }
              }
            },
            onError: (err) => debugPrint("Compass channel error: $err"),
          );
        } catch (_) {}
      }

      _updateSpeedData(_currentSpeedData.copyWith(isGpsActive: true));
      return true;
    } catch (e) {
      debugPrint("Error initializing GPS: $e");
      return false;
    }
  }

  void stopGpsTracking() {
    _positionSubscription?.cancel();
    _positionSubscription = null;
    _compassSubscription?.cancel();
    _compassSubscription = null;
    _updateSpeedData(_currentSpeedData.copyWith(isGpsActive: false));
  }

  void _handlePositionUpdate(Position position) {
    if (_isSimulationMode) return;

    // 1. Raw speed from GPS satellite Doppler (m/s to km/h)
    double rawSpeedKmh = position.speed >= 0 ? position.speed * 3.6 : 0.0;

    // Fallback: If hardware reports 0 km/h but coordinates are physically advancing,
    // compute speed from distance/time delta so speedometer never gets stuck
    final now = DateTime.now();
    if (_lastPosition != null && _lastPositionTime != null) {
      final dtSeconds = now.difference(_lastPositionTime!).inMilliseconds / 1000.0;
      if (dtSeconds > 0.15 && dtSeconds < 2.5) {
        final dMeters = Geolocator.distanceBetween(
          _lastPosition!.latitude,
          _lastPosition!.longitude,
          position.latitude,
          position.longitude,
        );
        if (rawSpeedKmh < 0.6 && dMeters > 0.4) {
          final computedSpeedKmh = (dMeters / dtSeconds) * 3.6;
          if (computedSpeedKmh < 180.0) {
            rawSpeedKmh = computedSpeedKmh;
          }
        }
      }
    }
    _lastPositionTime = now;

    // Suppress tiny sensor noise/drift when completely stopped
    if (rawSpeedKmh < 0.8) rawSpeedKmh = 0.0;

    // 2. Ultra-responsive speed filter (immediate reaction to acceleration/deceleration)
    final double alpha = rawSpeedKmh == 0.0 ? 0.90 : 0.70;
    _filteredSpeed = (alpha * rawSpeedKmh) + ((1.0 - alpha) * _filteredSpeed);
    if (_filteredSpeed < 0.5) _filteredSpeed = 0.0;

    // 3. Distance calculation
    double distanceDeltaKm = 0.0;
    if (_lastPosition != null) {
      final meters = Geolocator.distanceBetween(
        _lastPosition!.latitude,
        _lastPosition!.longitude,
        position.latitude,
        position.longitude,
      );
      if (meters < 300) {
        distanceDeltaKm = meters / 1000.0;
      }
    }

    // 4. Real-time Movement Heading (Course-Over-Ground)
    double calculatedHeading = _currentSpeedData.heading;
    _bearingAnchorPosition ??= _lastPosition ?? position;
    final anchorMeters = Geolocator.distanceBetween(
      _bearingAnchorPosition!.latitude,
      _bearingAnchorPosition!.longitude,
      position.latitude,
      position.longitude,
    );

    // As soon as vehicle moves >= 0.8 meter or speed >= 1.5 km/h, update movement bearing
    if (anchorMeters >= 0.8 || _filteredSpeed >= 1.5) {
      final moveBearing = Geolocator.bearingBetween(
        _bearingAnchorPosition!.latitude,
        _bearingAnchorPosition!.longitude,
        position.latitude,
        position.longitude,
      );
      calculatedHeading = (moveBearing + 360.0) % 360.0;
      _bearingAnchorPosition = position;
    } else if (position.heading != 0.0) {
      // When stationary on Android in landscape (ROTATION_90), hardware sensor is 90 deg off.
      // Compensate so the top of landscape screen matches forward/North.
      calculatedHeading = (position.heading - 90.0 + 360.0) % 360.0;
    }
    _lastPosition = position;

    final newDistance = _currentSpeedData.totalDistanceKm + distanceDeltaKm;
    final newMax = max(_currentSpeedData.maxSpeed, _filteredSpeed);

    // Compute average speed
    final elapsedHours = (_currentSpeedData.tripDuration.inSeconds) / 3600.0;
    final newAvg = elapsedHours > 0.005 ? (newDistance / elapsedHours) : _filteredSpeed;

    // Elevation, Total Ascent & Total Descent tracking
    final double rawAltitude = position.altitude;
    if (_lastAltitude != 0.0) {
      final double altDiff = rawAltitude - _lastAltitude;
      // Filter out tiny GPS altitude jitter (< 0.6m) and sensor spikes (> 80m)
      if (altDiff > 0.6 && altDiff < 80.0) {
        _totalAscentMeters += altDiff;
        _lastAltitude = rawAltitude;
      } else if (altDiff < -0.6 && altDiff > -80.0) {
        _totalDescentMeters += altDiff.abs();
        _lastAltitude = rawAltitude;
      }
    } else if (rawAltitude != 0.0) {
      _lastAltitude = rawAltitude;
    }

    final currentLatLng = LatLng(position.latitude, position.longitude);
    _positionController.add(currentLatLng);

    _updateSpeedData(_currentSpeedData.copyWith(
      currentSpeed: _filteredSpeed,
      maxSpeed: newMax,
      avgSpeed: newAvg,
      totalDistanceKm: newDistance,
      altitude: position.altitude,
      totalAscentMeters: _totalAscentMeters,
      totalDescentMeters: _totalDescentMeters,
      heading: calculatedHeading,
      accuracy: position.accuracy,
      isGpsActive: true,
    ));
  }

  void _updateSpeedData(SpeedData data) {
    _currentSpeedData = data;
    _speedDataController.add(_currentSpeedData);
  }

  void setUnit(SpeedUnit unit) {
    _updateSpeedData(_currentSpeedData.copyWith(unit: unit));
  }

  void setSpeedLimit(double limitKmh) {
    _updateSpeedData(_currentSpeedData.copyWith(speedLimit: limitKmh));
  }

  void resetTrip() {
    _tripStartTime = DateTime.now();
    _filteredSpeed = 0.0;
    _totalAscentMeters = 0.0;
    _totalDescentMeters = 0.0;
    _lastAltitude = _currentSpeedData.altitude;
    _lastPosition = null;
    _updateSpeedData(_currentSpeedData.copyWith(
      currentSpeed: 0.0,
      maxSpeed: 0.0,
      avgSpeed: 0.0,
      totalDistanceKm: 0.0,
      totalAscentMeters: 0.0,
      totalDescentMeters: 0.0,
      tripDuration: Duration.zero,
    ));
  }

  // ---------------- SIMULATION DRIVE (Demo Mode) ----------------
  void toggleSimulation(List<LatLng> routePoints) {
    if (_isSimulationMode) {
      stopSimulation();
    } else {
      startSimulation(routePoints);
    }
  }

  void startSimulation(List<LatLng> routePoints) {
    stopGpsTracking();
    _isSimulationMode = true;
    _simRoute = routePoints;
    _simIndex = 0;
    _tripStartTime ??= DateTime.now();

    _simDriveTimer?.cancel();
    final random = Random();

    _simDriveTimer = Timer.periodic(const Duration(milliseconds: 300), (_) {
      if (_simRoute.isEmpty) return;

      // Realistic speed variation (accelerating, cruising around 60-110 km/h, braking)
      if (_simIndex % 40 == 0) {
        _simTargetSpeed = 45.0 + random.nextDouble() * 65.0; // 45 - 110 km/h
      }

      // Smooth acceleration / deceleration
      _filteredSpeed += (_simTargetSpeed - _filteredSpeed) * 0.08;
      final speedWithJitter = (_filteredSpeed + (random.nextDouble() - 0.5) * 2.0).clamp(0.0, 140.0);

      // Move along route based on speed
      final stepDistanceMeters = (speedWithJitter / 3.6) * 0.3; // distance covered in 300ms

      // Simulated elevation profile (gentle rolling terrain)
      final simAlt = 135.0 + 25.0 * sin(_simIndex * 0.05);
      final altDelta = simAlt - (_lastAltitude == 0.0 ? simAlt : _lastAltitude);
      if (altDelta > 0.2) _totalAscentMeters += altDelta;
      if (altDelta < -0.2) _totalDescentMeters += altDelta.abs();
      _lastAltitude = simAlt;

      _currentSpeedData = _currentSpeedData.copyWith(
        currentSpeed: speedWithJitter,
        maxSpeed: max(_currentSpeedData.maxSpeed, speedWithJitter),
        totalDistanceKm: _currentSpeedData.totalDistanceKm + (stepDistanceMeters / 1000),
        altitude: simAlt,
        totalAscentMeters: _totalAscentMeters,
        totalDescentMeters: _totalDescentMeters,
        accuracy: 3.5,
        isGpsActive: true,
      );

      // Compute heading to next point
      final currentPoint = _simRoute[_simIndex];
      _positionController.add(currentPoint);

      if (_simIndex < _simRoute.length - 1) {
        final nextPoint = _simRoute[_simIndex + 1];
        final dLat = nextPoint.latitude - currentPoint.latitude;
        final dLng = nextPoint.longitude - currentPoint.longitude;
        final headingRad = atan2(dLng, dLat);
        final headingDeg = (headingRad * 180 / pi + 360) % 360;
        _currentSpeedData = _currentSpeedData.copyWith(heading: headingDeg);
      }

      _simIndex = (_simIndex + 1) % _simRoute.length;
      _updateSpeedData(_currentSpeedData);
    });
  }

  void stopSimulation() {
    _isSimulationMode = false;
    _simDriveTimer?.cancel();
    _simDriveTimer = null;
    _filteredSpeed = 0.0;
    _updateSpeedData(_currentSpeedData.copyWith(
      currentSpeed: 0.0,
      isGpsActive: false,
    ));
  }

  bool get isSimulationMode => _isSimulationMode;

  void dispose() {
    _positionSubscription?.cancel();
    _compassSubscription?.cancel();
    _tripTimer?.cancel();
    _simDriveTimer?.cancel();
    _speedDataController.close();
    _positionController.close();
  }
}
