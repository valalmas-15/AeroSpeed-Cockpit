import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../models/vital_signs.dart';

class BleHeartRateService {
  // Standard Bluetooth SIG Heart Rate Service and Characteristics
  static final Guid heartRateServiceUuid = Guid("180D");
  static final Guid heartRateMeasurementCharUuid = Guid("2A37");
  static final Guid batteryServiceUuid = Guid("180F");
  static final Guid batteryLevelCharUuid = Guid("2A19");

  BluetoothDevice? _connectedDevice;
  StreamSubscription<List<int>>? _hrSubscription;
  StreamSubscription<List<ScanResult>>? _scanSubscription;
  StreamSubscription<BluetoothConnectionState>? _connectionStateSub;
  StreamSubscription<bool>? _isScanningSub;

  // Stream controllers
  final _vitalsController = StreamController<VitalSigns>.broadcast();
  Stream<VitalSigns> get vitalsStream => _vitalsController.stream;

  final _scanResultsController = StreamController<List<ScanResult>>.broadcast();
  Stream<List<ScanResult>> get scanResultsStream => _scanResultsController.stream;

  final _isScanningController = StreamController<bool>.broadcast();
  Stream<bool> get isScanningStream => _isScanningController.stream;

  VitalSigns _currentVitals = const VitalSigns();
  VitalSigns get currentVitals => _currentVitals;

  final List<HeartRateDataPoint> _historyBuffer = [];
  Timer? _simulationTimer;
  Timer? _autoConnectLoopTimer;
  bool _isSimulationMode = false;
  double _simBaseBpm = 85.0;

  // Auto-connect engine state
  bool _autoConnectEnabled = true;
  bool get autoConnectEnabled => _autoConnectEnabled;
  bool _isConnecting = false;
  String? _lastConnectedDeviceId;

  BleHeartRateService() {
    _initBluetooth();
  }

  void _initBluetooth() {
    _isScanningSub = FlutterBluePlus.isScanning.listen((scanning) {
      _isScanningController.add(scanning);
      // Auto-restart scan if auto-connect is active and device not yet connected
      if (!scanning && _autoConnectEnabled && _connectedDevice == null && !_isSimulationMode && !_isConnecting) {
        _autoConnectLoopTimer?.cancel();
        _autoConnectLoopTimer = Timer(const Duration(seconds: 3), () {
          if (_autoConnectEnabled && _connectedDevice == null && !_isSimulationMode && !_isConnecting) {
            startAutoConnect();
          }
        });
      }
    });

    // Listen to adapter state changes
    FlutterBluePlus.adapterState.listen((state) {
      if (state == BluetoothAdapterState.on && _autoConnectEnabled && _connectedDevice == null && !_isSimulationMode) {
        startAutoConnect();
      }
    });
  }

  // ---------------- AUTO-CONNECT ENGINE ----------------
  void toggleAutoConnect(bool enable) {
    _autoConnectEnabled = enable;
    if (enable && _connectedDevice == null && !_isSimulationMode) {
      startAutoConnect();
    } else if (!enable) {
      _autoConnectLoopTimer?.cancel();
    }
  }

  bool isMatchingWatch(ScanResult r) {
    final name = r.device.platformName.toLowerCase();
    final advName = r.advertisementData.advName.toLowerCase();
    final hasHrService = r.advertisementData.serviceUuids.any(
      (u) => u.toString().toLowerCase().contains('180d'),
    );

    if (_lastConnectedDeviceId != null && r.device.remoteId.str == _lastConnectedDeviceId) {
      return true;
    }

    if (name.contains('amazfit') ||
        name.contains('active') ||
        advName.contains('amazfit') ||
        advName.contains('active') ||
        hasHrService) {
      return true;
    }

    return false;
  }

  Future<void> startAutoConnect() async {
    if (_isSimulationMode || _connectedDevice != null || _isConnecting || !_autoConnectEnabled) {
      return;
    }

    try {
      if (await FlutterBluePlus.isSupported == false) return;

      final adapterState = await FlutterBluePlus.adapterState.first;
      if (adapterState != BluetoothAdapterState.on) return;

      debugPrint("[BLE] Auto-connect scan started for Amazfit Active 2...");

      _scanSubscription?.cancel();
      _scanSubscription = FlutterBluePlus.scanResults.listen((results) async {
        if (_connectedDevice != null || _isConnecting || !_autoConnectEnabled || _isSimulationMode) {
          return;
        }

        // Sort results
        final sorted = List<ScanResult>.from(results);
        sorted.sort((a, b) {
          final isA = isMatchingWatch(a);
          final isB = isMatchingWatch(b);
          if (isA && !isB) return -1;
          if (!isA && isB) return 1;
          return b.rssi.compareTo(a.rssi);
        });
        _scanResultsController.add(sorted);

        // Find candidate for auto-connect
        for (final r in results) {
          if (isMatchingWatch(r)) {
            final devName = r.device.platformName.isNotEmpty ? r.device.platformName : r.advertisementData.advName;
            debugPrint("[BLE] Auto-connect candidate found: $devName (${r.device.remoteId.str})");
            _isConnecting = true;
            await stopScan();

            final success = await connectToDevice(r.device);
            _isConnecting = false;

            if (success) {
              _lastConnectedDeviceId = r.device.remoteId.str;
              debugPrint("[BLE] Successfully auto-connected to: $devName");
            } else {
              debugPrint("[BLE] Auto-connect attempt failed, will retry...");
              _autoConnectLoopTimer?.cancel();
              _autoConnectLoopTimer = Timer(const Duration(seconds: 4), () {
                if (_autoConnectEnabled && _connectedDevice == null && !_isSimulationMode) {
                  startAutoConnect();
                }
              });
            }
            break;
          }
        }
      });

      await FlutterBluePlus.startScan(
        withServices: [],
        timeout: const Duration(seconds: 15),
      );
    } catch (e) {
      debugPrint("[BLE] Auto-connect error: $e");
      _isConnecting = false;
    }
  }

  // Start BLE scanning for Amazfit Active 2 and Heart Rate Monitors
  Future<void> startScan({Duration timeout = const Duration(seconds: 15)}) async {
    try {
      if (await FlutterBluePlus.isSupported == false) return;

      await FlutterBluePlus.adapterState
          .where((state) => state == BluetoothAdapterState.on)
          .first
          .timeout(const Duration(seconds: 4), onTimeout: () => BluetoothAdapterState.unknown);

      _scanSubscription?.cancel();
      _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
        final sorted = List<ScanResult>.from(results);
        sorted.sort((a, b) {
          final isA = isMatchingWatch(a);
          final isB = isMatchingWatch(b);
          if (isA && !isB) return -1;
          if (!isA && isB) return 1;
          return b.rssi.compareTo(a.rssi);
        });
        _scanResultsController.add(sorted);
      });

      await FlutterBluePlus.startScan(
        withServices: [],
        timeout: timeout,
      );
    } catch (e) {
      debugPrint("[BLE] Manual scan error: $e");
    }
  }

  Future<void> stopScan() async {
    try {
      await FlutterBluePlus.stopScan();
    } catch (e) {
      debugPrint("[BLE] Stop scan error: $e");
    }
  }

  // Connect to target device with robust retry for Android error 133
  Future<bool> connectToDevice(BluetoothDevice device, {int maxRetries = 3}) async {
    try {
      stopSimulation();
    await stopScan();
    await Future.delayed(const Duration(milliseconds: 300));
    await disconnect();

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        debugPrint("[BLE] Connecting to ${device.platformName} (Attempt $attempt/$maxRetries)...");
        _connectedDevice = device;
        await device.connect(timeout: const Duration(seconds: 7), autoConnect: false);
        debugPrint("[BLE] Connected successfully on attempt $attempt!");
        break;
      } catch (e) {
        debugPrint("[BLE] Connection attempt $attempt failed: $e");
        try {
          await device.disconnect();
        } catch (_) {}
        if (attempt == maxRetries) {
          disconnect();
          return false;
        }
        await Future.delayed(Duration(milliseconds: 600 * attempt));
      }
    }

      _connectionStateSub?.cancel();
      _connectionStateSub = device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          debugPrint("[BLE] Device disconnected: ${device.platformName}");
          _updateVitals(_currentVitals.copyWith(isConnected: false));
          _connectedDevice = null;

          // Auto-reconnect trigger
          if (_autoConnectEnabled && !_isSimulationMode) {
            _autoConnectLoopTimer?.cancel();
            _autoConnectLoopTimer = Timer(const Duration(seconds: 3), () {
              if (_autoConnectEnabled && _connectedDevice == null && !_isSimulationMode) {
                startAutoConnect();
              }
            });
          }
        }
      });

      // Discover services
      final services = await device.discoverServices();
      bool foundHr = false;

      for (var service in services) {
        // 1. Heart Rate Service
        if (service.uuid == heartRateServiceUuid) {
          for (var char in service.characteristics) {
            if (char.uuid == heartRateMeasurementCharUuid) {
              await char.setNotifyValue(true);
              _hrSubscription?.cancel();
              _hrSubscription = char.onValueReceived.listen(_parseHeartRateData);
              foundHr = true;
            }
          }
        }

        // 2. Battery Service
        if (service.uuid == batteryServiceUuid) {
          for (var char in service.characteristics) {
            if (char.uuid == batteryLevelCharUuid) {
              try {
                final val = await char.read();
                if (val.isNotEmpty) {
                  _updateVitals(_currentVitals.copyWith(batteryLevel: val.first));
                }
              } catch (_) {}
            }
          }
        }
      }

      final deviceName = device.platformName.isNotEmpty ? device.platformName : 'Amazfit Active 2';
      _lastConnectedDeviceId = device.remoteId.str;
      _updateVitals(_currentVitals.copyWith(
        isConnected: true,
        deviceName: deviceName,
      ));

      return foundHr;
    } catch (e) {
      debugPrint("[BLE] Connect error: $e");
      disconnect();
      return false;
    }
  }

  // Parse standard GATT Heart Rate Measurement Characteristic (0x2A37)
  void _parseHeartRateData(List<int> value) {
    if (value.isEmpty) return;

    final flags = value[0];
    final is16Bit = (flags & 0x01) != 0;
    int bpm = 0;

    if (is16Bit && value.length >= 3) {
      bpm = value[1] | (value[2] << 8);
    } else if (value.length >= 2) {
      bpm = value[1];
    }

    if (bpm > 30 && bpm < 250) {
      _recordBpm(bpm);
    }
  }

  void _recordBpm(int bpm) {
    final now = DateTime.now();
    _historyBuffer.add(HeartRateDataPoint(timestamp: now, bpm: bpm));
    if (_historyBuffer.length > 50) {
      _historyBuffer.removeAt(0);
    }

    final minHr = _currentVitals.minHeartRate == 0
        ? bpm
        : min(_currentVitals.minHeartRate, bpm);
    final maxHr = max(_currentVitals.maxHeartRate, bpm);

    // Compute average
    final sum = _historyBuffer.fold<int>(0, (prev, el) => prev + el.bpm);
    final avgHr = (_historyBuffer.isNotEmpty ? (sum / _historyBuffer.length) : bpm).round();

    _updateVitals(_currentVitals.copyWith(
      heartRate: bpm,
      minHeartRate: minHr,
      maxHeartRate: maxHr,
      avgHeartRate: avgHr,
      history: List.unmodifiable(_historyBuffer),
    ));
  }

  void _updateVitals(VitalSigns vitals) {
    _currentVitals = vitals;
    _vitalsController.add(_currentVitals);
  }

  Future<void> disconnect() async {
    _hrSubscription?.cancel();
    _hrSubscription = null;
    _connectionStateSub?.cancel();
    _connectionStateSub = null;

    if (_connectedDevice != null) {
      try {
        await _connectedDevice!.disconnect();
      } catch (_) {}
      _connectedDevice = null;
    }

    _updateVitals(_currentVitals.copyWith(isConnected: false));
  }

  // ---------------- SIMULATION MODE (For Testing & Demo) ----------------
  void toggleSimulation() {
    if (_isSimulationMode) {
      stopSimulation();
      if (_autoConnectEnabled) {
        startAutoConnect();
      }
    } else {
      startSimulation();
    }
  }

  void startSimulation() {
    disconnect();
    _isSimulationMode = true;
    _autoConnectLoopTimer?.cancel();
    _simulationTimer?.cancel();
    _historyBuffer.clear();

    _updateVitals(_currentVitals.copyWith(
      isConnected: true,
      deviceName: 'Amazfit Active 2 (Simulated)',
      batteryLevel: 92,
    ));

    final random = Random();
    _simulationTimer = Timer.periodic(const Duration(milliseconds: 1000), (_) {
      final jitter = (random.nextDouble() - 0.48) * 3.5;
      _simBaseBpm = (_simBaseBpm + jitter).clamp(72.0, 168.0);
      _recordBpm(_simBaseBpm.round());
    });
  }

  void setSimulatedExertion(double speedKmh) {
    if (!_isSimulationMode) return;
    if (speedKmh > 80) {
      _simBaseBpm = (_simBaseBpm * 0.9 + 145 * 0.1);
    } else if (speedKmh > 40) {
      _simBaseBpm = (_simBaseBpm * 0.9 + 120 * 0.1);
    } else {
      _simBaseBpm = (_simBaseBpm * 0.9 + 82 * 0.1);
    }
  }

  void stopSimulation() {
    _isSimulationMode = false;
    _simulationTimer?.cancel();
    _simulationTimer = null;
    _updateVitals(_currentVitals.copyWith(
      isConnected: false,
      heartRate: 0,
      deviceName: 'Amazfit Active 2',
    ));
    if (_autoConnectEnabled) {
      startAutoConnect();
    }
  }

  bool get isSimulationMode => _isSimulationMode;

  void dispose() {
    _autoConnectEnabled = false;
    _autoConnectLoopTimer?.cancel();
    _isScanningSub?.cancel();
    _simulationTimer?.cancel();
    _hrSubscription?.cancel();
    _scanSubscription?.cancel();
    _connectionStateSub?.cancel();
    _vitalsController.close();
    _scanResultsController.close();
    _isScanningController.close();
  }
}
