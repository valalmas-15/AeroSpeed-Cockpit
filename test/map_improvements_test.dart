import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:speedometer_app/main.dart';
import 'package:speedometer_app/providers/dashboard_provider.dart';
import 'package:speedometer_app/widgets/map/map_panel.dart';
import 'package:speedometer_app/widgets/speedometer/speedometer_panel.dart';
import 'package:speedometer_app/widgets/vitals/vitals_panel.dart';

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
  });

  group('Map Improvements and Sizing Tests (Samsung Galaxy J6+)', () {
    testWidgets('DashboardCockpitScreen renders 3 columns when not full screen on J6+ landscape (740x360)',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1480, 720);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => DashboardProvider()),
          ],
          child: const MaterialApp(
            home: DashboardCockpitScreen(),
          ),
        ),
      );
      await tester.pump();

      // Normal mode: SpeedometerPanel, MapPanel, and VitalsPanel are present
      expect(find.byType(SpeedometerPanel), findsOneWidget);
      expect(find.byType(MapPanel), findsOneWidget);
      expect(find.byType(VitalsPanel), findsOneWidget);
    });

    testWidgets('DashboardCockpitScreen renders full screen MapPanel when isMapFullScreen is true',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1480, 720);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) {
              final p = DashboardProvider();
              p.setMapFullScreen(true);
              return p;
            }),
          ],
          child: const MaterialApp(
            home: DashboardCockpitScreen(),
          ),
        ),
      );
      await tester.pump();

      // In Full Map mode: MapPanel is full screen, Speedometer and Vitals are hidden from cockpit body
      expect(find.byType(MapPanel), findsOneWidget);
      expect(find.byType(SpeedometerPanel), findsNothing);
      expect(find.byType(VitalsPanel), findsNothing);

      // Mini speed badge is displayed in full map mode
      expect(find.byIcon(Icons.speed), findsOneWidget);

      // Exit fullscreen icon is available
      expect(find.byIcon(Icons.fullscreen_exit), findsOneWidget);
    });

    testWidgets('MapPanel action buttons and compact controls render without overflow',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1480, 720);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => DashboardProvider()),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 285,
                height: 322,
                child: MapPanel(isFullScreen: false),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Ensure no overflow exception occurred
      expect(tester.takeException(), isNull);

      // Find quick action buttons
      expect(find.byIcon(Icons.fullscreen), findsOneWidget);
      expect(find.byIcon(Icons.add_location_alt_rounded), findsOneWidget);
      expect(find.byIcon(Icons.alt_route), findsOneWidget);
      expect(find.byIcon(Icons.my_location), findsOneWidget);
      expect(find.byIcon(Icons.add), findsOneWidget);
      expect(find.byIcon(Icons.remove), findsOneWidget);
    });
  });
}
