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

  group('Map Theme Mode (Day Mode vs Night Mode) Tests', () {
    test('Default map theme is Day Mode (isDarkMap is false)', () {
      final provider = DashboardProvider();

      expect(provider.isDarkMap, isFalse, reason: 'Default map theme must be Day Mode (Mode Siang)');
      expect(provider.isDayMap, isTrue);

      provider.dispose();
    });

    test('Toggling map theme switches to Night Mode and persists in SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({});
      final provider = DashboardProvider();

      // Initial: Day Mode
      expect(provider.isDarkMap, isFalse);

      // Toggle to Night Mode
      provider.toggleMapTheme();
      expect(provider.isDarkMap, isTrue);
      expect(provider.isDayMap, isFalse);

      // Check SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('map_is_dark_theme'), isTrue);

      // Simulate app restart / new provider
      final newProvider = DashboardProvider();
      await Future.delayed(const Duration(milliseconds: 50));
      expect(newProvider.isDarkMap, isTrue, reason: 'Must restore user dark mode preference on startup');

      provider.dispose();
      newProvider.dispose();
    });

    test('Map theme mode does NOT reset when opening or exiting fullscreen', () async {
      final provider = DashboardProvider();

      // Default is Day Mode
      expect(provider.isDarkMap, isFalse);

      // Open fullscreen
      provider.setMapFullScreen(true);
      expect(provider.isMapFullScreen, isTrue);
      expect(provider.isDarkMap, isFalse, reason: 'Must remain Day Mode when opening fullscreen');

      // Exit fullscreen
      provider.setMapFullScreen(false);
      expect(provider.isMapFullScreen, isFalse);
      expect(provider.isDarkMap, isFalse, reason: 'Must remain Day Mode when exiting fullscreen');

      // Toggle to Dark Mode
      provider.toggleMapTheme();
      expect(provider.isDarkMap, isTrue);

      // Open and exit fullscreen in Dark Mode
      provider.setMapFullScreen(true);
      expect(provider.isDarkMap, isTrue, reason: 'Must remain Dark Mode in fullscreen');

      provider.setMapFullScreen(false);
      expect(provider.isDarkMap, isTrue, reason: 'Must remain Dark Mode after exiting fullscreen');

      provider.dispose();
    });

    testWidgets('MapPanel renders wb_sunny icon by default and toggles to dark_mode on tap', (tester) async {
      tester.view.physicalSize = const Size(1480, 720);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final provider = DashboardProvider();

      // Render MapPanel (Day mode default)
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

      // In Day Mode, the button shows Icons.wb_sunny (with tooltip indicating Mode Siang)
      expect(find.byIcon(Icons.wb_sunny), findsOneWidget);
      expect(find.byIcon(Icons.dark_mode), findsNothing);

      // Tap theme toggle button
      await tester.tap(find.byIcon(Icons.wb_sunny));
      await tester.pumpAndSettle();

      // Should now be in Night Mode, displaying dark_mode icon
      expect(provider.isDarkMap, isTrue);
      expect(find.byIcon(Icons.dark_mode), findsOneWidget);
      expect(find.byIcon(Icons.wb_sunny), findsNothing);

      provider.dispose();
    });
  });
}

