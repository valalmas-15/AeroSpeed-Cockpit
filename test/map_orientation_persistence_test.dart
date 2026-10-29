import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speedometer_app/providers/dashboard_provider.dart';
import 'package:speedometer_app/services/offline_map_service.dart';
import 'package:speedometer_app/widgets/map/map_panel.dart';

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
        return null;
      },
    );
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    OfflineMapService.instance.setOnlineStatus(true);
    await OfflineMapService.instance.dismissPrompt('diy');
  });

  tearDown(() {
    OfflineMapService.instance.setOnlineStatus(null);
  });

  test('Warm-up Bluetooth and dependencies', () {
    final provider = DashboardProvider();
    provider.dispose();
  });

  group('Map Orientation Persistence Tests (North-Up vs Heading-Up)', () {
    test('Default orientation is Heading-Up, can toggle to North-Up and persists in SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({});
      final provider = DashboardProvider();

      // Default is Heading-Up
      expect(provider.isHeadingUp, isTrue);
      expect(provider.isNorthUp, isFalse);

      // User switches to North-Up
      provider.toggleMapOrientation();
      expect(provider.isNorthUp, isTrue);
      expect(provider.isHeadingUp, isFalse);

      // Verify saved in SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('map_orientation_heading_up'), isFalse);

      // Simulate app reopen: provider loads preference
      final newProvider = DashboardProvider();
      await Future.delayed(const Duration(milliseconds: 50));
      expect(newProvider.isNorthUp, isTrue);

      provider.dispose();
      newProvider.dispose();
    });

    test('Orientation mode does NOT reset when opening or exiting fullscreen', () async {
      final provider = DashboardProvider();

      // User sets to North-Up
      provider.setMapOrientation(headingUp: false);
      expect(provider.isNorthUp, isTrue);

      // User opens full screen
      provider.setMapFullScreen(true);
      expect(provider.isMapFullScreen, isTrue);
      expect(provider.isNorthUp, isTrue, reason: 'Must remain North-Up when entering fullscreen');

      // User exits full screen
      provider.setMapFullScreen(false);
      expect(provider.isMapFullScreen, isFalse);
      expect(provider.isNorthUp, isTrue, reason: 'Must remain North-Up when exiting fullscreen');

      provider.dispose();
    });

    test('Orientation mode does NOT reset when route selected or rerouting', () async {
      final provider = DashboardProvider();

      // User sets to North-Up
      provider.setMapOrientation(headingUp: false);
      expect(provider.isNorthUp, isTrue);

      // User selects a route
      provider.selectPresetRoute(0);
      expect(provider.currentRoute, isNotNull);
      expect(provider.isNorthUp, isTrue, reason: 'Must remain North-Up when selecting a route');

      // Fullscreen while navigating
      provider.setMapFullScreen(true);
      expect(provider.isNorthUp, isTrue, reason: 'Must remain North-Up in navigation fullscreen');

      provider.setMapFullScreen(false);
      expect(provider.isNorthUp, isTrue, reason: 'Must remain North-Up when exiting navigation fullscreen');

      // Only changes when user explicitly toggles back to Heading-Up
      provider.toggleMapOrientation();
      expect(provider.isHeadingUp, isTrue);

      provider.dispose();
    });

    testWidgets('MapPanel orientation button toggles and retains mode across fullscreen switches', (tester) async {
      tester.view.physicalSize = const Size(1480, 720);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final provider = DashboardProvider();
      // Set to North-Up
      provider.setMapOrientation(headingUp: false);

      // 1. Build normal MapPanel
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeNotifierProvider.value(
              value: provider,
              child: const MapPanel(isFullScreen: false),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify orientation button shows explore icon (North-Up)
      expect(find.byIcon(Icons.explore), findsOneWidget);
      expect(find.byIcon(Icons.navigation), findsNothing);

      // 2. Toggle to FullScreen (replaces widget instance)
      provider.setMapFullScreen(true);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeNotifierProvider.value(
              value: provider,
              child: const MapPanel(isFullScreen: true),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Must STILL be North-Up!
      expect(provider.isNorthUp, isTrue);
      expect(find.byIcon(Icons.explore), findsOneWidget);
      expect(find.byIcon(Icons.navigation), findsNothing);

      // 3. Exit FullScreen (replaces widget instance again)
      provider.setMapFullScreen(false);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeNotifierProvider.value(
              value: provider,
              child: const MapPanel(isFullScreen: false),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Must STILL be North-Up!
      expect(provider.isNorthUp, isTrue);
      expect(find.byIcon(Icons.explore), findsOneWidget);

      // 4. Click the orientation button: Now it changes to Heading-Up!
      await tester.tap(find.byIcon(Icons.explore));
      await tester.pumpAndSettle();

      expect(provider.isHeadingUp, isTrue);
      expect(find.byIcon(Icons.navigation), findsOneWidget);

      provider.dispose();
    });
  });
}
