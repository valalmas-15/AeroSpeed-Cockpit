import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../models/route_model.dart';
import 'offline_map_service.dart';
import 'offline_routing_engine.dart';

class RouteSearchResult {
  final String displayName;
  final String shortName;
  final String category;
  final LatLng point;
  final double? distanceKm;

  const RouteSearchResult({
    required this.displayName,
    required this.shortName,
    required this.category,
    required this.point,
    this.distanceKm,
  });

  RouteSearchResult copyWith({
    String? displayName,
    String? shortName,
    String? category,
    LatLng? point,
    double? distanceKm,
  }) {
    return RouteSearchResult(
      displayName: displayName ?? this.displayName,
      shortName: shortName ?? this.shortName,
      category: category ?? this.category,
      point: point ?? this.point,
      distanceKm: distanceKm ?? this.distanceKm,
    );
  }

  String get formattedDistance {
    if (distanceKm == null) return '';
    if (distanceKm! < 1.0) {
      return '${(distanceKm! * 1000).round()} m';
    }
    return '${distanceKm!.toStringAsFixed(1)} km';
  }

  String get cyclingTimeEstimate {
    if (distanceKm == null) return '';
    // Average cycling speed ~15 km/h -> 4 minutes per km
    final minutes = (distanceKm! / 15.0 * 60).round().clamp(1, 120);
    return '~$minutes min';
  }
}

class ParsedGmapsLocation {
  final LatLng point;
  final String title;

  const ParsedGmapsLocation({required this.point, required this.title});
}

class RoutingService {

  // Preset Routes (Jogja, Jakarta, Bandung)
  static final List<NavigationRoute> presetRoutes = [
    _buildTuguToKeratonJogjaRoute(),
    _buildMonasToGbkRoute(),
    _buildBundaranHiToAncolRoute(),
    _buildPasteurToGedungSateRoute(),
  ];

  // Cache in-memory hasil destinasi dinamis di sekitar lokasi user
  static List<RouteSearchResult> _cachedNearbyDestinations = [];

  // Rekomendasi dinamis tersimpan (berdasarkan lokasi GPS user saat ini)
  static List<RouteSearchResult> getRecommendationsNear(
    LatLng userPos, {
    String? category,
  }) {
    if (_cachedNearbyDestinations.isEmpty) return [];
    if (category == null || category == 'Semua' || category == 'All') {
      return List<RouteSearchResult>.from(_cachedNearbyDestinations);
    }
    return _cachedNearbyDestinations.where((d) =>
      d.category.toLowerCase().contains(category.toLowerCase()) ||
      category.toLowerCase().contains(d.category.toLowerCase())
    ).toList();
  }

  // 100% DINAMIS: Mencari tempat terkenal & ramah sepeda di sekitar GPS user dalam radius 1 jam gowes (<= 15 km)
  static Future<List<RouteSearchResult>> fetchCyclingDestinationsNear(
    LatLng userPos, {
    String? category,
  }) async {
    const distanceCalc = Distance();
    final List<RouteSearchResult> results = [];
    final seen = <String>{};

    void addCandidate(RouteSearchResult item) {
      final key = item.shortName.toLowerCase().trim();
      if (seen.contains(key) || key.length < 3) return;
      final dist = item.distanceKm ??
          (distanceCalc.as(LengthUnit.Meter, userPos, item.point) / 1000.0);
      // Batasi ketat dalam radius 1 jam bersepeda: 250m s/d 15 km
      if (dist >= 0.25 && dist <= 15.0) {
        seen.add(key);
        results.add(item.copyWith(distanceKm: dist));
      }
    }

    // Query dinamis ke Photon (komoot cycling geospatial engine) untuk tempat terkenal di sekitar koordinat user
    final queries = [
      ('alun-alun', 'Parks & Squares'),
      ('taman', 'Parks & Squares'),
      ('stadion', 'Sports'),
      ('monumen', 'Tourism & Landmarks'),
      ('wisata', 'Tourism & Landmarks'),
      ('mall', 'Malls'),
    ];

    try {
      final futures = queries.map((q) async {
        final queryStr = q.$1;
        final cat = q.$2;
        try {
          final url = Uri.parse(
            'https://photon.komoot.io/api/?q=' + Uri.encodeComponent(queryStr) +
            '&lat=' + userPos.latitude.toString() +
            '&lon=' + userPos.longitude.toString() +
            '&limit=5',
          );
          final res = await http.get(url).timeout(const Duration(seconds: 4));
          if (res.statusCode == 200) {
            final data = json.decode(res.body);
            final features = data['features'] as List? ?? [];
            final items = <RouteSearchResult>[];
            for (var feat in features) {
              final props = feat['properties'] as Map<String, dynamic>? ?? {};
              final name = props['name'] as String?;
              if (name == null || name.trim().length < 3) continue;

              final coords = feat['geometry']?['coordinates'] as List?;
              if (coords == null || coords.length < 2) continue;

              final lon = (coords[0] as num).toDouble();
              final lat = (coords[1] as num).toDouble();
              final p = LatLng(lat, lon);
              final dist = distanceCalc.as(LengthUnit.Meter, userPos, p) / 1000.0;

              if (dist >= 0.25 && dist <= 15.0) {
                final street = props['street'] as String? ?? '';
                final city = props['city'] as String? ?? props['county'] as String? ?? '';
                final fullAddress = [name, street, city].where((s) => s.isNotEmpty).join(', ');

                items.add(RouteSearchResult(
                  shortName: name,
                  displayName: fullAddress,
                  category: cat,
                  point: p,
                  distanceKm: dist,
                ));
              }
            }
            return items;
          }
        } catch (_) {}
        return <RouteSearchResult>[];
      });

      final fetchedLists = await Future.wait(futures);
      for (var list in fetchedLists) {
        for (var item in list) {
          addCandidate(item);
        }
      }
    } catch (_) {}

    // Urutkan dari yang paling dekat
    results.sort((a, b) => (a.distanceKm ?? 999).compareTo(b.distanceKm ?? 999));

    // Perbarui cache dinamis lokasi saat ini
    _cachedNearbyDestinations = List<RouteSearchResult>.from(results);

    // Filter kategori jika dipilih
    if (category != null && category != 'Semua' && category != 'All') {
      return results.where((r) =>
        r.category.toLowerCase().contains(category.toLowerCase()) ||
        category.toLowerCase().contains(r.category.toLowerCase())
      ).toList();
    }

    return results;
  }

  // Dual-Engine Search: Local DB + Photon (biased to user position) + Nominatim
  static Future<List<RouteSearchResult>> searchPlaces(
    String query, {
    LatLng? userPos,
    bool forceOffline = false,
  }) async {
    final cleanQuery = query.trim().toLowerCase();
    if (cleanQuery.isEmpty) return [];

    const distanceCalc = Distance();
    final List<RouteSearchResult> results = [];

    double? calcDist(LatLng p) {
      if (userPos == null) return null;
      return distanceCalc.as(LengthUnit.Meter, userPos, p) / 1000.0;
    }

    void addResult(RouteSearchResult item) {
      final exists = results.any((r) =>
          r.shortName.toLowerCase() == item.shortName.toLowerCase() ||
          (r.point.latitude == item.point.latitude && r.point.longitude == item.point.longitude));
      if (!exists) {
        results.add(item);
      }
    }

    // Step A0: Cari dari Database Tempat Offline (100% Offline POI & Places)
    try {
      final offlineMatches = OfflineMapService.instance.searchOfflinePlaces(cleanQuery, userPos: userPos);
      for (var om in offlineMatches) {
        addResult(om);
      }
    } catch (_) {}

    // In offline mode, skip all network queries immediately
    if (forceOffline) {
      if (userPos != null) {
        results.sort((a, b) => (a.distanceKm ?? 99999).compareTo(b.distanceKm ?? 99999));
      }
      return results;
    }

    // Step A: Cari dari cache destinasi dinamis sekitar user
    for (var dest in _cachedNearbyDestinations) {
      if (dest.shortName.toLowerCase().contains(cleanQuery) ||
          dest.displayName.toLowerCase().contains(cleanQuery) ||
          dest.category.toLowerCase().contains(cleanQuery)) {
        addResult(dest.copyWith(distanceKm: calcDist(dest.point)));
      }
    }

    // Step B1: Query Photon API with Location Biasing
    try {
      String photonUrl = 'https://photon.komoot.io/api/?q=${Uri.encodeComponent(query)}&limit=8';
      if (userPos != null) {
        photonUrl += '&lat=${userPos.latitude}&lon=${userPos.longitude}';
      }

      final response = await http.get(Uri.parse(photonUrl)).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final features = data['features'] as List? ?? [];

        for (var item in features) {
          final props = item['properties'] as Map? ?? {};
          final geom = item['geometry'] as Map? ?? {};
          final coords = geom['coordinates'] as List? ?? [];

          if (coords.length >= 2) {
            final name = props['name'] as String? ?? props['street'] as String? ?? 'Lokasi';
            final city = props['city'] as String? ?? props['county'] as String? ?? props['district'] as String? ?? '';
            final state = props['state'] as String? ?? props['country'] as String? ?? '';
            final fullAddress = [name, city, state].where((s) => s.isNotEmpty).join(', ');

            final lat = (coords[1] as num).toDouble();
            final lon = (coords[0] as num).toDouble();
            final point = LatLng(lat, lon);

            addResult(RouteSearchResult(
              shortName: name,
              displayName: fullAddress,
              category: props['osm_value'] as String? ?? 'Lokasi',
              point: point,
              distanceKm: calcDist(point),
            ));
          }
        }
      }
    } catch (_) {}

    // Step B2: If results are few and userPos was used, also query Photon globally
    if (results.length < 3 && userPos != null) {
      try {
        final globalUrl = Uri.parse('https://photon.komoot.io/api/?q=${Uri.encodeComponent(query)}&limit=6');
        final response = await http.get(globalUrl).timeout(const Duration(seconds: 4));
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final features = data['features'] as List? ?? [];

          for (var item in features) {
            final props = item['properties'] as Map? ?? {};
            final geom = item['geometry'] as Map? ?? {};
            final coords = geom['coordinates'] as List? ?? [];

            if (coords.length >= 2) {
              final name = props['name'] as String? ?? props['street'] as String? ?? 'Lokasi';
              final city = props['city'] as String? ?? props['county'] as String? ?? props['district'] as String? ?? '';
              final state = props['state'] as String? ?? props['country'] as String? ?? '';
              final fullAddress = [name, city, state].where((s) => s.isNotEmpty).join(', ');

              final lat = (coords[1] as num).toDouble();
              final lon = (coords[0] as num).toDouble();
              final point = LatLng(lat, lon);

              addResult(RouteSearchResult(
                shortName: name,
                displayName: fullAddress,
                category: props['osm_value'] as String? ?? 'Lokasi',
                point: point,
                distanceKm: calcDist(point),
              ));
            }
          }
        }
      } catch (_) {}
    }

    // Step C: Fallback to OpenStreetMap Nominatim (safe for Chrome web, no forbidden User-Agent header)
    if (results.length < 3) {
      try {
        final nomUrl = Uri.parse(
          'https://nominatim.openstreetmap.org/search?format=json&q=${Uri.encodeComponent(query)}&limit=6&addressdetails=1',
        );
        final headers = kIsWeb
            ? <String, String>{}
            : {'User-Agent': 'AeroSpeedCockpit/1.0 (contact@aerospeed.app)'};

        final response = await http.get(nomUrl, headers: headers).timeout(const Duration(seconds: 5));
        if (response.statusCode == 200) {
          final List data = json.decode(response.body);
          for (var item in data) {
            final lat = double.parse(item['lat']);
            final lon = double.parse(item['lon']);
            final name = (item['display_name'] as String).split(',').first;
            final full = item['display_name'] as String;
            final point = LatLng(lat, lon);

            addResult(RouteSearchResult(
              shortName: name,
              displayName: full,
              category: item['type'] as String? ?? 'Lokasi',
              point: point,
              distanceKm: calcDist(point),
            ));
          }
        }
      } catch (_) {}
    }

    // Sort by proximity
    if (userPos != null) {
      results.sort((a, b) => (a.distanceKm ?? 99999).compareTo(b.distanceKm ?? 99999));
    }

    return results;
  }



  // Parse Google Maps input (Direct coordinates, URL, share text, or place link)
  static Future<ParsedGmapsLocation?> parseGoogleMapsInput(String input) async {
    final clean = input.trim();
    if (clean.isEmpty) return null;

    // 1. If shortlink (maps.app.goo.gl or goo.gl/maps), resolve target location FIRST
    if (clean.contains('goo.gl') || clean.contains('maps.app')) {
      final urlMatch = RegExp(r'https?://[^\s]+').firstMatch(clean);
      final shortUrl = urlMatch?.group(0);

      if (shortUrl != null) {
        String? resolvedUrl;

        // Try direct redirect on mobile native
        if (!kIsWeb) {
          try {
            final client = http.Client();
            final request = http.Request('GET', Uri.parse(shortUrl))..followRedirects = false;
            final response = await client.send(request);
            resolvedUrl = response.headers['location'];
          } catch (_) {}
        }

        // On Web (or fallback), use CORS unshorten endpoint
        if (resolvedUrl == null || resolvedUrl.isEmpty) {
          try {
            final unshortenUri = Uri.parse('https://unshorten.me/json/' + Uri.encodeComponent(shortUrl));
            final response = await http.get(unshortenUri).timeout(const Duration(seconds: 6));
            if (response.statusCode == 200) {
              final data = json.decode(response.body);
              if (data['success'] == true && data['resolved_url'] != null) {
                resolvedUrl = data['resolved_url'] as String;
              }
            }
          } catch (_) {}
        }

        // Secondary Web Fallback
        if (resolvedUrl == null || resolvedUrl.isEmpty) {
          try {
            final proxyUri = Uri.parse('https://api.allorigins.win/raw?url=' + Uri.encodeComponent(shortUrl));
            final response = await http.get(proxyUri).timeout(const Duration(seconds: 5));
            if (response.statusCode == 200 && response.body.contains('http')) {
              final match = RegExp(r'https?://[^\s"<>]+').firstMatch(response.body);
              if (match != null && match.group(0)!.contains('google.com/maps')) {
                resolvedUrl = match.group(0);
              }
            }
          } catch (_) {}
        }

        if (resolvedUrl != null && resolvedUrl.isNotEmpty) {
          var decodedUrl = Uri.decodeFull(resolvedUrl);
          try {
            decodedUrl = Uri.decodeComponent(decodedUrl);
          } catch (_) {}
          final parsed = await parseGoogleMapsInput(decodedUrl);
          if (parsed != null) return parsed;
        }
      }
    }

    // Normalize URL/text encodings (%21 -> !, %3D -> =, %2B -> +)
    final normalized = clean
        .replaceAll('%21', '!')
        .replaceAll('%3D', '=')
        .replaceAll('%26', '&')
        .replaceAll('%2B', '+');

    final placeName = extractPlaceName(normalized);

    // 2. Direct decimal coordinates: "!3dlat!4dlon" (Google Maps EXACT building / POI pin - Highest Priority)
    final dataRegex = RegExp(r'!3d(-?\d+\.\d+)!4d(-?\d+\.\d+)');
    final dataMatch = dataRegex.firstMatch(normalized);
    if (dataMatch != null) {
      final lat = double.tryParse(dataMatch.group(1)!);
      final lon = double.tryParse(dataMatch.group(2)!);
      if (lat != null && lon != null) {
        return ParsedGmapsLocation(
          point: LatLng(lat, lon),
          title: placeName ?? 'Lokasi Google Maps',
        );
      }
    }

    // 3. Query coordinates: "?q=lat,lon" or "destination=lat,lon" or "ll=lat,lon"
    final paramRegex = RegExp(r'[?&](?:q|query|destination|ll|center)=(-?\d+\.\d+),(-?\d+\.\d+)');
    final paramMatch = paramRegex.firstMatch(normalized);
    if (paramMatch != null) {
      final lat = double.tryParse(paramMatch.group(1)!);
      final lon = double.tryParse(paramMatch.group(2)!);
      if (lat != null && lon != null) {
        return ParsedGmapsLocation(
          point: LatLng(lat, lon),
          title: placeName ?? 'Lokasi Google Maps',
        );
      }
    }

    // 4. If Place Name is extracted, match against Curated Popular Places or Search Places
    // (In Google Maps URLs, @lat,lon is only the viewport camera center which can be
    // kilometers away from the actual building pin. Resolving the place name ensures exact coordinate!)
    if (placeName != null && placeName.length > 2) {
      final cleanName = placeName.toLowerCase();
      // First check cached nearby dynamic places
      final cachedMatch = _cachedNearbyDestinations.cast<RouteSearchResult?>().firstWhere(
            (d) => d != null && (d.shortName.toLowerCase().contains(cleanName) || cleanName.contains(d.shortName.toLowerCase())),
            orElse: () => null,
          );
      if (cachedMatch != null) {
        return ParsedGmapsLocation(
          point: cachedMatch.point,
          title: cachedMatch.shortName,
        );
      }

      // Then search online geocoders
      final searchResults = await searchPlaces(placeName);
      if (searchResults.isNotEmpty) {
        return ParsedGmapsLocation(
          point: searchResults.first.point,
          title: searchResults.first.shortName,
        );
      }
    }

    // 5. Standalone decimal coordinates: "-7.7956, 110.3695" anywhere in text
    final coordRegex = RegExp(r'(-?\d{1,2}\.\d{3,10})\s*,\s*(-?\d{1,3}\.\d{3,10})');
    final coordMatch = coordRegex.firstMatch(normalized);
    if (coordMatch != null) {
      final lat = double.tryParse(coordMatch.group(1)!);
      final lon = double.tryParse(coordMatch.group(2)!);
      if (lat != null && lon != null) {
        return ParsedGmapsLocation(
          point: LatLng(lat, lon),
          title: placeName ?? 'Koordinat (${lat.toStringAsFixed(4)}, ${lon.toStringAsFixed(4)})',
        );
      }
    }

    // 6. DMS coordinates format: 7°47'44.2"S 110°22'10.2"E
    final dmsRegex = RegExp(r"(\d+)°(\d+)'([0-9.]+)[^0-9]*([NSns])[^0-9]*(\d+)°(\d+)'([0-9.]+)[^0-9]*([EWew])");
    final dmsMatch = dmsRegex.firstMatch(normalized);
    if (dmsMatch != null) {
      var lat = int.parse(dmsMatch.group(1)!) +
          int.parse(dmsMatch.group(2)!) / 60.0 +
          double.parse(dmsMatch.group(3)!) / 3600.0;
      if (dmsMatch.group(4)!.toUpperCase() == 'S') lat = -lat;
      var lon = int.parse(dmsMatch.group(5)!) +
          int.parse(dmsMatch.group(6)!) / 60.0 +
          double.parse(dmsMatch.group(7)!) / 3600.0;
      if (dmsMatch.group(8)!.toUpperCase() == 'W') lon = -lon;
      return ParsedGmapsLocation(
        point: LatLng(lat, lon),
        title: placeName ?? 'Koordinat (${lat.toStringAsFixed(4)}, ${lon.toStringAsFixed(4)})',
      );
    }

    // 7. Viewport Camera coordinates: "@lat,lon" (Google Maps map view center - fallback)
    final atRegex = RegExp(r'@(-?\d+\.\d+),(-?\d+\.\d+)');
    final atMatch = atRegex.firstMatch(normalized);
    if (atMatch != null) {
      final lat = double.tryParse(atMatch.group(1)!);
      final lon = double.tryParse(atMatch.group(2)!);
      if (lat != null && lon != null) {
        return ParsedGmapsLocation(
          point: LatLng(lat, lon),
          title: placeName ?? 'Google Maps Coordinates',
        );
      }
    }

    return null;
  }

  // Extract human-readable place name from Google Maps share text or URL
  static String? extractPlaceName(String input) {
    try {
      // A. Text before or around URL (standard in Google Maps mobile share text)
      final withoutUrl = input.replaceAll(RegExp(r'https?://\S+'), '').trim();
      if (withoutUrl.isNotEmpty) {
        final lines = withoutUrl.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
        if (lines.isNotEmpty) {
          final first = lines.first;
          // Filter out if it's just raw numbers/coordinates
          if (!RegExp(r'^-?\d+\.\d+').hasMatch(first) && first.length > 2) {
            return first;
          }
        }
      }

      // B. URL path: /place/Place+Name/ or /search/Place+Name/
      final placeMatch = RegExp(r'/(?:place|search)/([^/@?]+)').firstMatch(input);
      if (placeMatch != null) {
        var raw = placeMatch.group(1)!;
        try {
          raw = Uri.decodeFull(raw);
          raw = Uri.decodeComponent(raw);
        } catch (_) {}
        raw = raw.replaceAll('+', ' ').replaceAll('%20', ' ').replaceAll('%2B', ' ');
        return raw.trim();
      }

      // C. Query param: ?q=Place+Name
      final qMatch = RegExp(r'[?&]q=([^&]+)').firstMatch(input);
      if (qMatch != null) {
        final raw = qMatch.group(1)!;
        if (!RegExp(r'^-?\d+\.\d+').hasMatch(raw)) {
          return Uri.decodeComponent(raw.replaceAll('+', ' '));
        }
      }
    } catch (_) {}
    return null;
  }

  // OSRM Real Routing Engine (Online) + Offline Road Network Engine
  static Future<NavigationRoute?> fetchRoute({
    required LatLng origin,
    required LatLng destination,
    required String originName,
    required String destinationName,
    bool forceOffline = false,
  }) async {
    // 1. Jika mode offline aktif, gunakan engine jaringan jalan offline (mengikuti jalan nyata)
    if (forceOffline) {
      return OfflineRoutingEngine.buildOfflineRoute(
        origin: origin,
        destination: destination,
        originName: originName,
        destinationName: destinationName,
      );
    }

    final url = Uri.parse(
      'https://router.project-osrm.org/route/v1/driving/'
      '${origin.longitude},${origin.latitude};${destination.longitude},${destination.latitude}'
      '?overview=full&geometries=geojson&steps=true',
    );

    try {
      final response = await http.get(url).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['code'] == 'Ok' && (data['routes'] as List).isNotEmpty) {
          final routeData = data['routes'][0];
          final geometry = routeData['geometry'];
          final coords = geometry['coordinates'] as List;

          final polyline = coords.map<LatLng>((c) {
            final lon = (c[0] as num).toDouble();
            final lat = (c[1] as num).toDouble();
            return LatLng(lat, lon);
          }).toList();

          final distance = (routeData['distance'] as num).toDouble();
          final duration = (routeData['duration'] as num).toDouble();

          final steps = <RouteStep>[];
          final legs = routeData['legs'] as List;

          if (legs.isNotEmpty) {
            final legSteps = legs[0]['steps'] as List;
            for (var s in legSteps) {
              final maneuver = s['maneuver'] as Map;
              final maneuverType = maneuver['type'] as String?;
              final modifier = maneuver['modifier'] as String?;
              final name = s['name'] as String? ?? destinationName;
              final stepDist = (s['distance'] as num).toDouble();
              final stepDur = (s['duration'] as num).toDouble();
              final loc = maneuver['location'] as List;
              final stepPoint = LatLng(
                (loc[1] as num).toDouble(),
                (loc[0] as num).toDouble(),
              );

              final mEnum = _parseManeuver(maneuverType, modifier);
              final instruction = _buildInstruction(mEnum, name.isNotEmpty ? name : 'road');

              steps.add(RouteStep(
                instruction: instruction,
                streetName: name.isNotEmpty ? name : 'Road',
                distanceMeters: stepDist,
                durationSeconds: stepDur,
                maneuver: mEnum,
                point: stepPoint,
              ));
            }
          }

          return NavigationRoute(
            originName: originName,
            destinationName: destinationName,
            originPoint: origin,
            destinationPoint: destination,
            polylinePoints: polyline,
            steps: steps,
            totalDistanceMeters: distance,
            totalDurationSeconds: duration,
          );
        }
      }
    } catch (e) {
      debugPrint("OSRM routing error: $e");
    }

    // 2. Fallback cerdas jika koneksi internet terputus saat request online
    return OfflineRoutingEngine.buildOfflineRoute(
      origin: origin,
      destination: destination,
      originName: originName,
      destinationName: destinationName,
    );
  }

  static ManeuverType _parseManeuver(String? type, String? modifier) {
    if (type == 'arrive') return ManeuverType.arrive;
    if (type == 'depart') return ManeuverType.depart;
    if (modifier == 'left' || modifier == 'sharp left') return ManeuverType.turnLeft;
    if (modifier == 'right' || modifier == 'sharp right') return ManeuverType.turnRight;
    if (modifier == 'slight left') return ManeuverType.turnSlightLeft;
    if (modifier == 'slight right') return ManeuverType.turnSlightRight;
    if (modifier == 'u-turn') return ManeuverType.uTurn;
    if (type == 'roundabout' || type == 'rotary') return ManeuverType.roundabout;
    return ManeuverType.straight;
  }

  static String _buildInstruction(ManeuverType maneuver, String streetName) {
    switch (maneuver) {
      case ManeuverType.depart:
        return 'Head towards $streetName';
      case ManeuverType.turnLeft:
        return 'Turn left onto $streetName';
      case ManeuverType.turnRight:
        return 'Turn right onto $streetName';
      case ManeuverType.turnSlightLeft:
        return 'Keep left onto $streetName';
      case ManeuverType.turnSlightRight:
        return 'Keep right onto $streetName';
      case ManeuverType.straight:
        return 'Continue straight on $streetName';
      case ManeuverType.roundabout:
        return 'Enter roundabout towards $streetName';
      case ManeuverType.uTurn:
        return 'Make a U-turn on $streetName';
      case ManeuverType.arrive:
        return 'Arrive at destination: $streetName';
    }
  }

  static NavigationRoute _buildFallbackRoute(
    LatLng origin,
    LatLng destination,
    String originName,
    String destinationName,
  ) {
    return OfflineRoutingEngine.buildOfflineRoute(
      origin: origin,
      destination: destination,
      originName: originName,
      destinationName: destinationName,
    );
  }

  // ---------------- PRESET REALISTIC ROUTES ----------------
  static NavigationRoute _buildTuguToKeratonJogjaRoute() {
    final points = [
      const LatLng(-7.782889, 110.367072), // Tugu Pal Putih Jogja
      const LatLng(-7.789167, 110.363333), // Stasiun Tugu
      const LatLng(-7.792841, 110.365823), // Jl. Malioboro
      const LatLng(-7.800278, 110.366111), // Titik Nol Kilometer
      const LatLng(-7.805284, 110.364203), // Keraton Yogyakarta
    ];

    return NavigationRoute(
      originName: 'Tugu Pal Putih (Yogyakarta)',
      destinationName: 'Keraton Ngayogyakarta Hadiningrat',
      polylinePoints: points,
      steps: [
        RouteStep(
          instruction: 'Head south on Jl. Margo Utomo',
          streetName: 'Jl. Margo Utomo',
          distanceMeters: 750,
          durationSeconds: 110,
          maneuver: ManeuverType.depart,
          point: points[0],
        ),
        RouteStep(
          instruction: 'Continue straight to Jl. Malioboro',
          streetName: 'Jl. Malioboro',
          distanceMeters: 1100,
          durationSeconds: 180,
          maneuver: ManeuverType.straight,
          point: points[2],
        ),
        RouteStep(
          instruction: 'Pass through Zero Kilometer Point to Jl. Pangurakan',
          streetName: 'Jl. Pangurakan',
          distanceMeters: 600,
          durationSeconds: 90,
          maneuver: ManeuverType.straight,
          point: points[3],
        ),
        RouteStep(
          instruction: 'Arrive at Yogyakarta Palace Main Gate',
          streetName: 'Plataran Keraton',
          distanceMeters: 200,
          durationSeconds: 40,
          maneuver: ManeuverType.arrive,
          point: points[4],
        ),
      ],
      totalDistanceMeters: 2650,
      totalDurationSeconds: 420,
    );
  }

  static NavigationRoute _buildMonasToGbkRoute() {
    final points = [
      const LatLng(-6.175392, 106.827153), // Monas
      const LatLng(-6.182245, 106.824982), // Jl. MH Thamrin
      const LatLng(-6.189563, 106.823908), // Sarinah
      const LatLng(-6.194432, 106.823021), // Bundaran HI
      const LatLng(-6.203341, 106.821453), // Dukuh Atas
      const LatLng(-6.208821, 106.819876), // Karet Sudirman
      const LatLng(-6.215543, 106.814232), // Semanggi
      const LatLng(-6.218521, 106.802341), // GBK Senayan
    ];

    return NavigationRoute(
      originName: 'Monas (Jakarta Pusat)',
      destinationName: 'Gelora Bung Karno (Senayan)',
      polylinePoints: points,
      steps: [
        RouteStep(
          instruction: 'Mulai ke arah selatan di Jl. Medan Merdeka Barat',
          streetName: 'Jl. Medan Merdeka Barat',
          distanceMeters: 800,
          durationSeconds: 120,
          maneuver: ManeuverType.depart,
          point: points[0],
        ),
        RouteStep(
          instruction: 'Lurus terus melewati Bundaran HI ke Jl. Jend. Sudirman',
          streetName: 'Jl. Jenderal Sudirman',
          distanceMeters: 2400,
          durationSeconds: 320,
          maneuver: ManeuverType.straight,
          point: points[3],
        ),
        RouteStep(
          instruction: 'Ambil jalur kanan menuju Simpang Susun Semanggi',
          streetName: 'Semanggi Flyover',
          distanceMeters: 950,
          durationSeconds: 150,
          maneuver: ManeuverType.turnRight,
          point: points[6],
        ),
        RouteStep(
          instruction: 'Tiba di Gelora Bung Karno Senayan',
          streetName: 'GBK Gate 1',
          distanceMeters: 300,
          durationSeconds: 60,
          maneuver: ManeuverType.arrive,
          point: points[7],
        ),
      ],
      totalDistanceMeters: 7400,
      totalDurationSeconds: 840,
    );
  }

  static NavigationRoute _buildBundaranHiToAncolRoute() {
    final points = [
      const LatLng(-6.194432, 106.823021), // Bundaran HI
      const LatLng(-6.175392, 106.827153), // Monas
      const LatLng(-6.160124, 106.829124), // Harmoni
      const LatLng(-6.138452, 106.826543), // Glodok / Kota Tua
      const LatLng(-6.126543, 106.833452), // Ancol Taman Impian
    ];

    return NavigationRoute(
      originName: 'Bundaran HI',
      destinationName: 'Taman Impian Jaya Ancol',
      polylinePoints: points,
      steps: [
        RouteStep(
          instruction: 'Arah utara di Jl. M.H. Thamrin menuju Monas',
          streetName: 'Jl. M.H. Thamrin',
          distanceMeters: 2100,
          durationSeconds: 280,
          maneuver: ManeuverType.depart,
          point: points[0],
        ),
        RouteStep(
          instruction: 'Lurus ke Jl. Gajah Mada melalui Kota Tua',
          streetName: 'Jl. Gajah Mada',
          distanceMeters: 3500,
          durationSeconds: 420,
          maneuver: ManeuverType.straight,
          point: points[2],
        ),
        RouteStep(
          instruction: 'Belok kanan ke Gerbang Ancol Barat',
          streetName: 'Jl. Lodan Raya',
          distanceMeters: 1200,
          durationSeconds: 180,
          maneuver: ManeuverType.turnRight,
          point: points[4],
        ),
      ],
      totalDistanceMeters: 9200,
      totalDurationSeconds: 1100,
    );
  }

  static NavigationRoute _buildPasteurToGedungSateRoute() {
    final points = [
      const LatLng(-6.893245, 107.575643), // Pasteur Toll Exit
      const LatLng(-6.899543, 107.595432), // Jl. Dr. Djunjunan
      const LatLng(-6.901234, 107.608765), // Cihampelas
      const LatLng(-6.902534, 107.618645), // Gedung Sate Bandung
    ];

    return NavigationRoute(
      originName: 'Gerbang Tol Pasteur',
      destinationName: 'Gedung Sate Bandung',
      polylinePoints: points,
      steps: [
        RouteStep(
          instruction: 'Lurus di Flyover Pasupati menuju Jl. Surapati',
          streetName: 'Flyover Pasupati',
          distanceMeters: 2800,
          durationSeconds: 300,
          maneuver: ManeuverType.depart,
          point: points[0],
        ),
        RouteStep(
          instruction: 'Belok kanan ke Jl. Diponegoro Gedung Sate',
          streetName: 'Jl. Diponegoro',
          distanceMeters: 600,
          durationSeconds: 100,
          maneuver: ManeuverType.turnRight,
          point: points[3],
        ),
      ],
      totalDistanceMeters: 4800,
      totalDurationSeconds: 620,
    );
  }

  /// Hitung jarak terpendek (meter) dari posisi kendaraan ke polyline rute
  static double distanceToPolyline(LatLng point, List<LatLng> polyline) {
    if (polyline.isEmpty) return double.infinity;
    if (polyline.length == 1) {
      return const Distance().as(LengthUnit.Meter, point, polyline.first);
    }

    const distanceCalc = Distance();
    double minDistance = double.infinity;

    for (int i = 0; i < polyline.length - 1; i++) {
      final a = polyline[i];
      final b = polyline[i + 1];

      final dx = b.longitude - a.longitude;
      final dy = b.latitude - a.latitude;
      final segLenSq = dx * dx + dy * dy;

      if (segLenSq == 0) {
        final d = distanceCalc.as(LengthUnit.Meter, point, a);
        if (d < minDistance) minDistance = d;
        continue;
      }

      final t = (((point.longitude - a.longitude) * dx +
                  (point.latitude - a.latitude) * dy) /
              segLenSq)
          .clamp(0.0, 1.0);

      final closest = LatLng(a.latitude + t * dy, a.longitude + t * dx);
      final d = distanceCalc.as(LengthUnit.Meter, point, closest);
      if (d < minDistance) {
        minDistance = d;
      }
    }

    return minDistance;
  }
}

extension ScopeLet<T> on T {
  R let<R>(R Function(T it) block) => block(this);
}
