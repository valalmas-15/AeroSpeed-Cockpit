import 'package:latlong2/latlong.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:speedometer_app/models/route_model.dart';
import 'package:speedometer_app/services/routing_service.dart';

void main() {
  group('Google Maps Link and Place Parser Tests', () {
    test('Parse direct decimal coordinates', () async {
      final loc = await RoutingService.parseGoogleMapsInput('-7.7956, 110.3695');
      expect(loc, isNotNull);
      expect(loc!.point.latitude, closeTo(-7.7956, 0.001));
      expect(loc.point.longitude, closeTo(110.3695, 0.001));
    });

    test('Parse user shortlink Lippo Plaza Jogja', () async {
      const url = 'https://maps.app.goo.gl/ogaZX9RtjR6vc3F27';
      final loc = await RoutingService.parseGoogleMapsInput(url);
      // ignore: avoid_print
      print('DEBUG SHORTLINK RESULT: title=${loc?.title}, point=${loc?.point}');
      expect(loc, isNotNull);
      expect(loc!.point.latitude, closeTo(-7.783, 0.01));
      expect(loc.point.longitude, closeTo(110.390, 0.01));
      expect(loc.title, contains('Lippo Plaza'));
    });

    test('Search places Lippo Plaza Jogja', () async {
      final results = await RoutingService.searchPlaces('Lippo Plaza Jogja');
      for (var r in results) {
        // ignore: avoid_print
        print('DEBUG SEARCH RESULT: shortName=${r.shortName}, point=${r.point}, displayName=${r.displayName}');
      }
    });

    test('Parse long Google Maps URL with @lat,lon', () async {
      const url = 'https://www.google.com/maps/place/Keraton+Yogyakarta/@-7.805284,110.364203,17z';
      final loc = await RoutingService.parseGoogleMapsInput(url);
      expect(loc, isNotNull);
      expect(loc!.point.latitude, closeTo(-7.805, 0.01));
      expect(loc.point.longitude, closeTo(110.364, 0.01));
      expect(loc.title.toLowerCase(), anyOf(contains('keraton'), contains('karaton')));
    });

    test('Parse Google Maps query URL ?q=lat,lon', () async {
      const url = 'https://www.google.com/maps?q=-7.7520,110.4914';
      final loc = await RoutingService.parseGoogleMapsInput(url);
      expect(loc, isNotNull);
      expect(loc!.point.latitude, closeTo(-7.7520, 0.001));
      expect(loc.point.longitude, closeTo(110.4914, 0.001));
    });

    test('Parse DMS coordinates', () async {
      const dms = "7°47'44.2\"S 110°22'10.2\"E";
      final loc = await RoutingService.parseGoogleMapsInput(dms);
      expect(loc, isNotNull);
      expect(loc!.point.latitude, closeTo(-7.7956, 0.01));
      expect(loc.point.longitude, closeTo(110.3695, 0.01));
    });

    test('Extract place name from mobile share text', () {
      const shareText = "Candi Prambanan\nBokoharjo, Sleman\nhttps://maps.app.goo.gl/abcdef";
      final name = RoutingService.extractPlaceName(shareText);
      expect(name, 'Candi Prambanan');
    });
    test('Distance to polyline test for detour / off-route detection', () {
      final polyline = [
        const LatLng(-7.7800, 110.3600),
        const LatLng(-7.7800, 110.3700),
        const LatLng(-7.7800, 110.3800),
      ];

      // Point directly on segment
      final onLine = const LatLng(-7.7800, 110.3650);
      final distOn = RoutingService.distanceToPolyline(onLine, polyline);
      expect(distOn, lessThan(1.0));

      // Point ~110m north (off-route)
      // 0.001 deg latitude is approximately 111 meters
      final offRoute = const LatLng(-7.7790, 110.3650);
      final distOff = RoutingService.distanceToPolyline(offRoute, polyline);
      expect(distOff, greaterThan(100.0));
      expect(distOff, lessThan(125.0));
    });
  });

  group('Offline Road Routing Engine Tests', () {
    test('Offline route between Tugu and Keraton matches curated road and Malioboro', () async {
      const tugu = LatLng(-7.782889, 110.367072);
      const keraton = LatLng(-7.805284, 110.364203);

      final route = await RoutingService.fetchRoute(
        origin: tugu,
        destination: keraton,
        originName: 'Tugu Pal Putih',
        destinationName: 'Keraton Yogyakarta',
        forceOffline: true,
      );

      expect(route, isNotNull);
      expect(route!.polylinePoints.length, greaterThanOrEqualTo(5));
      expect(route.totalDistanceMeters, closeTo(2650, 250));
      expect(route.steps.any((s) => s.streetName.contains('Malioboro')), isTrue);
      expect(route.steps.any((s) => s.streetName.contains('Margo Utomo')), isTrue);
    });

    test('Offline route between Amplaz and Tugu follows arterial corridors', () async {
      const amplaz = LatLng(-7.7829, 110.4011);
      const tugu = LatLng(-7.782889, 110.367072);

      final route = await RoutingService.fetchRoute(
        origin: amplaz,
        destination: tugu,
        originName: 'Ambarrukmo Plaza',
        destinationName: 'Tugu Pal Putih',
        forceOffline: true,
      );

      print('DEBUG AMPLAZ TO TUGU: dist=${route?.totalDistanceKm}');
      for (var s in route!.steps) {
        print('  Step: ${s.maneuver} -> ${s.instruction} (${s.streetName}), dist=${s.distanceMeters}');
      }

      expect(route, isNotNull);
      expect(route.polylinePoints.length, greaterThan(4));
      expect(route.totalDistanceKm, greaterThan(3.0));
      expect(route.totalDistanceKm, lessThan(8.0));
      expect(route.steps.length, greaterThanOrEqualTo(2));
      expect(
        route.steps.any((s) => s.streetName.contains('Sudirman') || s.streetName.contains('Adisucipto')),
        isTrue,
      );
    });

    test('Offline route for arbitrary custom coordinates follows street grid turns (not straight line)', () async {
      const origin = LatLng(-7.7700, 110.3700);
      const destination = LatLng(-7.7780, 110.3800);

      final route = await RoutingService.fetchRoute(
        origin: origin,
        destination: destination,
        originName: 'Titik A',
        destinationName: 'Titik B',
        forceOffline: true,
      );

      expect(route, isNotNull);
      // Street grid creates turns and curved corner fillets
      expect(route!.polylinePoints.length, greaterThan(6));

      // Verify points do NOT form a direct straight chord
      final straightChord = [origin, destination];
      double maxDeviationFromChord = 0.0;
      for (var pt in route.polylinePoints) {
        final d = RoutingService.distanceToPolyline(pt, straightChord);
        if (d > maxDeviationFromChord) {
          maxDeviationFromChord = d;
        }
      }
      expect(
        maxDeviationFromChord,
        greaterThan(50.0),
        reason: 'Route in offline mode must follow street turns with lateral deviation, not a direct straight line',
      );

      // Check maneuvers include actual street turns
      expect(
        route.steps.any((s) =>
            s.maneuver == ManeuverType.turnRight ||
            s.maneuver == ManeuverType.turnLeft ||
            s.maneuver == ManeuverType.turnSlightRight ||
            s.maneuver == ManeuverType.turnSlightLeft),
        isTrue,
      );
    });

    test('Debug inspect offline route from default position', () async {
      const origin = LatLng(-7.7956, 110.3695);
      const destination = LatLng(-7.782889, 110.367072); // Tugu

      final route = await RoutingService.fetchRoute(
        origin: origin,
        destination: destination,
        originName: 'Posisi Awal',
        destinationName: 'Tugu Pal Putih',
        forceOffline: true,
      );

      print('DEBUG ROUTE POINTS: ${route?.polylinePoints.length}');
      for (int i = 0; i < (route?.polylinePoints.length ?? 0); i++) {
        print('  Point $i: ${route!.polylinePoints[i]}');
      }
      print('DEBUG ROUTE STEPS:');
      for (var s in route!.steps) {
        print('  Step: ${s.maneuver} -> ${s.instruction} (${s.streetName}), dist=${s.distanceMeters}');
      }
    });
  });
}
