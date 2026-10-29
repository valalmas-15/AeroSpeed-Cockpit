import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speedometer_app/models/province_offline_model.dart';
import 'package:speedometer_app/providers/dashboard_provider.dart';
import 'package:speedometer_app/services/offline_map_service.dart';
import 'package:speedometer_app/widgets/map/map_panel.dart';
import 'package:speedometer_app/widgets/map/offline_map_banner.dart';
import 'package:speedometer_app/widgets/map/offline_map_dialog.dart';

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

  group('Offline Map Province Detection Tests', () {
    final service = OfflineMapService.instance;

    test('Detects DI Yogyakarta from coordinates', () {
      final jogjaPoint = const LatLng(-7.7956, 110.3695);
      final province = service.detectProvince(jogjaPoint);
      expect(province.id, equals('diy'));
      expect(province.name, contains('Yogyakarta'));
      expect(province.estimatedSizeMb, inInclusiveRange(30.0, 50.0));
    });

    test('Detects DKI Jakarta from coordinates', () {
      final jktPoint = const LatLng(-6.1754, 106.8272);
      final province = service.detectProvince(jktPoint);
      expect(province.id, equals('dki'));
      expect(province.name, contains('Jakarta'));
    });

    test('Detects Jawa Barat from Bandung coordinates', () {
      final bandungPoint = const LatLng(-6.9175, 107.6191);
      final province = service.detectProvince(bandungPoint);
      expect(province.id, equals('jabar'));
      expect(province.name, contains('Jawa Barat'));
    });

    test('Detects Bali from Denpasar coordinates', () {
      final baliPoint = const LatLng(-8.6705, 115.2126);
      final province = service.detectProvince(baliPoint);
      expect(province.id, equals('bali'));
      expect(province.name, contains('Bali'));
    });
  });

  group('Offline Places Search Tests (100% Offline POI)', () {
    final service = OfflineMapService.instance;

    test('Searches Malioboro and Tugu Pal Putih offline', () {
      final results = service.searchOfflinePlaces('malioboro');
      expect(results, isNotEmpty);
      expect(results.first.shortName, contains('Malioboro'));

      final tugu = service.searchOfflinePlaces('tugu');
      expect(tugu.any((p) => p.shortName.contains('Tugu Pal Putih')), isTrue);
    });

    test('Searches Monas and GBK offline', () {
      final monas = service.searchOfflinePlaces('monas');
      expect(monas, isNotEmpty);
      expect(monas.first.shortName, contains('Monas'));

      final gbk = service.searchOfflinePlaces('gbk');
      expect(gbk, isNotEmpty);
      expect(gbk.first.shortName, contains('Gelora Bung Karno'));
    });

    test('Searches Gedung Sate and Borobudur offline', () {
      final sate = service.searchOfflinePlaces('gedung sate');
      expect(sate, isNotEmpty);
      expect(sate.first.shortName, contains('Gedung Sate'));

      final borobudur = service.searchOfflinePlaces('borobudur');
      expect(borobudur, isNotEmpty);
      expect(borobudur.first.shortName, contains('Borobudur'));
    });
  });

  group('Offline Map Daily Update and Dismissal Tests', () {
    test('Dismissing prompt throttles it for today', () async {
      SharedPreferences.setMockInitialValues({});
      final service = OfflineMapService.instance;
      await service.init(startPeriodicTimer: false);

      final diy = service.provinces['diy']!;
      diy.isDownloaded = false;

      // Dismiss prompt for today
      await service.dismissPrompt('diy');

      // Check SharedPreferences directly
      final prefs = await SharedPreferences.getInstance();
      final dismissedDate = prefs.getString('offline_map_dismissed_date_diy');
      expect(dismissedDate, equals(service.todayKey));
      expect(service.isProvinceDismissedToday('diy'), isTrue);

      // shouldShowUpdatePrompt should be false because dismissed today
      final shouldShow = await service.shouldShowUpdatePrompt(diy);
      expect(shouldShow, isFalse);
    });

    test('Province updated today does not show prompt', () async {
      final service = OfflineMapService.instance;
      final today = service.todayKey;

      SharedPreferences.setMockInitialValues({
        'offline_map_last_updated_date_diy': today,
        'offline_map_downloaded_diy': true,
        'offline_map_version_diy': '2026.10',
      });
      await service.init(startPeriodicTimer: false);

      final diy = service.provinces['diy']!;
      expect(service.isProvinceUpdatedToday('diy'), isTrue);

      final shouldShow = await service.shouldShowUpdatePrompt(diy);
      expect(shouldShow, isFalse);
    });

    test('Download simulation completes and marks province updated today', () async {
      SharedPreferences.setMockInitialValues({});
      final service = OfflineMapService.instance;
      await service.init(startPeriodicTimer: false);

      final diy = service.provinces['diy']!;
      diy.isDownloaded = false;

      double lastProgress = 0.0;
      await service.downloadProvince('diy', onProgress: (p) {
        lastProgress = p;
      });

      expect(diy.isDownloaded, isTrue);
      expect(lastProgress, equals(1.0));
      expect(service.isProvinceUpdatedToday('diy'), isTrue);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('offline_map_downloaded_diy'), isTrue);
      expect(prefs.getString('offline_map_last_updated_date_diy'), equals(service.todayKey));
    });

    test('Download fails and throws Exception when offline', () async {
      SharedPreferences.setMockInitialValues({});
      final service = OfflineMapService.instance;
      await service.init(startPeriodicTimer: false);

      final diy = service.provinces['diy']!;
      diy.isDownloaded = false;

      // Set offline status
      service.setOnlineStatus(false);

      expect(
        () async => await service.downloadProvince('diy'),
        throwsA(isA<Exception>()),
      );

      // Verify that pack is NOT marked as downloaded or updated today
      expect(diy.isDownloaded, isFalse);
      expect(service.isProvinceUpdatedToday('diy'), isFalse);
    });
  });

  group('Network Mode (Online vs Offline) Tests', () {
    test('Default cockpit mode is fun and network mode switches properly', () async {
      final provider = DashboardProvider();
      expect(provider.cockpitMode, equals(CockpitMode.fun));
      expect(provider.isFunMode, isTrue);

      // Force internet offline in service
      provider.offlineMapService.setOnlineStatus(false);
      await provider.setNetworkMode(NetworkMode.offline);
      expect(provider.isOfflineMode, isTrue);

      // Attempt to switch to online while internet is not connected -> must fail!
      final result = await provider.setNetworkMode(NetworkMode.online);
      expect(result, isFalse);
      expect(provider.isOfflineMode, isTrue); // Remains offline

      // Simulate internet connection restored
      provider.offlineMapService.setOnlineStatus(true);
      final onlineResult = await provider.setNetworkMode(NetworkMode.online);
      expect(onlineResult, isTrue);
      expect(provider.isOnlineMode, isTrue);

      provider.dispose();
    });
  });

  group('Offline Map Dialog Widget Tests (Confirmation & Daily Popup)', () {
    testWidgets('OfflineMapConfirmUpdateDialog renders confirmation and prevents accidental click', (tester) async {
      final diy = ProvinceOfflinePack(
        id: 'diy',
        name: 'DI Yogyakarta',
        code: 'DIY',
        estimatedSizeMb: 42.5,
        version: '2026.10',
        minLat: -8.25,
        maxLat: -7.50,
        minLon: 110.00,
        maxLon: 110.85,
        centerPoint: const LatLng(-7.7956, 110.3695),
        poiCount: 185,
        offlinePlaces: [],
      );

      final provider = DashboardProvider();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeNotifierProvider.value(
              value: provider,
              child: OfflineMapConfirmUpdateDialog(province: diy),
            ),
          ),
        ),
      );

      expect(find.text('KONFIRMASI PEMBARUAN PETA'), findsOneWidget);
      expect(find.text('BATAL'), findsOneWidget);
      expect(find.text('YA, PERBARUI'), findsOneWidget);
      expect(find.textContaining('DI Yogyakarta'), findsWidgets);

      provider.dispose();
    });

    testWidgets('OfflineMapDailyUpdateDialog renders daily popup', (tester) async {
      final diy = ProvinceOfflinePack(
        id: 'diy',
        name: 'DI Yogyakarta',
        code: 'DIY',
        estimatedSizeMb: 42.5,
        version: '2026.10',
        minLat: -8.25,
        maxLat: -7.50,
        minLon: 110.00,
        maxLon: 110.85,
        centerPoint: const LatLng(-7.7956, 110.3695),
        poiCount: 185,
        offlinePlaces: [],
      );

      final provider = DashboardProvider();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeNotifierProvider.value(
              value: provider,
              child: OfflineMapDailyUpdateDialog(province: diy),
            ),
          ),
        ),
      );

      expect(find.text('PEMBARUAN PETA OFFLINE HARIAN'), findsOneWidget);
      expect(find.text('HARI INI BELUM UPDATE'), findsOneWidget);
      expect(find.text('NANTI / LEWATKAN'), findsOneWidget);
      expect(find.text('PERBARUI SEKARANG'), findsOneWidget);

      provider.dispose();
    });

    testWidgets('OfflineMapConfirmUpdateDialog disables download button and shows warning when offline', (tester) async {
      final diy = ProvinceOfflinePack(
        id: 'diy',
        name: 'DI Yogyakarta',
        code: 'DIY',
        estimatedSizeMb: 42.5,
        version: '2026.10',
        minLat: -8.25,
        maxLat: -7.50,
        minLon: 110.00,
        maxLon: 110.85,
        centerPoint: const LatLng(-7.7956, 110.3695),
        poiCount: 185,
        offlinePlaces: [],
      );

      final provider = DashboardProvider();
      provider.offlineMapService.setOnlineStatus(false);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeNotifierProvider.value(
              value: provider,
              child: OfflineMapConfirmUpdateDialog(province: diy),
            ),
          ),
        ),
      );

      expect(find.text('KONFIRMASI PEMBARUAN PETA'), findsOneWidget);
      expect(find.text('BATAL'), findsOneWidget);
      expect(find.text('OFFLINE (TIDAK BISA UNDUH)'), findsOneWidget);
      expect(find.textContaining('Ponsel sedang offline'), findsOneWidget);

      provider.dispose();
    });

    testWidgets('MapPanel renders TileLayer and offline POI indicators even in offline mode', (tester) async {
      final provider = DashboardProvider();
      await provider.setNetworkMode(NetworkMode.offline);
      expect(provider.isOfflineMode, isTrue);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeNotifierProvider.value(
              value: provider,
              child: const MapPanel(),
            ),
          ),
        ),
      );
      await tester.pump();

      // TileLayer MUST remain in the widget tree so map is visible
      expect(find.byType(TileLayer), findsOneWidget);
      // Offline badge is present
      expect(find.textContaining('OFFLINE'), findsWidgets);

      provider.dispose();
    });
  });

  group('OfflineMapUpdateBanner Widget Tests', () {
    testWidgets('Renders update banner with Unduh and Ingatkan Besok buttons', (tester) async {
      final diy = ProvinceOfflinePack(
        id: 'diy',
        name: 'DI Yogyakarta',
        code: 'DIY',
        estimatedSizeMb: 42.5,
        version: '2026.10',
        minLat: -8.25,
        maxLat: -7.50,
        minLon: 110.00,
        maxLon: 110.85,
        centerPoint: const LatLng(-7.7956, 110.3695),
        poiCount: 185,
        offlinePlaces: [],
      );

      final provider = DashboardProvider();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeNotifierProvider.value(
              value: provider,
              child: OfflineMapUpdateBanner(province: diy),
            ),
          ),
        ),
      );

      expect(find.text('UPDATE PETA OFFLINE'), findsOneWidget);
      expect(find.text('DI Yogyakarta'), findsOneWidget);
      expect(find.text('UNDUH'), findsOneWidget);
      expect(find.text('INGATKAN BESOK'), findsOneWidget);

      provider.dispose();
    });

    testWidgets('Renders progress bar when downloading', (tester) async {
      final diy = ProvinceOfflinePack(
        id: 'diy',
        name: 'DI Yogyakarta',
        code: 'DIY',
        estimatedSizeMb: 42.5,
        version: '2026.10',
        minLat: -8.25,
        maxLat: -7.50,
        minLon: 110.00,
        maxLon: 110.85,
        centerPoint: const LatLng(-7.7956, 110.3695),
        poiCount: 185,
        offlinePlaces: [],
        isDownloading: true,
        downloadProgress: 0.65,
      );

      final provider = DashboardProvider();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeNotifierProvider.value(
              value: provider,
              child: OfflineMapUpdateBanner(province: diy),
            ),
          ),
        ),
      );

      expect(find.text('Mengunduh Peta Offline DI Yogyakarta...'), findsOneWidget);
      expect(find.text('65%'), findsOneWidget);

      provider.dispose();
    });
  });

  group('OfflineMapManagerDialog Widget and Delete Tests', () {
    test('deleteProvince removes downloaded status and clears preferences', () async {
      final service = OfflineMapService.instance;
      service.setOnlineStatus(true);
      await service.init();

      // Set DIY as downloaded
      service.provinces['diy']!.isDownloaded = true;
      expect(service.downloadedProvinces.any((p) => p.id == 'diy'), isTrue);

      // Delete DIY
      await service.deleteProvince('diy');
      expect(service.provinces['diy']!.isDownloaded, isFalse);
      expect(service.downloadedProvinces.any((p) => p.id == 'diy'), isFalse);
      expect(service.availableProvinces.any((p) => p.id == 'diy'), isTrue);
    });

    testWidgets('OfflineMapManagerDialog renders downloaded and available lists with update and delete actions', (tester) async {
      tester.view.physicalSize = const Size(1480, 720);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      SharedPreferences.setMockInitialValues({
        'offline_map_downloaded_diy': true,
        'offline_map_version_diy': '2026.10',
      });

      final service = OfflineMapService.instance;
      service.setOnlineStatus(true);
      await service.init();
      expect(service.provinces['diy']!.isDownloaded, isTrue);

      final provider = DashboardProvider();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeNotifierProvider.value(
              value: provider,
              child: const OfflineMapManagerDialog(),
            ),
          ),
        ),
      );
      await tester.pump();

      // Verify Header
      expect(find.text('DOWNLOAD & KELOLA PETA OFFLINE'), findsOneWidget);

      // Verify Section 1: Peta yang Sudah Didownload
      expect(find.text('PETA YANG SUDAH DIDOWNLOAD'), findsOneWidget);
      expect(find.text('Update'), findsWidgets);
      expect(find.text('Hapus'), findsWidgets);

      // Verify Section 2: Daftar Peta yang Bisa Didownload
      expect(find.text('DAFTAR PETA YANG BISA DIDOWNLOAD'), findsOneWidget);
      expect(find.text('Download'), findsWidgets);

      // Test tapping "Hapus" shows confirmation dialog
      await tester.tap(find.text('Hapus').first);
      await tester.pump();

      expect(find.text('HAPUS PETA OFFLINE?'), findsOneWidget);
      expect(find.text('BATAL'), findsOneWidget);
      expect(find.text('HAPUS PETA'), findsOneWidget);

      // Confirm deletion
      await tester.tap(find.text('HAPUS PETA'));
      await tester.pump();

      // DIY should now be deleted and moved to available list
      expect(service.provinces['diy']!.isDownloaded, isFalse);

      provider.dispose();
    });
  });
}

