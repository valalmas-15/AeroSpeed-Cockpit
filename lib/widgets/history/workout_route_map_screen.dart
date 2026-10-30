import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../models/workout_session_model.dart';
import '../../services/offline_routing_engine.dart';
import '../../services/offline_tile_service.dart';
import '../../theme/app_theme.dart';

/// Halaman Tampilan Peta Rute Detail ala Strava untuk Sesi Berkendara yang Disimpan
class WorkoutRouteMapScreen extends StatefulWidget {
  final WorkoutSession session;
  final bool initialDarkMap;
  final VoidCallback? onBack;

  const WorkoutRouteMapScreen({
    super.key,
    required this.session,
    this.initialDarkMap = false,
    this.onBack,
  });

  @override
  State<WorkoutRouteMapScreen> createState() => _WorkoutRouteMapScreenState();
}

class _WorkoutRouteMapScreenState extends State<WorkoutRouteMapScreen> {
  final MapController _mapController = MapController();
  late bool _isDarkMap;
  bool _isFitted = false;

  @override
  void initState() {
    super.initState();
    _isDarkMap = widget.initialDarkMap;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fitBounds();
    });
  }

  void _fitBounds() {
    if (!mounted) return;
    final points = widget.session.routePoints;
    if (points.isNotEmpty) {
      final bounds = LatLngBounds.fromPoints(points);
      final latSpan = (bounds.north - bounds.south).abs();
      final lngSpan = (bounds.east - bounds.west).abs();
      if (latSpan < 0.003 && lngSpan < 0.003) {
        _mapController.move(bounds.center, 15.0);
      } else {
        _mapController.fitCamera(
          CameraFit.bounds(
            bounds: bounds,
            maxZoom: 16.0,
            padding: const EdgeInsets.only(top: 55, bottom: 65, left: 40, right: 40),
          ),
        );
      }
      setState(() => _isFitted = true);
    }
  }

  void _zoomIn() {
    final currentZoom = _mapController.camera.zoom;
    _mapController.move(_mapController.camera.center, min(currentZoom + 1.0, 19.0));
  }

  void _zoomOut() {
    final currentZoom = _mapController.camera.zoom;
    _mapController.move(_mapController.camera.center, max(currentZoom - 1.0, 4.0));
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final points = session.routePoints;
    final hasRoute = points.isNotEmpty;
    final initialCenter = hasRoute
        ? points.first
        : const LatLng(-7.7956, 110.3695); // Default Malioboro / DIY

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (widget.onBack != null) {
          widget.onBack!();
        } else {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0C0D10),
        body: SafeArea(
          child: Stack(
            children: [
              // 0. Tactical Grid Background (Ensures clean contrast even before raster tiles load)
              Positioned.fill(
                child: Container(
                  color: _isDarkMap ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                ),
              ),

              // 1. FlutterMap (Uses downloaded offline map tiles and vector road network)
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: initialCenter,
                  initialZoom: hasRoute ? 15.0 : 13.0,
                  maxZoom: 19.0,
                  minZoom: 4.0,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                  ),
                  onMapReady: () {
                    if (!_isFitted && hasRoute) {
                      _fitBounds();
                    }
                  },
                ),
                children: [
                  // A. Tile Layer with Offline Storage Provider (Day Mode or Dark Mode Matrix)
                  TileLayer(
                    key: ValueKey(_isDarkMap),
                    urlTemplate: 'https://{s}.google.com/vt/lyrs=m&x={x}&y={y}&z={z}',
                    subdomains: const ['mt0', 'mt1', 'mt2', 'mt3'],
                    userAgentPackageName: 'com.speedometer.speedometer_app',
                    maxZoom: 20,
                    maxNativeZoom: 16,
                    tileProvider: OfflineTileService.instance.getTileProvider(),
                    tileBuilder: _isDarkMap
                        ? (context, tileWidget, tile) {
                            return ColorFiltered(
                              colorFilter: const ColorFilter.matrix(<double>[
                                -0.25, -0.50, -0.10, 0, 220,
                                -0.25, -0.50, -0.10, 0, 220,
                                -0.25, -0.50, -0.10, 0, 220,
                                0, 0, 0, 1, 0,
                              ]),
                              child: tileWidget,
                            );
                          }
                        : null,
                  ),

                  // B. Offline Road Network Vector Overlay (Crisp streets from downloaded province data)
                  PolylineLayer(
                    polylines: OfflineRoutingEngine.allRoadEdges.map((edge) {
                      final isRing = edge.roadName.toLowerCase().contains('ring road');
                      return Polyline(
                        points: edge.geometry,
                        strokeWidth: isRing ? 3.0 : 1.8,
                        color: _isDarkMap
                            ? (isRing ? const Color(0xFF94A3B8) : const Color(0xFF475569).withOpacity(0.85))
                            : (isRing ? const Color(0xFF334155) : const Color(0xFF64748B).withOpacity(0.85)),
                        strokeCap: StrokeCap.round,
                        strokeJoin: StrokeJoin.round,
                      );
                    }).toList(),
                  ),

                // C. Recorded Route Polyline (Strava-like glowing neon track)
                if (hasRoute) ...[
                  // Outer contrast border
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: points,
                        strokeWidth: 7.0,
                        color: const Color(0xFF0F172A).withOpacity(0.92),
                        strokeCap: StrokeCap.round,
                        strokeJoin: StrokeJoin.round,
                      ),
                    ],
                  ),
                  // Inner neon cyan / Strava orange line
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: points,
                        strokeWidth: 4.5,
                        color: const Color(0xFF00E5FF),
                        strokeCap: StrokeCap.round,
                        strokeJoin: StrokeJoin.round,
                      ),
                    ],
                  ),
                ],

                // D. Markers: Start & Finish Pins
                if (hasRoute)
                  MarkerLayer(
                    markers: [
                      // Start Marker (Green Pin)
                      Marker(
                        point: points.first,
                        width: 28,
                        height: 28,
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF10B981).withOpacity(0.6),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.play_arrow_rounded,
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
                      ),

                      // Finish Marker (Checkered Red Pin)
                      if (points.length > 1)
                        Marker(
                          point: points.last,
                          width: 28,
                          height: 28,
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFFEF4444),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFEF4444).withOpacity(0.6),
                                  blurRadius: 6,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.flag_rounded,
                              size: 15,
                              color: Colors.white,
                            ),
                          ),
                        ),
                    ],
                  ),
              ],
            ),

            // 2. Floating Top Header (Route Title, Back Button, Theme & Recenter)
            Positioned(
              top: 8,
              left: 10,
              right: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A).withOpacity(0.92),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0xFF00E5FF).withOpacity(0.4),
                    width: 1.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.5),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // Back Button
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: widget.onBack ?? () => Navigator.of(context).pop(),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppTheme.border, width: 0.8),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.arrow_back_rounded, size: 14, color: Color(0xFFCBD5E1)),
                            SizedBox(width: 4),
                            Text(
                              'KEMBALI',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFFCBD5E1),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(width: 10),

                    // Route Name & Coordinates
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.alt_route, size: 13, color: Color(0xFF00E5FF)),
                              const SizedBox(width: 5),
                              Flexible(
                                child: Text(
                                  session.routeName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 1),
                          Text(
                            hasRoute
                                ? '${points.length} Titik GPS • ${session.totalDistanceKm.toStringAsFixed(1)} km • ${session.duration.inMinutes}m'
                                : 'Rute Bebas (${session.totalDistanceKm.toStringAsFixed(1)} km)',
                            style: const TextStyle(fontSize: 8.5, color: Color(0xFF94A3B8)),
                          ),
                        ],
                      ),
                    ),

                    // Day / Night Mode Toggle
                    IconButton(
                      icon: Icon(
                        _isDarkMap ? Icons.wb_sunny_rounded : Icons.nightlight_round,
                        size: 16,
                        color: _isDarkMap ? const Color(0xFFF59E0B) : const Color(0xFF38BDF8),
                      ),
                      tooltip: _isDarkMap ? 'Mode Siang' : 'Mode Malam',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                      onPressed: () => setState(() => _isDarkMap = !_isDarkMap),
                    ),

                    // Recenter Route Bounds Button
                    if (hasRoute)
                      IconButton(
                        icon: const Icon(Icons.center_focus_strong_rounded, size: 16, color: Color(0xFF00E5FF)),
                        tooltip: 'Pusatkan Rute',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                        onPressed: _fitBounds,
                      ),
                  ],
                ),
              ),
            ),

            // 3. Floating Zoom Controls (Right edge)
            Positioned(
              right: 12,
              top: 65,
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A).withOpacity(0.9),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.border.withOpacity(0.5)),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 4),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.add, size: 16, color: Colors.white),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                      onPressed: _zoomIn,
                    ),
                    Container(height: 1, width: 22, color: AppTheme.border.withOpacity(0.4)),
                    IconButton(
                      icon: const Icon(Icons.remove, size: 16, color: Colors.white),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                      onPressed: _zoomOut,
                    ),
                  ],
                ),
              ),
            ),

            // 4. Floating Strava-style Bottom Metrics Strip (Compact landscape HUD)
            Positioned(
              bottom: 6,
              left: 10,
              right: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A).withOpacity(0.95),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0xFF1E293B),
                    width: 1.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.6),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // Jarak
                    Expanded(
                      child: _buildMetricTile(
                        label: 'JARAK',
                        value: session.displayDistance.toStringAsFixed(1),
                        unit: session.distanceUnitLabel,
                        color: const Color(0xFF10B981),
                      ),
                    ),
                    _verticalDivider(),
                    // Durasi
                    Expanded(
                      child: _buildMetricTile(
                        label: 'DURASI',
                        value: session.formattedDuration,
                        unit: '',
                        color: const Color(0xFFA855F7),
                      ),
                    ),
                    _verticalDivider(),
                    // Rata2 Speed
                    Expanded(
                      child: _buildMetricTile(
                        label: 'RATA-RATA',
                        value: session.displayAvgSpeed.toStringAsFixed(1),
                        unit: session.speedUnitLabel,
                        color: const Color(0xFF00E5FF),
                      ),
                    ),
                    _verticalDivider(),
                    // Max Speed
                    Expanded(
                      child: _buildMetricTile(
                        label: 'MAX SPEED',
                        value: session.displayMaxSpeed.toStringAsFixed(0),
                        unit: session.speedUnitLabel,
                        color: const Color(0xFFFF5252),
                      ),
                    ),
                    _verticalDivider(),
                    // Elevasi Gain/Loss
                    Expanded(
                      child: _buildMetricTile(
                        label: 'ELEVASI (+/-)',
                        value: '+${session.displayAscent.round()}/-${session.displayDescent.round()}',
                        unit: session.elevationUnitLabel,
                        color: const Color(0xFF60A5FA),
                      ),
                    ),
                    _verticalDivider(),
                    // Kalori
                    Expanded(
                      child: _buildMetricTile(
                        label: 'KALORI',
                        value: session.calories.round().toString(),
                        unit: 'kcal',
                        color: const Color(0xFFF59E0B),
                      ),
                    ),
                    _verticalDivider(),
                    // Heart Rate
                    Expanded(
                      child: _buildMetricTile(
                        label: 'DETAK JANTUNG',
                        value: session.avgHeartRate > 0 ? '${session.avgHeartRate}' : '--',
                        unit: 'bpm',
                        color: const Color(0xFFEC4899),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

  Widget _verticalDivider() {
    return Container(
      width: 1,
      height: 22,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      color: const Color(0xFF334155).withOpacity(0.5),
    );
  }

  Widget _buildMetricTile({
    required String label,
    required String value,
    required String unit,
    required Color color,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 7.5,
            fontWeight: FontWeight.w800,
            color: Color(0xFF94A3B8),
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 1),
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 12.0,
                fontWeight: FontWeight.w900,
                color: color,
                fontFamily: 'monospace',
              ),
            ),
            if (unit.isNotEmpty) ...[
              const SizedBox(width: 2),
              Text(
                unit,
                style: const TextStyle(
                  fontSize: 7.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF94A3B8),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

