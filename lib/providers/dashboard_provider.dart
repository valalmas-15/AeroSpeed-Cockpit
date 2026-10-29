import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/province_offline_model.dart';
import '../models/route_model.dart';
import '../models/speed_data.dart';
import '../models/vital_signs.dart';
import '../services/ble_heart_rate_service.dart';
import '../services/gps_speed_service.dart';
import '../services/offline_map_service.dart';
import '../services/routing_service.dart';

enum MapStyle {
  darkMatter,
  cyberVoyager,
  satellite,
}

enum CockpitMode {
  minimalis,
  fun,
}

enum NetworkMode {
  online,
  offline,
}

class DashboardProvider extends ChangeNotifier {
  final GpsSpeedService _gpsService = GpsSpeedService();
  final BleHeartRateService _bleService = BleHeartRateService();
  final OfflineMapService _offlineMapService = OfflineMapService.instance;

  // Subscriptions
  StreamSubscription<SpeedData>? _speedSub;
  StreamSubscription<LatLng>? _positionSub;
  StreamSubscription<VitalSigns>? _vitalsSub;
  StreamSubscription<ProvinceOfflinePack?>? _offlineMapSub;

  // State
  SpeedData _speedData = const SpeedData();
  VitalSigns _vitals = const VitalSigns();
  NavigationRoute? _currentRoute;
  LatLng _currentPosition = const LatLng(-7.7956, 110.3695); // Default Yogyakarta until GPS locks
  double _currentHeading = 0.0;
  MapStyle _mapStyle = MapStyle.satellite;
  CockpitMode _cockpitMode = CockpitMode.fun; // Default mode tema: FUN
  NetworkMode _networkMode = NetworkMode.online; // Mode Online / Offline
  bool _isRouteFollowVehicle = true;
  bool _isRerouting = false;
  int _rerouteCount = 0;
  bool _isMapFullScreen = false;
  DateTime? _lastRerouteTime;
  bool _shouldShowOfflinePrompt = false;
  bool _isDisposed = false;

  // Calorie accumulation timer
  Timer? _calorieTimer;
  double _accumulatedCalories = 0.0;

  // Service Getters
  GpsSpeedService get gpsService => _gpsService;
  BleHeartRateService get bleService => _bleService;
  OfflineMapService get offlineMapService => _offlineMapService;

  // State Getters
  SpeedData get speedData => _speedData;
  VitalSigns get vitals => _vitals;
  NavigationRoute? get currentRoute => _currentRoute;
  LatLng get currentPosition => _currentPosition;
  double get currentHeading => _currentHeading;
  MapStyle get mapStyle => _mapStyle;
  CockpitMode get cockpitMode => _cockpitMode;
  bool get isFunMode => _cockpitMode == CockpitMode.fun;
  bool get isRouteFollowVehicle => _isRouteFollowVehicle;
  bool get isSimulationActive => _gpsService.isSimulationMode;
  bool get isBleSimulationActive => _bleService.isSimulationMode;
  bool get isRerouting => _isRerouting;
  int get rerouteCount => _rerouteCount;
  bool get isMapFullScreen => _isMapFullScreen;
  bool get shouldShowOfflinePrompt => _shouldShowOfflinePrompt && _offlineMapService.currentProvince != null;
  ProvinceOfflinePack? get currentProvince => _offlineMapService.currentProvince;

  // Network Mode Getters
  NetworkMode get networkMode => _networkMode;
  bool get isOfflineMode => _networkMode == NetworkMode.offline;
  bool get isOnlineMode => _networkMode == NetworkMode.online;
  bool get isInternetConnected => _offlineMapService.isOnline;

  // Map Orientation Mode:
  // true = Heading-Up (Peta berputar mengikuti arah hadap kendaraan / kompas)
  // false = North-Up (Kunci ke Utara, Utara selalu di atas, rotasi peta = 0.0)
  bool _isHeadingUp = true;
  bool get isHeadingUp => _isHeadingUp;
  bool get isNorthUp => !_isHeadingUp;

  // Map Theme Mode:
  // false = Mode Siang / Day Mode (Google Maps Daylight / Natural colors) [DEFAULT BARU]
  // true = Mode Malam / Night Mode (Dark Monochrome contrast)
  bool _isDarkMap = false;
  bool get isDarkMap => _isDarkMap;
  bool get isDayMap => !_isDarkMap;

  // Track whether the current active route has already had its bounds fitted initially
  bool _isRouteInitialFitted = false;
  bool get isRouteInitialFitted => _isRouteInitialFitted;

  void markRouteFitted() {
    _isRouteInitialFitted = true;
  }

  void toggleMapOrientation() {
    _isHeadingUp = !_isHeadingUp;
    _saveOrientationPreference(_isHeadingUp);
    notifyListeners();
  }

  void setMapOrientation({required bool headingUp}) {
    if (_isHeadingUp != headingUp) {
      _isHeadingUp = headingUp;
      _saveOrientationPreference(_isHeadingUp);
      notifyListeners();
    }
  }

  void toggleMapTheme() {
    _isDarkMap = !_isDarkMap;
    _saveMapThemePreference(_isDarkMap);
    notifyListeners();
  }

  void setMapDarkTheme(bool isDark) {
    if (_isDarkMap != isDark) {
      _isDarkMap = isDark;
      _saveMapThemePreference(_isDarkMap);
      notifyListeners();
    }
  }

  Future<void> _loadOrientationPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedHeadingUp = prefs.getBool('map_orientation_heading_up');
      if (savedHeadingUp != null && !_isDisposed) {
        _isHeadingUp = savedHeadingUp;
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> _saveOrientationPreference(bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('map_orientation_heading_up', value);
    } catch (_) {}
  }

  Future<void> _loadMapThemePreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedDark = prefs.getBool('map_is_dark_theme');
      if (savedDark != null && !_isDisposed) {
        _isDarkMap = savedDark;
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> _saveMapThemePreference(bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('map_is_dark_theme', value);
    } catch (_) {}
  }

  Future<bool> setNetworkMode(NetworkMode mode) async {
    if (mode == NetworkMode.online) {
      final hasInternet = await _offlineMapService.checkInternetConnection(force: true);
      if (!hasInternet) {
        debugPrint("[NetworkMode] Tidak dapat beralih ke Online: Tidak ada koneksi internet.");
        notifyListeners();
        return false;
      }
    }
    _networkMode = mode;
    notifyListeners();
    return true;
  }

  void setMapFullScreen(bool value) {
    if (_isMapFullScreen != value) {
      _isMapFullScreen = value;
      notifyListeners();
    }
  }

  void toggleMapFullScreen() {
    _isMapFullScreen = !_isMapFullScreen;
    notifyListeners();
  }

  void setCockpitMode(CockpitMode mode) {
    if (_cockpitMode != mode) {
      _cockpitMode = mode;
      notifyListeners();
    }
  }

  void toggleCockpitMode() {
    _cockpitMode = _cockpitMode == CockpitMode.minimalis ? CockpitMode.fun : CockpitMode.minimalis;
    notifyListeners();
  }

  DashboardProvider() {
    _initListeners();
    // Start in free-roam mode with NO preselected destination/route
    _currentRoute = null;
    _startCalorieCounter();
    _startGps();
    _bleService.startAutoConnect();
    _initOfflineMap();
    _loadOrientationPreference();
    _loadMapThemePreference();
  }

  bool get isBleAutoConnecting =>
      _bleService.autoConnectEnabled &&
      !_vitals.isConnected &&
      !_bleService.isSimulationMode;

  void _initListeners() {
    // 1. Speed & GPS Telemetry
    _speedSub = _gpsService.speedStream.listen((data) {
      _speedData = data;
      // When moving at normal speed (>= 1.2 km/h) or when no active navigation route exists,
      // use live GPS course-over-ground / landscape-compensated heading
      if (data.currentSpeed >= 1.2 || _currentRoute == null) {
        _currentHeading = data.heading;
      }

      // Provide simulated exertion to BLE watch
      if (_bleService.isSimulationMode) {
        _bleService.setSimulatedExertion(data.currentSpeed);
      }
      notifyListeners();
    });

    // 2. Position updates
    _positionSub = _gpsService.positionStream.listen((pos) {
      final prevProv = _offlineMapService.currentProvince;
      final newProv = _offlineMapService.detectProvince(pos);
      if (prevProv?.id != newProv.id) {
        _checkOfflinePrompt();
      }

      _currentPosition = pos;
      _updateNavigationProgress(pos);
      notifyListeners();
    });

    // 3. Vital signs & Amazfit Active 2 telemetry
    _vitalsSub = _bleService.vitalsStream.listen((v) {
      _vitals = v.copyWith(caloriesBurned: _accumulatedCalories);
      notifyListeners();
    });
  }

  Future<void> _startGps() async {
    await _gpsService.startGpsTracking();
  }

  // Real-time calorie computation based on Heart Rate (Keytel equation)
  void _startCalorieCounter() {
    _calorieTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      final bpm = _vitals.heartRate;
      if (bpm > 50) {
        // Approximate for average 70kg driver/cyclist
        // Calorie expenditure per minute: ~ [(-55 + 0.6309*HR + 0.1988*70 + 0.2017*28) / 4.184]
        final calPerMin = ((0.45 * bpm) - 20.0).clamp(1.5, 18.0);
        final calPerSec = calPerMin / 60.0;
        _accumulatedCalories += calPerSec * 2.0;

        final calPerHour = calPerMin * 60;
        _vitals = _vitals.copyWith(
          caloriesBurned: _accumulatedCalories,
          burnRatePerHour: calPerHour,
        );
        notifyListeners();
      }
    });
  }

  // Update Navigation Progress along polyline with Auto-Reroute Detection & Route Heading
  void _updateNavigationProgress(LatLng userPos) {
    if (_currentRoute == null || _currentRoute!.polylinePoints.isEmpty) return;

    final polyline = _currentRoute!.polylinePoints;
    const distanceCalc = Distance();

    // 1. Maintain route forward heading when stationary or navigating at slow speeds
    if (polyline.length >= 2) {
      int nearestIdx = 0;
      double minD = double.infinity;
      for (int i = 0; i < polyline.length; i++) {
        final d = distanceCalc.as(LengthUnit.Meter, userPos, polyline[i]);
        if (d < minD) {
          minD = d;
          nearestIdx = i;
        }
      }

      // If user is within 45m of route, orient icon forward along the upcoming route segment
      if (minD <= 45.0) {
        int lookAheadIdx = (nearestIdx + 1).clamp(0, polyline.length - 1);
        while (lookAheadIdx < polyline.length - 1 &&
            distanceCalc.as(LengthUnit.Meter, userPos, polyline[lookAheadIdx]) < 8.0) {
          lookAheadIdx++;
        }
        final targetPoint = polyline[lookAheadIdx];
        final routeBearing = (Geolocator.bearingBetween(
          userPos.latitude,
          userPos.longitude,
          targetPoint.latitude,
          targetPoint.longitude,
        ) + 360.0) % 360.0;

        // When stationary on an active route, keep arrow oriented forward along upcoming path
        if (_speedData.currentSpeed < 1.2) {
          _currentHeading = routeBearing;
        }
      }
    }

    final steps = _currentRoute!.steps;
    if (steps.isNotEmpty) {
      int closestStepIndex = _currentRoute!.currentStepIndex;
      double minDistance = double.infinity;

      for (int i = 0; i < steps.length; i++) {
        final dist = distanceCalc.as(LengthUnit.Meter, userPos, steps[i].point);
        if (dist < minDistance) {
          minDistance = dist;
          closestStepIndex = i;
        }
      }

      if (closestStepIndex != _currentRoute!.currentStepIndex) {
        _currentRoute = _currentRoute!.copyWith(currentStepIndex: closestStepIndex);
        notifyListeners();
      }
    }

    // --- DETEKSI KELUAR JALUR & AUTO-REROUTE ---
    final dest = _currentRoute!.destinationPoint ?? _currentRoute!.polylinePoints.last;
    final distToDest = distanceCalc.as(LengthUnit.Meter, userPos, dest);

    // Jangan reroute jika sudah mendekati tujuan (< 35m)
    if (distToDest < 35.0) return;

    // Hitung jarak tegak lurus dari posisi kendaraan ke polyline rute
    final distToRoute = RoutingService.distanceToPolyline(userPos, _currentRoute!.polylinePoints);

    // Jika kendaraan berjarak lebih dari 45 meter dari rute (misal pengemudi belok lebih dulu atau mengambil jalan alternatif)
    if (distToRoute > 45.0 && !_isRerouting) {
      final now = DateTime.now();
      if (_lastRerouteTime == null || now.difference(_lastRerouteTime!).inSeconds >= 4) {
        _lastRerouteTime = now;
        _triggerAutoReroute(userPos);
      }
    }
  }

  Future<void> _triggerAutoReroute(LatLng userPos) async {
    if (_currentRoute == null || _isRerouting) return;

    _isRerouting = true;
    notifyListeners();

    try {
      final dest = _currentRoute!.destinationPoint ?? _currentRoute!.polylinePoints.last;
      final destName = _currentRoute!.destinationName;

      final newRoute = await RoutingService.fetchRoute(
        origin: userPos,
        destination: dest,
        originName: 'Posisi Terkini',
        destinationName: destName,
        forceOffline: isOfflineMode,
      );

      if (newRoute != null && _currentRoute != null) {
        _currentRoute = newRoute;
        _rerouteCount++;
        _isRouteFollowVehicle = true;
        if (_gpsService.isSimulationMode) {
          _gpsService.startSimulation(newRoute.polylinePoints);
        }
        debugPrint("Auto-rerouted successfully to $destName (reroute #$_rerouteCount)");
      }
    } catch (e) {
      debugPrint("Auto-reroute error: $e");
    } finally {
      _isRerouting = false;
      notifyListeners();
    }
  }

  // Speedometer controls
  void toggleSpeedUnit() {
    final newUnit = _speedData.unit == SpeedUnit.kmh ? SpeedUnit.mph : SpeedUnit.kmh;
    _gpsService.setUnit(newUnit);
  }

  void setSpeedLimit(double limit) {
    _gpsService.setSpeedLimit(limit);
  }

  void resetTrip() {
    _accumulatedCalories = 0.0;
    _gpsService.resetTrip();
    _vitals = _vitals.copyWith(caloriesBurned: 0.0);
    notifyListeners();
  }

  // Route & Navigation controls
  void cancelCurrentRoute() {
    _currentRoute = null;
    _isRouteInitialFitted = false;
    if (_gpsService.isSimulationMode) {
      _gpsService.stopSimulation();
    }
    notifyListeners();
  }

  void selectPresetRoute(int index) {
    if (index >= 0 && index < RoutingService.presetRoutes.length) {
      _currentRoute = RoutingService.presetRoutes[index];
      _isRouteInitialFitted = false;
      _currentPosition = _currentRoute!.polylinePoints.first;
      if (_currentRoute!.polylinePoints.length >= 2) {
        _currentHeading = (Geolocator.bearingBetween(
          _currentRoute!.polylinePoints[0].latitude,
          _currentRoute!.polylinePoints[0].longitude,
          _currentRoute!.polylinePoints[1].latitude,
          _currentRoute!.polylinePoints[1].longitude,
        ) + 360.0) % 360.0;
      }
      if (_gpsService.isSimulationMode) {
        _gpsService.startSimulation(_currentRoute!.polylinePoints);
      }
      notifyListeners();
    }
  }

  Future<void> setCustomRoute(
    LatLng origin,
    LatLng destination,
    String originName,
    String destinationName,
  ) async {
    final route = await RoutingService.fetchRoute(
      origin: origin,
      destination: destination,
      originName: originName,
      destinationName: destinationName,
      forceOffline: isOfflineMode,
    );

    if (route != null) {
      _currentRoute = route;
      _isRouteInitialFitted = false;
      _currentPosition = route.polylinePoints.first;
      if (route.polylinePoints.length >= 2) {
        _currentHeading = (Geolocator.bearingBetween(
          route.polylinePoints[0].latitude,
          route.polylinePoints[0].longitude,
          route.polylinePoints[1].latitude,
          route.polylinePoints[1].longitude,
        ) + 360.0) % 360.0;
      }
      if (_gpsService.isSimulationMode) {
        _gpsService.startSimulation(route.polylinePoints);
      }
      notifyListeners();
    }
  }

  void setMapStyle(MapStyle style) {
    _mapStyle = style;
    notifyListeners();
  }

  void toggleFollowVehicle() {
    _isRouteFollowVehicle = !_isRouteFollowVehicle;
    notifyListeners();
  }

  // Simulation controls (Demo Mode)
  void toggleDriveSimulation() {
    if (_gpsService.isSimulationMode) {
      _gpsService.stopSimulation();
      _bleService.stopSimulation();
      _gpsService.startGpsTracking();
    } else {
      final points = _currentRoute?.polylinePoints ?? [
        const LatLng(-6.175392, 106.827153),
        const LatLng(-6.218521, 106.802341),
      ];
      _gpsService.startSimulation(points);
      _bleService.startSimulation();
    }
    notifyListeners();
  }

  // Amazfit BLE controls
  void toggleBleSimulation() {
    _bleService.toggleSimulation();
    notifyListeners();
  }

  Future<void> connectToDevice(BluetoothDevice device) async {
    await _bleService.connectToDevice(device);
    notifyListeners();
  }

  Future<void> disconnectBle() async {
    await _bleService.disconnect();
    notifyListeners();
  }

  // Offline Map & Province Controls
  Future<void> _initOfflineMap() async {
    await _offlineMapService.init();
    if (_isDisposed) return;
    _offlineMapService.startConnectivityMonitoring();
    final hasInternet = await _offlineMapService.checkInternetConnection();
    if (_isDisposed) return;
    if (!hasInternet) {
      _networkMode = NetworkMode.offline;
    }
    _offlineMapService.detectProvince(_currentPosition);
    _offlineMapSub = _offlineMapService.updateStream.listen((pack) {
      if (!_isDisposed) {
        notifyListeners();
        _checkOfflinePrompt();
      }
    });
    await _checkOfflinePrompt();
  }

  Future<void> _checkOfflinePrompt() async {
    if (_isDisposed) return;
    final cur = _offlineMapService.currentProvince;
    if (cur != null) {
      final should = await _offlineMapService.shouldShowUpdatePrompt(cur);
      if (_isDisposed) return;
      if (_shouldShowOfflinePrompt != should) {
        _shouldShowOfflinePrompt = should;
        if (!_isDisposed) notifyListeners();
      }
    }
  }

  Future<bool> downloadOfflineProvince(String provinceId) async {
    try {
      await _offlineMapService.downloadProvince(provinceId);
      if (_isDisposed) return true;
      _shouldShowOfflinePrompt = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint("[DashboardProvider] Gagal mengunduh peta offline: $e");
      if (!_isDisposed) {
        notifyListeners();
      }
      return false;
    }
  }

  Future<void> dismissOfflinePrompt(String provinceId) async {
    await _offlineMapService.dismissPrompt(provinceId);
    if (_isDisposed) return;
    _shouldShowOfflinePrompt = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _calorieTimer?.cancel();
    _speedSub?.cancel();
    _positionSub?.cancel();
    _vitalsSub?.cancel();
    _offlineMapSub?.cancel();
    _offlineMapService.stopConnectivityMonitoring();
    _offlineMapService.stopPeriodicTimer();
    _gpsService.dispose();
    _bleService.dispose();
    super.dispose();
  }
}
