import 'package:latlong2/latlong.dart';
import '../services/routing_service.dart';

class ProvinceOfflinePack {
  final String id;
  final String name;
  final String code;
  final double estimatedSizeMb;
  final String version;
  final double minLat;
  final double maxLat;
  final double minLon;
  final double maxLon;
  final LatLng centerPoint;
  final int poiCount;
  final List<RouteSearchResult> offlinePlaces;

  bool isDownloaded;
  bool isDownloading;
  double downloadProgress;
  DateTime? downloadedAt;

  ProvinceOfflinePack({
    required this.id,
    required this.name,
    required this.code,
    required this.estimatedSizeMb,
    required this.version,
    required this.minLat,
    required this.maxLat,
    required this.minLon,
    required this.maxLon,
    required this.centerPoint,
    required this.poiCount,
    required this.offlinePlaces,
    this.isDownloaded = false,
    this.isDownloading = false,
    this.downloadProgress = 0.0,
    this.downloadedAt,
  });

  bool containsLocation(LatLng point) {
    return point.latitude >= minLat &&
        point.latitude <= maxLat &&
        point.longitude >= minLon &&
        point.longitude <= maxLon;
  }

  ProvinceOfflinePack copyWith({
    bool? isDownloaded,
    bool? isDownloading,
    double? downloadProgress,
    DateTime? downloadedAt,
  }) {
    return ProvinceOfflinePack(
      id: id,
      name: name,
      code: code,
      estimatedSizeMb: estimatedSizeMb,
      version: version,
      minLat: minLat,
      maxLat: maxLat,
      minLon: minLon,
      maxLon: maxLon,
      centerPoint: centerPoint,
      poiCount: poiCount,
      offlinePlaces: offlinePlaces,
      isDownloaded: isDownloaded ?? this.isDownloaded,
      isDownloading: isDownloading ?? this.isDownloading,
      downloadProgress: downloadProgress ?? this.downloadProgress,
      downloadedAt: downloadedAt ?? this.downloadedAt,
    );
  }
}

