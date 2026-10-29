import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speedometer_app/models/route_model.dart';
import 'package:speedometer_app/providers/dashboard_provider.dart';
import 'package:speedometer_app/services/offline_map_service.dart';
import 'package:speedometer_app/services/routing_service.dart';
import 'package:speedometer_app/widgets/map/cancel_route_dialog.dart';
import 'package:speedometer_app/widgets/map/navigation_hud.dart';

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
  });

  tearDown(() {
    OfflineMapService.instance.setOnlineStatus(null);
  });

  final dummyRoute = RoutingService.presetRoutes.first;

  test('Warm-up Bluetooth and dependencies', () {
    final provider = DashboardProvider();
    provider.dispose();
  });

  group('Cancel Route Confirmation Dialog Tests', () {
    testWidgets('Renders dialog with destination, warning, and confirmation buttons', (tester) async {
      final provider = DashboardProvider();
      provider.selectPresetRoute(0);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeNotifierProvider.value(
              value: provider,
              child: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => CancelRouteConfirmDialog.show(context),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('BATALKAN NAVIGASI RUTE?'), findsOneWidget);
      expect(find.text(provider.currentRoute!.destinationName), findsOneWidget);
      expect(find.textContaining('Apakah Anda yakin ingin menghentikan petunjuk arah'), findsOneWidget);
      expect(find.text('LANJUTKAN RUTE'), findsOneWidget);
      expect(find.text('YA, BATALKAN'), findsOneWidget);

      await tester.tap(find.text('LANJUTKAN RUTE'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 1));

      provider.dispose();
    });

    testWidgets('Tapping LANJUTKAN RUTE dismisses dialog without cancelling route', (tester) async {
      final provider = DashboardProvider();
      provider.selectPresetRoute(0);
      expect(provider.currentRoute, isNotNull);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeNotifierProvider.value(
              value: provider,
              child: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => CancelRouteConfirmDialog.show(context),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );

      // Tap open
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('BATALKAN NAVIGASI RUTE?'), findsOneWidget);

      // Tap LANJUTKAN RUTE
      await tester.tap(find.text('LANJUTKAN RUTE'));
      await tester.pumpAndSettle();

      // Dialog closed
      expect(find.text('BATALKAN NAVIGASI RUTE?'), findsNothing);
      // Route is STILL ACTIVE
      expect(provider.currentRoute, isNotNull);

      provider.dispose();
    });

    testWidgets('Tapping YA, BATALKAN cancels the route', (tester) async {
      final provider = DashboardProvider();
      provider.selectPresetRoute(0);
      expect(provider.currentRoute, isNotNull);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeNotifierProvider.value(
              value: provider,
              child: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => CancelRouteConfirmDialog.show(context),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );

      // Tap open
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('BATALKAN NAVIGASI RUTE?'), findsOneWidget);

      // Tap YA, BATALKAN
      await tester.tap(find.text('YA, BATALKAN'));
      await tester.pumpAndSettle();

      // Dialog closed
      expect(find.text('BATALKAN NAVIGASI RUTE?'), findsNothing);
      // Route is CANCELLED!
      expect(provider.currentRoute, isNull);

      provider.dispose();
    });

    testWidgets('NavigationHud cancel button opens confirmation dialog instead of cancelling instantly', (tester) async {
      final provider = DashboardProvider();
      provider.selectPresetRoute(0);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeNotifierProvider.value(
              value: provider,
              child: NavigationHud(route: provider.currentRoute),
            ),
          ),
        ),
      );

      // Find close/cancel icon button
      final cancelBtn = find.byTooltip('Batalkan Rute');
      expect(cancelBtn, findsOneWidget);

      // Tap cancel icon
      await tester.tap(cancelBtn);
      await tester.pumpAndSettle();

      // Confirmation dialog MUST appear!
      expect(find.text('BATALKAN NAVIGASI RUTE?'), findsOneWidget);
      expect(find.text('LANJUTKAN RUTE'), findsOneWidget);
      expect(find.text('YA, BATALKAN'), findsOneWidget);

      // Route is NOT cancelled yet!
      expect(provider.currentRoute, isNotNull);

      provider.dispose();
    });
  });
}
