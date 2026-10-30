import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speedometer_app/models/speed_data.dart';
import 'package:speedometer_app/models/workout_session_model.dart';
import 'package:speedometer_app/providers/dashboard_provider.dart';
import 'package:speedometer_app/services/offline_map_service.dart';
import 'package:speedometer_app/services/workout_history_service.dart';
import 'package:speedometer_app/widgets/history/route_thumbnail_widget.dart';
import 'package:speedometer_app/widgets/history/workout_history_screen.dart';
import 'package:speedometer_app/widgets/history/workout_route_map_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('flutter.baseflow.com/geolocator'),
      (MethodCall methodCall) async {
        if (methodCall.method == 'isLocationServiceEnabled') return true;
        if (methodCall.method == 'checkPermission') return 3;
        if (methodCall.method == 'requestPermission') return 3;
        return null;
      },
    );

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('flutter_blue_plus/methods'),
      (MethodCall methodCall) async {
        if (methodCall.method == 'getAdapterState') return 4;
        if (methodCall.method == 'isSupported') return true;
        if (methodCall.method == 'flutterRestart') return null;
        return null;
      },
    );
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    OfflineMapService.instance.setOnlineStatus(true);
  });

  tearDown(() {
    OfflineMapService.instance.setOnlineStatus(null);
  });

  group('WorkoutSession Model & Serialization Tests', () {
    test('WorkoutSession serializes to JSON and back faithfully', () {
      final now = DateTime.now();
      final start = now.subtract(const Duration(minutes: 45));
      final session = WorkoutSession(
        id: 'test_session_123',
        startTime: start,
        endTime: now,
        duration: const Duration(minutes: 45, seconds: 30),
        totalDistanceKm: 14.5,
        avgSpeedKmh: 19.3,
        maxSpeedKmh: 34.2,
        totalAscentMeters: 120.0,
        totalDescentMeters: 85.0,
        calories: 340.0,
        speedUnit: SpeedUnit.kmh,
        routeName: 'Tugu ke Keraton',
        startLocation: '-7.7828, 110.3670',
        destinationLocation: 'Keraton Yogyakarta',
        routePoints: const [
          LatLng(-7.7828, 110.3670),
          LatLng(-7.7925, 110.3685),
          LatLng(-7.7956, 110.3695),
        ],
        routeThumbnailPath: '/data/user/0/com.speedometer.speedometer_app/app_flutter/workout_thumbnails/thumb_123.png',
        avgHeartRate: 142,
        maxHeartRate: 168,
        minHeartRate: 95,
        lastStress: 25,
        lastSpo2: 98,
        wasWatchConnected: true,
      );

      final jsonMap = session.toJson();
      final decoded = WorkoutSession.fromJson(jsonMap);

      expect(decoded.id, 'test_session_123');
      expect(decoded.duration.inMinutes, 45);
      expect(decoded.totalDistanceKm, 14.5);
      expect(decoded.avgSpeedKmh, 19.3);
      expect(decoded.maxSpeedKmh, 34.2);
      expect(decoded.totalAscentMeters, 120.0);
      expect(decoded.totalDescentMeters, 85.0);
      expect(decoded.calories, 340.0);
      expect(decoded.routeName, 'Tugu ke Keraton');
      expect(decoded.avgHeartRate, 142);
      expect(decoded.maxHeartRate, 168);
      expect(decoded.hasRoute, isTrue);
      expect(decoded.routePoints.length, 3);
      expect(decoded.routePoints.first.latitude, closeTo(-7.7828, 0.0001));
      expect(decoded.routeThumbnailPath, '/data/user/0/com.speedometer.speedometer_app/app_flutter/workout_thumbnails/thumb_123.png');
      expect(decoded.wasWatchConnected, isTrue);
    });
  });

  group('WorkoutHistoryService Storage Tests', () {
    test('saveSession, loadSessions, deleteSession, and clearAll work with SharedPreferences', () async {
      final service = WorkoutHistoryService.instance;
      await service.clearAll();

      var sessions = await service.loadSessions();
      expect(sessions, isEmpty);

      // session1: 1 hour ago (more recent)
      final session1 = WorkoutSession(
        id: 's1',
        startTime: DateTime.now().subtract(const Duration(hours: 1)),
        endTime: DateTime.now(),
        duration: const Duration(minutes: 30),
        totalDistanceKm: 10.0,
        avgSpeedKmh: 20.0,
        maxSpeedKmh: 30.0,
        totalAscentMeters: 50.0,
        totalDescentMeters: 40.0,
        calories: 250.0,
        routeName: 'Rute Pagi Malioboro',
        avgHeartRate: 135,
        maxHeartRate: 155,
        minHeartRate: 80,
        lastStress: 20,
        lastSpo2: 99,
        wasWatchConnected: true,
      );

      // session2: 3 hours ago (older)
      final session2 = WorkoutSession(
        id: 's2',
        startTime: DateTime.now().subtract(const Duration(hours: 3)),
        endTime: DateTime.now().subtract(const Duration(hours: 2)),
        duration: const Duration(minutes: 60),
        totalDistanceKm: 25.0,
        avgSpeedKmh: 25.0,
        maxSpeedKmh: 42.0,
        totalAscentMeters: 180.0,
        totalDescentMeters: 170.0,
        calories: 520.0,
        routeName: 'Keliling Ringroad',
        avgHeartRate: 148,
        maxHeartRate: 172,
        minHeartRate: 90,
        lastStress: 30,
        lastSpo2: 97,
        wasWatchConnected: true,
      );

      await service.saveSession(session1);
      await service.saveSession(session2);

      sessions = await service.loadSessions();
      expect(sessions.length, 2);
      // Newest first (session1 was 1 hr ago, session2 was 3 hrs ago)
      expect(sessions.first.id, 's1');
      expect(sessions.last.id, 's2');

      // Delete s1
      await service.deleteSession('s1');
      sessions = await service.loadSessions();
      expect(sessions.length, 1);
      expect(sessions.first.id, 's2');

      // Clear all
      await service.clearAll();
      sessions = await service.loadSessions();
      expect(sessions, isEmpty);
    });
  });

  group('DashboardProvider Session & Screen Navigation Tests', () {
    test('Session lifecycle starts, pauses, resumes, and finishes properly', () async {
      final provider = DashboardProvider();

      expect(provider.sessionStatus, SessionStatus.idle);
      expect(provider.isSessionIdle, isTrue);
      expect(provider.isSessionRunning, isFalse);
      expect(provider.isSessionPaused, isFalse);

      // In idle, speed telemetry below gauge is zeroed out
      final speedWhenIdle = provider.speedData;
      expect(speedWhenIdle.tripDuration, Duration.zero);
      expect(speedWhenIdle.totalDistanceKm, 0.0);
      expect(speedWhenIdle.avgSpeed, 0.0);
      expect(speedWhenIdle.maxSpeed, 0.0);
      expect(speedWhenIdle.totalAscentMeters, 0.0);
      expect(speedWhenIdle.totalDescentMeters, 0.0);

      // Start session
      provider.startSession();
      expect(provider.sessionStatus, SessionStatus.running);
      expect(provider.isSessionRunning, isTrue);
      expect(provider.isSessionIdle, isFalse);

      // Pause session
      provider.pauseSession();
      expect(provider.sessionStatus, SessionStatus.paused);
      expect(provider.isSessionPaused, isTrue);
      expect(provider.isSessionRunning, isFalse);

      // Resume session
      provider.resumeSession();
      expect(provider.sessionStatus, SessionStatus.running);

      // Screen navigation
      expect(provider.currentScreen, AppScreen.dashboard);
      provider.setScreen(AppScreen.history);
      expect(provider.currentScreen, AppScreen.history);
      provider.setScreen(AppScreen.dashboard);
      expect(provider.currentScreen, AppScreen.dashboard);

      // Finish session
      final saved = await provider.finishSession();
      expect(saved, isNotNull);
      expect(provider.sessionStatus, SessionStatus.idle);

      provider.dispose();
    });
  });

  group('WorkoutHistoryScreen Widget Tests', () {
    testWidgets('Renders empty state when no sessions exist', (tester) async {
      await WorkoutHistoryService.instance.clearAll();
      final provider = DashboardProvider();

      await tester.pumpWidget(
        ChangeNotifierProvider<DashboardProvider>.value(
          value: provider,
          child: const MaterialApp(
            home: Scaffold(
              body: WorkoutHistoryScreen(),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('RIWAYAT WORKOUT & BERKENDARA'), findsOneWidget);
      expect(find.text('BELUM ADA RIWAYAT SESI'), findsOneWidget);
      expect(find.text('BUKA DASHBOARD & MULAI SESI'), findsOneWidget);

      provider.dispose();
      await tester.pump();
    });

    testWidgets('Renders list of sessions when workouts are saved', (tester) async {
      await WorkoutHistoryService.instance.clearAll();
      final sample = WorkoutSession(
        id: 'session_demo_99',
        startTime: DateTime.now().subtract(const Duration(minutes: 25)),
        endTime: DateTime.now(),
        duration: const Duration(minutes: 25),
        totalDistanceKm: 8.7,
        avgSpeedKmh: 20.8,
        maxSpeedKmh: 35.0,
        totalAscentMeters: 45.0,
        totalDescentMeters: 30.0,
        calories: 190.0,
        routeName: 'Eksplorasi Malioboro',
        avgHeartRate: 132,
        maxHeartRate: 154,
        minHeartRate: 75,
        lastStress: 18,
        lastSpo2: 98,
        wasWatchConnected: true,
      );
      await WorkoutHistoryService.instance.saveSession(sample);
      final provider = DashboardProvider();

      await tester.pumpWidget(
        ChangeNotifierProvider<DashboardProvider>.value(
          value: provider,
          child: const MaterialApp(
            home: Scaffold(
              body: WorkoutHistoryScreen(),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Eksplorasi Malioboro'), findsOneWidget);
      expect(find.text('BUKA PETA'), findsOneWidget);
      expect(find.text('8.7'), findsOneWidget);
      expect(find.text('km'), findsWidgets);
      expect(find.text('25:00'), findsOneWidget);
      expect(find.byIcon(Icons.delete_sweep_rounded), findsOneWidget);
      expect(find.byIcon(Icons.delete_outline_rounded), findsOneWidget);

      provider.dispose();
      await tester.pump();
    });

    testWidgets('WorkoutRouteMapScreen renders map and Strava metrics HUD', (tester) async {
      final sessionWithRoute = WorkoutSession(
        id: 'session_route_view_test',
        startTime: DateTime.now().subtract(const Duration(minutes: 30)),
        endTime: DateTime.now(),
        duration: const Duration(minutes: 30),
        totalDistanceKm: 12.4,
        avgSpeedKmh: 24.8,
        maxSpeedKmh: 42.0,
        totalAscentMeters: 80.0,
        totalDescentMeters: 60.0,
        calories: 280.0,
        routeName: 'Rute Strava Yogyakarta',
        routePoints: const [
          LatLng(-7.7828, 110.3670),
          LatLng(-7.7895, 110.3663),
          LatLng(-7.7956, 110.3695),
        ],
        avgHeartRate: 145,
        maxHeartRate: 168,
        minHeartRate: 85,
        lastStress: 20,
        lastSpo2: 98,
        wasWatchConnected: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: WorkoutRouteMapScreen(session: sessionWithRoute),
        ),
      );
      await tester.pump();

      expect(find.text('Rute Strava Yogyakarta'), findsOneWidget);
      expect(find.text('KEMBALI'), findsOneWidget);
      expect(find.text('12.4'), findsOneWidget);
      expect(find.byType(FlutterMap), findsOneWidget);
    });

    testWidgets('WorkoutHistoryScreen displays RouteThumbnailWidget for recorded session', (tester) async {
      final historyService = WorkoutHistoryService.instance;
      await historyService.clearAll();

      final sessionWithRoute = WorkoutSession(
        id: 'session_thumb_test',
        startTime: DateTime.now().subtract(const Duration(minutes: 20)),
        endTime: DateTime.now(),
        duration: const Duration(minutes: 20),
        totalDistanceKm: 8.5,
        avgSpeedKmh: 25.5,
        maxSpeedKmh: 38.0,
        totalAscentMeters: 45.0,
        totalDescentMeters: 30.0,
        calories: 190.0,
        routeName: 'Latihan Sore Track',
        routePoints: const [
          LatLng(-7.7828, 110.3670),
          LatLng(-7.7895, 110.3663),
          LatLng(-7.7956, 110.3695),
        ],
        avgHeartRate: 140,
        maxHeartRate: 165,
        minHeartRate: 85,
        lastStress: 22,
        lastSpo2: 98,
        wasWatchConnected: true,
      );

      await historyService.saveSession(sessionWithRoute);

      final provider = DashboardProvider();
      await tester.pumpWidget(
        ChangeNotifierProvider<DashboardProvider>.value(
          value: provider,
          child: const MaterialApp(
            home: Scaffold(
              body: WorkoutHistoryScreen(),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(RouteThumbnailWidget), findsOneWidget);
      expect(find.text('Latihan Sore Track'), findsOneWidget);

      provider.dispose();
      await tester.pump();
    });
  });
}
