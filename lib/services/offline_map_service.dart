import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/province_offline_model.dart';
import 'offline_tile_service.dart';
import 'routing_service.dart';

class OfflineMapService {
  static final OfflineMapService instance = OfflineMapService._internal();

  OfflineMapService._internal() {
    _initCatalog();
  }

  // Pre-configured Province Catalog in Indonesia
  final Map<String, ProvinceOfflinePack> _provinces = {};
  Map<String, ProvinceOfflinePack> get provinces => Map.unmodifiable(_provinces);

  ProvinceOfflinePack? _currentProvince;
  ProvinceOfflinePack? get currentProvince => _currentProvince;

  bool _isPromptVisible = false;
  bool get isPromptVisible => _isPromptVisible;

  bool _isCheckingInternet = false;
  bool _isOnline = false;
  bool? _mockOnlineStatus;
  bool get isOnline => _mockOnlineStatus ?? _isOnline;

  void setOnlineStatus(bool? value) {
    _mockOnlineStatus = value;
    if (value != null) {
      _isOnline = value;
    }
    _updateNotifier.add(_currentProvince);
  }

  Timer? _periodicCheckTimer;
  Timer? _connectivityTimer;
  final _updateNotifier = StreamController<ProvinceOfflinePack?>.broadcast();
  Stream<ProvinceOfflinePack?> get updateStream => _updateNotifier.stream;

  SharedPreferences? _prefs;

  Future<void> init({bool startPeriodicTimer = false}) async {
    _prefs = await SharedPreferences.getInstance();
    await _loadSavedStatuses();
    if (startPeriodicTimer) {
      startPeriodicDayTimer();
    }
  }

  void startConnectivityMonitoring({Duration interval = const Duration(seconds: 4)}) {
    _connectivityTimer?.cancel();
    _connectivityTimer = Timer.periodic(interval, (_) async {
      await checkInternetConnection();
    });
  }

  void stopConnectivityMonitoring() {
    _connectivityTimer?.cancel();
    _connectivityTimer = null;
  }

  void startPeriodicDayTimer() {
    _periodicCheckTimer?.cancel();
    _periodicCheckTimer = Timer.periodic(const Duration(minutes: 15), (_) async {
      if (_currentProvince != null && !_currentProvince!.isDownloaded) {
        final shouldShow = await shouldShowUpdatePrompt(_currentProvince!);
        if (shouldShow) {
          _updateNotifier.add(_currentProvince);
        }
      }
    });
  }

  void stopPeriodicTimer() {
    _periodicCheckTimer?.cancel();
    _periodicCheckTimer = null;
    stopConnectivityMonitoring();
  }

  Future<void> _loadSavedStatuses() async {
    if (_prefs == null) return;
    for (var key in _provinces.keys) {
      final isDownloaded = _prefs!.getBool('offline_map_downloaded_$key') ?? false;
      final savedVersion = _prefs!.getString('offline_map_version_$key');
      final downloadedAtMs = _prefs!.getInt('offline_map_date_$key');

      final pack = _provinces[key];
      if (pack != null) {
        pack.isDownloaded = isDownloaded && (savedVersion == pack.version);
        if (downloadedAtMs != null) {
          pack.downloadedAt = DateTime.fromMillisecondsSinceEpoch(downloadedAtMs);
        }
      }
    }
  }

  // Detect which province the user is currently located in
  ProvinceOfflinePack detectProvince(LatLng point) {
    // 1. Direct bounding box check
    for (var pack in _provinces.values) {
      if (pack.containsLocation(point)) {
        _currentProvince = pack;
        return pack;
      }
    }

    // 2. Fallback: Find closest province center
    const distanceCalc = Distance();
    ProvinceOfflinePack? closest;
    double minDistance = double.infinity;

    for (var pack in _provinces.values) {
      final d = distanceCalc.as(LengthUnit.Kilometer, point, pack.centerPoint);
      if (d < minDistance) {
        minDistance = d;
        closest = pack;
      }
    }

    _currentProvince = closest ?? _provinces['diy']!;
    return _currentProvince!;
  }

  // Multi-stage probe to verify internet connectivity across all networks
  Future<bool> _probeInternet() async {
    // 1. Android captive portal check (super-fast, HTTP 204 No Content, unblocked worldwide)
    try {
      final res = await http.get(Uri.parse('http://clients3.google.com/generate_204'))
          .timeout(const Duration(milliseconds: 2500));
      if (res.statusCode == 204 || res.statusCode == 200) {
        return true;
      }
    } catch (_) {}

    // 2. Native socket DNS lookup via dart:io
    try {
      final addresses = await InternetAddress.lookup('google.com')
          .timeout(const Duration(milliseconds: 2000));
      if (addresses.isNotEmpty && addresses[0].rawAddress.isNotEmpty) {
        return true;
      }
    } catch (_) {}

    // 3. Direct IP Cloudflare probe (bypasses ISP DNS blocking / DNS-over-HTTPS blocks)
    try {
      final res = await http.get(Uri.parse('https://1.1.1.1'))
          .timeout(const Duration(milliseconds: 2500));
      if (res.statusCode >= 200 && res.statusCode < 400) {
        return true;
      }
    } catch (_) {}

    // 4. Fallback Google homepage probe
    try {
      final res = await http.get(Uri.parse('https://www.google.com'))
          .timeout(const Duration(milliseconds: 2500));
      if (res.statusCode >= 200 && res.statusCode < 400) {
        return true;
      }
    } catch (_) {}

    return false;
  }

  // Check if internet is currently active and reachable
  Future<bool> checkInternetConnection({bool force = false}) async {
    if (_mockOnlineStatus != null) {
      final prev = _isOnline;
      _isOnline = _mockOnlineStatus!;
      if (prev != _isOnline) {
        _updateNotifier.add(_currentProvince);
      }
      return _isOnline;
    }
    if (_isCheckingInternet && !force) return _isOnline;
    _isCheckingInternet = true;
    try {
      final previousStatus = _isOnline;
      final online = await _probeInternet();
      _isOnline = online;
      if (previousStatus != _isOnline) {
        debugPrint("[OfflineMap] Status internet terdeteksi: ${online ? 'ONLINE' : 'OFFLINE'}");
        _updateNotifier.add(_currentProvince);
      }
    } catch (_) {
      final previousStatus = _isOnline;
      _isOnline = false;
      if (previousStatus != false) {
        _updateNotifier.add(_currentProvince);
      }
    } finally {
      _isCheckingInternet = false;
    }
    return _isOnline;
  }

  String get todayKey {
    final now = DateTime.now();
    return "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
  }

  bool isProvinceUpdatedToday(String provinceId) {
    if (_prefs == null) return false;
    final lastUpdated = _prefs!.getString('offline_map_last_updated_date_$provinceId');
    return lastUpdated == todayKey;
  }

  bool isProvinceDismissedToday(String provinceId) {
    if (_prefs == null) return false;
    final lastDismissed = _prefs!.getString('offline_map_dismissed_date_$provinceId');
    return lastDismissed == todayKey;
  }

  // Check whether to show the daily update prompt for the active province
  // Rules:
  // - Belum update hari ini
  // - Belum pernah ditolak hari ini
  // - Terhubung ke internet
  Future<bool> shouldShowUpdatePrompt(ProvinceOfflinePack province) async {
    _prefs = await SharedPreferences.getInstance();

    // 1. Jika hari ini sudah update, tidak usah tampilkan
    if (isProvinceUpdatedToday(province.id)) {
      _isPromptVisible = false;
      return false;
    }

    // 2. Jika hari ini sudah pernah ditolak / ditutup, tidak usah muncul lagi hari ini
    if (isProvinceDismissedToday(province.id)) {
      _isPromptVisible = false;
      return false;
    }

    // 3. Cek koneksi internet: hanya muncul saat terhubung internet
    final online = await checkInternetConnection();
    if (!online) {
      _isPromptVisible = false;
      return false;
    }

    _isPromptVisible = true;
    return true;
  }

  // Reject / Dismiss prompt for today
  Future<void> dismissPrompt(String provinceId) async {
    _prefs = await SharedPreferences.getInstance();
    await _prefs!.setString('offline_map_dismissed_date_$provinceId', todayKey);
    _isPromptVisible = false;
    _updateNotifier.add(_currentProvince);
    debugPrint("[OfflineMap] Prompt for $provinceId dismissed for today ($todayKey).");
  }

  // Download the offline map pack for the province with realistic progress
  Future<void> downloadProvince(
    String provinceId, {
    Function(double progress)? onProgress,
  }) async {
    final pack = _provinces[provinceId];
    if (pack == null) return;

    // Mutlak cek koneksi internet sebelum download
    final hasInternet = await checkInternetConnection(force: true);
    if (!hasInternet) {
      debugPrint("[OfflineMap] Download dibatalkan: Tidak ada koneksi internet!");
      throw Exception('Tidak ada koneksi internet. Sambungkan WiFi atau data seluler untuk mengunduh peta.');
    }

    pack.isDownloading = true;
    pack.downloadProgress = 0.05;
    _updateNotifier.add(pack);

    try {
      // 1. Unduh ubin peta nyata secara persisten ke disk
      await OfflineTileService.instance.downloadTilesForProvince(
        pack,
        onProgress: (p) {
          pack.downloadProgress = p;
          onProgress?.call(p);
          _updateNotifier.add(pack);
        },
      );

      _prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();
      await _prefs!.setString('offline_map_last_updated_date_$provinceId', todayKey);
      await _prefs!.setBool('offline_map_downloaded_$provinceId', true);
      await _prefs!.setString('offline_map_version_$provinceId', pack.version);
      await _prefs!.setInt('offline_map_date_$provinceId', now.millisecondsSinceEpoch);

      pack.isDownloaded = true;
      pack.isDownloading = false;
      pack.downloadProgress = 1.0;
      pack.downloadedAt = now;
      _isPromptVisible = false;

      _updateNotifier.add(pack);
      debugPrint("[OfflineMap] ${pack.name} downloaded successfully! Ready for 100% full offline navigation.");
    } catch (e) {
      pack.isDownloading = false;
      _updateNotifier.add(pack);
      debugPrint("[OfflineMap] Error downloading province: $e");
      rethrow;
    }
  }

  // Delete/remove a downloaded province pack from local offline storage
  Future<void> deleteProvince(String provinceId) async {
    final pack = _provinces[provinceId];
    if (pack == null) return;

    pack.isDownloaded = false;
    pack.isDownloading = false;
    pack.downloadProgress = 0.0;
    pack.downloadedAt = null;

    // Hapus file ubin dari disk
    await OfflineTileService.instance.deleteTilesForProvince(provinceId);

    _prefs = await SharedPreferences.getInstance();
    await _prefs!.remove('offline_map_downloaded_$provinceId');
    await _prefs!.remove('offline_map_version_$provinceId');
    await _prefs!.remove('offline_map_date_$provinceId');
    await _prefs!.remove('offline_map_last_updated_date_$provinceId');

    _updateNotifier.add(pack);
    debugPrint("[OfflineMap] ${pack.name} deleted successfully from offline storage.");
  }

  // Getters for partitioned lists of provinces
  List<ProvinceOfflinePack> get downloadedProvinces =>
      _provinces.values.where((p) => p.isDownloaded).toList();

  List<ProvinceOfflinePack> get availableProvinces =>
      _provinces.values.where((p) => !p.isDownloaded).toList();


  // Search places strictly from offline downloaded database
  List<RouteSearchResult> searchOfflinePlaces(String query, {LatLng? userPos}) {
    final cleanQuery = query.trim().toLowerCase();
    if (cleanQuery.isEmpty) return [];

    const distanceCalc = Distance();
    final List<RouteSearchResult> results = [];

    // Search through downloaded provinces, or current province, or entire catalog if none downloaded yet
    final hasDownloaded = _provinces.values.any((p) => p.isDownloaded);
    final searchablePacks = hasDownloaded
        ? _provinces.values.where((p) => p.isDownloaded || p == _currentProvince)
        : _provinces.values;

    for (var pack in searchablePacks) {
      for (var place in pack.offlinePlaces) {
        if (place.shortName.toLowerCase().contains(cleanQuery) ||
            place.displayName.toLowerCase().contains(cleanQuery) ||
            place.category.toLowerCase().contains(cleanQuery)) {
          double? dist;
          if (userPos != null) {
            dist = distanceCalc.as(LengthUnit.Meter, userPos, place.point) / 1000.0;
          }
          results.add(place.copyWith(distanceKm: dist));
        }
      }
    }

    if (userPos != null) {
      results.sort((a, b) => (a.distanceKm ?? 9999).compareTo(b.distanceKm ?? 9999));
    }

    return results;
  }

  // Initialize offline province catalog with comprehensive Indonesian POIs
  void _initCatalog() {
    // 1. DI Yogyakarta (DIY)
    _provinces['diy'] = ProvinceOfflinePack(
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
      offlinePlaces: [
        const RouteSearchResult(
          shortName: 'Tugu Pal Putih',
          displayName: 'Tugu Pal Putih, Jl. Margo Utomo, Gowongan, Jetis, Kota Yogyakarta',
          category: 'Tourism & Landmarks',
          point: LatLng(-7.782889, 110.367072),
        ),
        const RouteSearchResult(
          shortName: 'Keraton Yogyakarta',
          displayName: 'Keraton Ngayogyakarta Hadiningrat, Panembahan, Kraton, Kota Yogyakarta',
          category: 'Tourism & Landmarks',
          point: LatLng(-7.805284, 110.364203),
        ),
        const RouteSearchResult(
          shortName: 'Jl. Malioboro',
          displayName: 'Jalan Malioboro, Sosromenduran, Gedong Tengen, Kota Yogyakarta',
          category: 'Shopping & Tourism',
          point: LatLng(-7.792841, 110.365823),
        ),
        const RouteSearchResult(
          shortName: 'Titik Nol Kilometer Jogja',
          displayName: 'Titik 0 Km Yogyakarta, Jl. Pangurakan, Ngupasan, Gondomanan',
          category: 'Landmarks',
          point: LatLng(-7.800278, 110.366111),
        ),
        const RouteSearchResult(
          shortName: 'Alun-Alun Kidul (Alkid)',
          displayName: 'Alun-Alun Selatan Yogyakarta, Patehan, Kraton, Kota Yogyakarta',
          category: 'Parks & Squares',
          point: LatLng(-7.8118, 110.3632),
        ),
        const RouteSearchResult(
          shortName: 'Alun-Alun Utara (Lor)',
          displayName: 'Alun-Alun Utara Yogyakarta, Ngupasan, Gondomanan, Kota Yogyakarta',
          category: 'Parks & Squares',
          point: LatLng(-7.8038, 110.3643),
        ),
        const RouteSearchResult(
          shortName: 'Stasiun Tugu Yogyakarta',
          displayName: 'Stasiun Yogyakarta (Tugu), Jl. Ps. Kembang, Sosromenduran',
          category: 'Transport',
          point: LatLng(-7.789167, 110.363333),
        ),
        const RouteSearchResult(
          shortName: 'Stasiun Lempuyangan',
          displayName: 'Stasiun Lempuyangan, Bausasran, Danurejan, Kota Yogyakarta',
          category: 'Transport',
          point: LatLng(-7.7904, 110.3753),
        ),
        const RouteSearchResult(
          shortName: 'Candi Prambanan',
          displayName: 'Taman Wisata Candi Prambanan, Bokoharjo, Prambanan, Sleman',
          category: 'Heritage & Tourism',
          point: LatLng(-7.7520, 110.4914),
        ),
        const RouteSearchResult(
          shortName: 'Universitas Gadjah Mada (UGM)',
          displayName: 'Kampus UGM, Bulaksumur, Caturtunggal, Depok, Sleman',
          category: 'Education',
          point: LatLng(-7.7713, 110.3777),
        ),
        const RouteSearchResult(
          shortName: 'RSUP Dr. Sardjito',
          displayName: 'RSUP Dr. Sardjito, Jl. Kesehatan No.1, Sekip, Sinduadi, Mlati, Sleman',
          category: 'Hospital',
          point: LatLng(-7.7686, 110.3735),
        ),
        const RouteSearchResult(
          shortName: 'Lippo Plaza Jogja',
          displayName: 'Lippo Plaza Jogja, Jl. Laksda Adisucipto No.32-34, Demangan, Gondokusuman',
          category: 'Malls',
          point: LatLng(-7.783276, 110.390645),
        ),
        const RouteSearchResult(
          shortName: 'Pakuwon Mall Jogja (Hartono)',
          displayName: 'Pakuwon Mall Jogja, Jl. Ring Road Utara, Condongcatur, Depok, Sleman',
          category: 'Malls',
          point: LatLng(-7.7592, 110.3995),
        ),
        const RouteSearchResult(
          shortName: 'Plaza Ambarrukmo',
          displayName: 'Plaza Ambarrukmo, Jl. Laksda Adisucipto, Caturtunggal, Depok, Sleman',
          category: 'Malls',
          point: LatLng(-7.7825, 110.4011),
        ),
        const RouteSearchResult(
          shortName: 'Stadion Maguwoharjo',
          displayName: 'Stadion Maguwoharjo, Maguwoharjo, Depok, Sleman',
          category: 'Sports',
          point: LatLng(-7.7495, 110.4287),
        ),
        const RouteSearchResult(
          shortName: 'Stadion Mandala Krida',
          displayName: 'Stadion Mandala Krida, Semaki, Umbulharjo, Kota Yogyakarta',
          category: 'Sports',
          point: LatLng(-7.7958, 110.3908),
        ),
        const RouteSearchResult(
          shortName: 'Pantai Parangtritis',
          displayName: 'Kawasan Wisata Pantai Parangtritis, Kretek, Bantul',
          category: 'Beach & Tourism',
          point: LatLng(-8.0255, 110.3188),
        ),
        const RouteSearchResult(
          shortName: 'Kaliurang (Gunung Merapi)',
          displayName: 'Kawasan Wisata Kaliurang, Hargobinangun, Pakem, Sleman',
          category: 'Nature & Tourism',
          point: LatLng(-7.5975, 110.4289),
        ),
        const RouteSearchResult(
          shortName: 'Bandara YIA Kulon Progo',
          displayName: 'Yogyakarta International Airport (YIA), Temon, Kulon Progo',
          category: 'Airport',
          point: LatLng(-7.9072, 110.0544),
        ),
      ],
    );

    // 2. DKI Jakarta
    _provinces['dki'] = ProvinceOfflinePack(
      id: 'dki',
      name: 'DKI Jakarta',
      code: 'JKT',
      estimatedSizeMb: 88.0,
      version: '2026.10',
      minLat: -6.40,
      maxLat: -6.05,
      minLon: 106.65,
      maxLon: 107.00,
      centerPoint: const LatLng(-6.1754, 106.8272),
      poiCount: 260,
      offlinePlaces: [
        const RouteSearchResult(
          shortName: 'Monas (Monumen Nasional)',
          displayName: 'Monas, Gambir, Kecamatan Gambir, Kota Jakarta Pusat',
          category: 'Tourism & Landmarks',
          point: LatLng(-6.175392, 106.827153),
        ),
        const RouteSearchResult(
          shortName: 'Gelora Bung Karno (GBK)',
          displayName: 'Kompleks Gelora Bung Karno, Senayan, Tanah Abang, Jakarta Pusat',
          category: 'Sports',
          point: LatLng(-6.218521, 106.802341),
        ),
        const RouteSearchResult(
          shortName: 'Bundaran HI',
          displayName: 'Bundaran Hotel Indonesia, Menteng, Jakarta Pusat',
          category: 'Landmarks',
          point: LatLng(-6.194432, 106.823021),
        ),
        const RouteSearchResult(
          shortName: 'Taman Impian Jaya Ancol',
          displayName: 'Kawasan Wisata Ancol, Pademangan, Jakarta Utara',
          category: 'Tourism & Beach',
          point: LatLng(-6.1265, 106.8335),
        ),
        const RouteSearchResult(
          shortName: 'Kota Tua Jakarta',
          displayName: 'Kawasan Wisata Kota Tua, Pinangsia, Tamansari, Jakarta Barat',
          category: 'Heritage & Tourism',
          point: LatLng(-6.1376, 106.8146),
        ),
        const RouteSearchResult(
          shortName: 'Masjid Istiqlal',
          displayName: 'Masjid Istiqlal, Ps. Baru, Sawah Besar, Jakarta Pusat',
          category: 'Religious',
          point: LatLng(-6.1702, 106.8317),
        ),
        const RouteSearchResult(
          shortName: 'Katedral Jakarta',
          displayName: 'Gereja Katedral Jakarta, Jl. Katedral, Ps. Baru, Sawah Besar',
          category: 'Religious',
          point: LatLng(-6.1692, 106.8331),
        ),
        const RouteSearchResult(
          shortName: 'Stasiun Gambir',
          displayName: 'Stasiun Gambir, Gambir, Kecamatan Gambir, Jakarta Pusat',
          category: 'Transport',
          point: LatLng(-6.1767, 106.8306),
        ),
        const RouteSearchResult(
          shortName: 'Grand Indonesia Mall',
          displayName: 'Grand Indonesia, Jl. M.H. Thamrin No.1, Menteng, Jakarta Pusat',
          category: 'Malls',
          point: LatLng(-6.1955, 106.8213),
        ),
        const RouteSearchResult(
          shortName: 'Blok M Square',
          displayName: 'Blok M Square & MRT Hub, Melawai, Kebayoran Baru, Jakarta Selatan',
          category: 'Shopping & Transport',
          point: LatLng(-6.2443, 106.7978),
        ),
      ],
    );

    // 3. Jawa Barat
    _provinces['jabar'] = ProvinceOfflinePack(
      id: 'jabar',
      name: 'Jawa Barat',
      code: 'JBR',
      estimatedSizeMb: 96.0,
      version: '2026.10',
      minLat: -7.85,
      maxLat: -5.90,
      minLon: 106.35,
      maxLon: 108.85,
      centerPoint: const LatLng(-6.9175, 107.6191),
      poiCount: 220,
      offlinePlaces: [
        const RouteSearchResult(
          shortName: 'Gedung Sate',
          displayName: 'Gedung Sate, Citarum, Bandung Wetan, Kota Bandung',
          category: 'Government & Landmarks',
          point: LatLng(-6.9025, 107.6186),
        ),
        const RouteSearchResult(
          shortName: 'Alun-Alun Bandung',
          displayName: 'Alun-Alun Kota Bandung, Jl. Asia Afrika, Balonggede, Regol',
          category: 'Parks & Squares',
          point: LatLng(-6.9218, 107.6071),
        ),
        const RouteSearchResult(
          shortName: 'Jl. Asia Afrika',
          displayName: 'Jalan Asia Afrika, Braga, Sumur Bandung, Kota Bandung',
          category: 'Tourism & Landmarks',
          point: LatLng(-6.9211, 107.6096),
        ),
        const RouteSearchResult(
          shortName: 'Kebun Raya Bogor',
          displayName: 'Kebun Raya Bogor, Paledang, Kecamatan Bogor Tengah, Kota Bogor',
          category: 'Nature & Tourism',
          point: LatLng(-6.5976, 106.7996),
        ),
        const RouteSearchResult(
          shortName: 'Puncak Pass Bogor',
          displayName: 'Kawasan Wisata Puncak, Tugu Selatan, Cisarua, Bogor',
          category: 'Tourism & Mountain',
          point: LatLng(-6.7028, 106.9934),
        ),
        const RouteSearchResult(
          shortName: 'Tangkuban Perahu',
          displayName: 'Taman Wisata Alam Gunung Tangkuban Parahu, Lembang, Bandung Barat',
          category: 'Tourism & Volcano',
          point: LatLng(-6.7596, 107.6098),
        ),
        const RouteSearchResult(
          shortName: 'Sentul International Circuit',
          displayName: 'Sirkuit Sentul, Kadumangu, Babakan Madang, Bogor',
          category: 'Sports & Motorsport',
          point: LatLng(-6.5369, 106.8582),
        ),
      ],
    );

    // 4. Jawa Tengah
    _provinces['jateng'] = ProvinceOfflinePack(
      id: 'jateng',
      name: 'Jawa Tengah',
      code: 'JTG',
      estimatedSizeMb: 92.0,
      version: '2026.10',
      minLat: -8.25,
      maxLat: -6.40,
      minLon: 108.55,
      maxLon: 111.70,
      centerPoint: const LatLng(-6.9667, 110.4167),
      poiCount: 210,
      offlinePlaces: [
        const RouteSearchResult(
          shortName: 'Simpang Lima Semarang',
          displayName: 'Kawasan Simpang Lima, Pleburan, Semarang Selatan, Kota Semarang',
          category: 'Parks & Squares',
          point: LatLng(-6.9904, 110.4229),
        ),
        const RouteSearchResult(
          shortName: 'Lawang Sewu',
          displayName: 'Lawang Sewu, Jl. Pemuda, Sekayu, Semarang Tengah, Kota Semarang',
          category: 'Heritage & Tourism',
          point: LatLng(-6.9840, 110.4110),
        ),
        const RouteSearchResult(
          shortName: 'Candi Borobudur',
          displayName: 'Taman Wisata Candi Borobudur, Borobudur, Magelang',
          category: 'Heritage & Tourism',
          point: LatLng(-7.6079, 110.2038),
        ),
        const RouteSearchResult(
          shortName: 'Keraton Surakarta (Solo)',
          displayName: 'Keraton Kasunanan Surakarta Hadiningrat, Baluwarti, Pasar Kliwon, Surakarta',
          category: 'Heritage & Culture',
          point: LatLng(-7.5777, 110.8280),
        ),
        const RouteSearchResult(
          shortName: 'Stadion Manahan Solo',
          displayName: 'Stadion Manahan, Jl. Adi Sucipto, Manahan, Banjarsari, Surakarta',
          category: 'Sports',
          point: LatLng(-7.5558, 110.8093),
        ),
        const RouteSearchResult(
          shortName: 'Dataran Tinggi Dieng',
          displayName: 'Kawasan Wisata Dataran Tinggi Dieng, Batur, Banjarnegara',
          category: 'Tourism & Mountain',
          point: LatLng(-7.2045, 109.9078),
        ),
      ],
    );

    // 5. Jawa Timur
    _provinces['jatim'] = ProvinceOfflinePack(
      id: 'jatim',
      name: 'Jawa Timur',
      code: 'JTM',
      estimatedSizeMb: 105.0,
      version: '2026.10',
      minLat: -8.85,
      maxLat: -6.70,
      minLon: 110.90,
      maxLon: 114.65,
      centerPoint: const LatLng(-7.2575, 112.7521),
      poiCount: 240,
      offlinePlaces: [
        const RouteSearchResult(
          shortName: 'Tugu Pahlawan Surabaya',
          displayName: 'Tugu Pahlawan, Alun-alun Contong, Bubutan, Surabaya',
          category: 'Tourism & Landmarks',
          point: LatLng(-7.2464, 112.7378),
        ),
        const RouteSearchResult(
          shortName: 'Jembatan Suramadu',
          displayName: 'Jembatan Nasional Suramadu, Tambak Wedi, Kenjeran, Surabaya',
          category: 'Landmarks & Bridge',
          point: LatLng(-7.1991, 112.7801),
        ),
        const RouteSearchResult(
          shortName: 'Gunung Bromo',
          displayName: 'Taman Nasional Bromo Tengger Semeru, Ngadisari, Sukapura, Probolinggo',
          category: 'Nature & Volcano',
          point: LatLng(-7.9425, 112.9530),
        ),
        const RouteSearchResult(
          shortName: 'Alun-Alun Kota Malang',
          displayName: 'Alun-Alun Merdeka Malang, Kauman, Klojen, Kota Malang',
          category: 'Parks & Squares',
          point: LatLng(-7.9826, 112.6308),
        ),
        const RouteSearchResult(
          shortName: 'Jatim Park 1 & 2 Batu',
          displayName: 'Kawasan Wisata Jawa Timur Park, Sisir, Kec. Batu, Kota Batu',
          category: 'Amusement & Tourism',
          point: LatLng(-7.8890, 112.5280),
        ),
      ],
    );

    // 6. Bali
    _provinces['bali'] = ProvinceOfflinePack(
      id: 'bali',
      name: 'Bali',
      code: 'BLI',
      estimatedSizeMb: 52.0,
      version: '2026.10',
      minLat: -8.90,
      maxLat: -8.05,
      minLon: 114.40,
      maxLon: 115.75,
      centerPoint: const LatLng(-8.4095, 115.1889),
      poiCount: 190,
      offlinePlaces: [
        const RouteSearchResult(
          shortName: 'Pantai Kuta',
          displayName: 'Pantai Kuta, Kecamatan Kuta, Kabupaten Badung, Bali',
          category: 'Beach & Tourism',
          point: LatLng(-8.7185, 115.1686),
        ),
        const RouteSearchResult(
          shortName: 'Garuda Wisnu Kencana (GWK)',
          displayName: 'Taman Budaya GWK, Ungasan, Kuta Selatan, Badung',
          category: 'Culture & Tourism',
          point: LatLng(-8.8105, 115.1676),
        ),
        const RouteSearchResult(
          shortName: 'Tanah Lot',
          displayName: 'Pura Tanah Lot, Beraban, Kediri, Kabupaten Tabanan',
          category: 'Heritage & Temple',
          point: LatLng(-8.6212, 115.0868),
        ),
        const RouteSearchResult(
          shortName: 'Uluwatu Temple',
          displayName: 'Pura Luhur Uluwatu, Pecatu, Kuta Selatan, Badung',
          category: 'Heritage & Temple',
          point: LatLng(-8.8291, 115.0849),
        ),
        const RouteSearchResult(
          shortName: 'Ubud Monkey Forest',
          displayName: 'Sacred Monkey Forest Sanctuary, Jl. Monkey Forest, Ubud, Gianyar',
          category: 'Nature & Tourism',
          point: LatLng(-8.5194, 115.2606),
        ),
      ],
    );
  }

  void dispose() {
    _periodicCheckTimer?.cancel();
    _updateNotifier.close();
  }
}
