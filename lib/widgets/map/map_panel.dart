import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../../models/route_model.dart';
import '../../providers/dashboard_provider.dart';
import '../../services/offline_routing_engine.dart';
import '../../services/offline_tile_service.dart';
import '../../theme/app_theme.dart';
import 'navigation_hud.dart';
import 'offline_map_banner.dart';
import 'offline_map_dialog.dart';
import 'route_search_dialog.dart';

class MapPanel extends StatefulWidget {
  final bool isFullScreen;

  const MapPanel({super.key, this.isFullScreen = false});

  @override
  State<MapPanel> createState() => _MapPanelState();
}

class _MapPanelState extends State<MapPanel> {
  final MapController _mapController = MapController();
  bool _autoFollow = true;
  LatLng? _selectedPointOnMap;
  bool _isSelectingOnMapMode = false;
  final Distance _distanceCalc = const Distance();
  int _lastHandledRerouteCount = 0;
  bool _hasShownDailyPopupThisSession = false;

  void _fitRouteBounds(NavigationRoute route) {
    if (route.polylinePoints.isEmpty) return;
    try {
      final points = List<LatLng>.from(route.polylinePoints);
      if (route.destinationPoint != null) {
        points.add(route.destinationPoint!);
      }
      if (route.originPoint != null) {
        points.add(route.originPoint!);
      }
      final bounds = LatLngBounds.fromPoints(points);
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: bounds,
          padding: const EdgeInsets.only(top: 60, bottom: 40, left: 35, right: 35),
        ),
      );
      setState(() => _autoFollow = false);
    } catch (_) {}
  }

  void _activateMapPickerMode() {
    context.read<DashboardProvider>().setMapFullScreen(true);
    setState(() {
      _isSelectingOnMapMode = true;
      _autoFollow = false;
      try {
        _selectedPointOnMap = _mapController.camera.center;
      } catch (_) {
        _selectedPointOnMap = context.read<DashboardProvider>().currentPosition;
      }
    });
  }

  void _exitMapPickerMode() {
    final provider = context.read<DashboardProvider>();
    provider.setMapFullScreen(false);
    setState(() {
      _isSelectingOnMapMode = false;
      _selectedPointOnMap = null;
      _autoFollow = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        final h = provider.isHeadingUp ? -provider.currentHeading : 0.0;
        _mapController.moveAndRotate(provider.currentPosition, 16.5, h);
      } catch (_) {}
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DashboardProvider>();
    final position = provider.currentPosition;
    final heading = provider.currentHeading;
    final route = provider.currentRoute;
    final isFullScreen = widget.isFullScreen || provider.isMapFullScreen;

    // 1. Reroute Handler: immediately lock focus onto user location without zooming out or shifting!
    if (provider.rerouteCount > _lastHandledRerouteCount) {
      _lastHandledRerouteCount = provider.rerouteCount;
      _autoFollow = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        try {
          final h = provider.isHeadingUp ? -heading : 0.0;
          _mapController.moveAndRotate(position, 16.5, h);
        } catch (_) {}
      });
    } else if (route != null && !provider.isRouteInitialFitted) {
      // Auto-fit route bounds ONLY when a brand-new route is initially selected
      provider.markRouteFitted();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _fitRouteBounds(route);
      });
    }

    // 2. Auto-center and align map orientation if autoFollow is enabled
    if (_autoFollow && !_isSelectingOnMapMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        try {
          final targetZoom = _mapController.camera.zoom;
          final targetRotation = provider.isHeadingUp ? -heading : 0.0;
          _mapController.moveAndRotate(position, targetZoom, targetRotation);
        } catch (_) {}
      });
    }

    // 3. Daily Offline Map Update Popup Check (Auto popup once per day if not updated)
    if (provider.shouldShowOfflinePrompt &&
        provider.currentProvince != null &&
        !_hasShownDailyPopupThisSession) {
      _hasShownDailyPopupThisSession = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted &&
            context.read<DashboardProvider>().shouldShowOfflinePrompt &&
            context.read<DashboardProvider>().currentProvince != null) {
          OfflineMapDailyUpdateDialog.show(
            context,
            context.read<DashboardProvider>().currentProvince!,
          );
        }
      });
    } else if (!provider.shouldShowOfflinePrompt) {
      _hasShownDailyPopupThisSession = false;
    }

    return Container(
      decoration: AppTheme.glassCard(radius: 12),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Tactical Cockpit Canvas Background (ensures map area is styled even when offline or un-cached)
          Positioned.fill(
            child: Container(
              color: provider.isDarkMap ? const Color(0xFF0C1017) : const Color(0xFFF1F5F9),
              child: CustomPaint(
                painter: _TacticalGridPainter(isDark: provider.isDarkMap),
              ),
            ),
          ),

          // 1. Interactive Flutter Map
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: position,
              initialZoom: 16.0,
              initialRotation: provider.isHeadingUp ? -heading : 0.0,
              minZoom: 4,
              maxZoom: 19,
              onTap: (tapPosition, point) {
                setState(() {
                  _selectedPointOnMap = point;
                  _isSelectingOnMapMode = true;
                  _autoFollow = false;
                });
                context.read<DashboardProvider>().setMapFullScreen(true);
              },
              onPositionChanged: (cam, hasGesture) {
                if (hasGesture) {
                  if (_autoFollow) setState(() => _autoFollow = false);
                  if (_isSelectingOnMapMode) {
                    setState(() => _selectedPointOnMap = cam.center);
                  }
                }
              },
            ),
            children: [
              // Navigation Map Layer (Day Mode by Default or Dark Mode)
              // Uses PersistentCachedTileProvider which reads directly from local disk when offline!
              TileLayer(
                key: ValueKey(provider.isDarkMap),
                urlTemplate: 'https://{s}.google.com/vt/lyrs=m&x={x}&y={y}&z={z}',
                subdomains: const ['mt0', 'mt1', 'mt2', 'mt3'],
                userAgentPackageName: 'com.speedometer.speedometer_app',
                maxZoom: 20,
                maxNativeZoom: 16,
                tileProvider: OfflineTileService.instance.getTileProvider(),
                tileBuilder: provider.isDarkMap
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

              // Offline Road Network Vector Layer (Visible even on cold boot offline without raster tiles!)
              if (provider.isOfflineMode || provider.currentProvince?.isDownloaded == true) ...[
                PolylineLayer(
                  polylines: OfflineRoutingEngine.allRoadEdges.map((edge) {
                    final isRingRoad = edge.roadName.toLowerCase().contains('ring road');
                    return Polyline(
                      points: edge.geometry,
                      strokeWidth: isRingRoad ? 3.0 : 1.8,
                      color: provider.isDarkMap
                          ? (isRingRoad ? const Color(0xFF64748B) : const Color(0xFF475569).withOpacity(0.85))
                          : (isRingRoad ? const Color(0xFF94A3B8) : const Color(0xFFCBD5E1).withOpacity(0.85)),
                      strokeCap: StrokeCap.round,
                      strokeJoin: StrokeJoin.round,
                    );
                  }).toList(),
                ),
              ],

              // Polyline Layer for Route Navigation
              if (route != null && route.polylinePoints.isNotEmpty) ...[
                // Outer High-Contrast Dark Outline
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: route.polylinePoints,
                      strokeWidth: 7,
                      color: const Color(0xFF0F172A).withOpacity(0.95),
                      strokeCap: StrokeCap.round,
                      strokeJoin: StrokeJoin.round,
                    ),
                  ],
                ),
                // Inner Solid Route Polyline
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: route.polylinePoints,
                      strokeWidth: 4.0,
                      color: provider.isFunMode
                          ? const Color(0xFF00E5FF)
                          : (provider.isDarkMap ? const Color(0xFFFFFFFF) : const Color(0xFF2563EB)),
                      strokeCap: StrokeCap.round,
                      strokeJoin: StrokeJoin.round,
                    ),
                  ],
                ),
              ],

              // Marker Layer (Start, Destination, Vehicle, Fixed Target Pin)
              MarkerLayer(
                markers: [
                  // Start Pin (Compact 18x18 Dot)
                  if (route != null && route.polylinePoints.isNotEmpty)
                    Marker(
                      point: route.polylinePoints.first,
                      width: 18,
                      height: 18,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: provider.isFunMode ? const Color(0xFF10B981) : const Color(0xFFFFFFFF),
                          border: Border.all(color: const Color(0xFF0F172A), width: 1.5),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 3),
                          ],
                        ),
                        child: const Icon(Icons.trip_origin, size: 8, color: Color(0xFF0F172A)),
                      ),
                    ),

                  // Destination Pin with Compact Badge (Reduced size to prevent overlap)
                  if (route != null)
                    Marker(
                      point: route.destinationPoint ?? route.polylinePoints.last,
                      width: 105,
                      height: 38,
                      alignment: Alignment.topCenter,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF14171E),
                              borderRadius: BorderRadius.circular(5),
                              boxShadow: [
                                BoxShadow(color: Colors.black.withOpacity(0.6), blurRadius: 4),
                              ],
                              border: Border.all(
                                color: provider.isFunMode ? const Color(0xFFFF5252) : const Color(0xFFFFFFFF),
                                width: 1.0,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.flag,
                                  size: 10,
                                  color: provider.isFunMode ? const Color(0xFFFF5252) : Colors.white,
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    route.destinationName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.location_on,
                            size: 18,
                            color: provider.isFunMode ? const Color(0xFFFF5252) : const Color(0xFFFFFFFF),
                          ),
                        ],
                      ),
                    ),

                  // Tapped Pin on Map (when not in center reticle mode)
                  if (_selectedPointOnMap != null && !_isSelectingOnMapMode)
                    Marker(
                      point: _selectedPointOnMap!,
                      width: 24,
                      height: 24,
                      child: const Icon(Icons.location_on, size: 22, color: Color(0xFFCBD5E1)),
                    ),

                  // User Vehicle Marker (Compact 36x36 Arrow Marker)
                  Marker(
                    point: position,
                    width: 36,
                    height: 36,
                    rotate: true,
                    child: _buildVehicleMarker(heading, provider.isHeadingUp, provider.isFunMode),
                  ),

                  // Offline Curated POI Pins (Show downloaded offline places directly on map!)
                  if (provider.isOfflineMode && provider.currentProvince != null)
                    ...provider.currentProvince!.offlinePlaces.take(30).map(
                      (poi) => Marker(
                        point: poi.point,
                        width: 80,
                        height: 32,
                        alignment: Alignment.topCenter,
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedPointOnMap = poi.point;
                            });
                            ScaffoldMessenger.of(context).hideCurrentSnackBar();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('📍 ${poi.shortName} • ${poi.category}'),
                                duration: const Duration(seconds: 2),
                                backgroundColor: const Color(0xFF1E293B),
                              ),
                            );
                          },
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0F172A).withOpacity(0.92),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: provider.isFunMode ? const Color(0xFF00E5FF) : const Color(0xFFCBD5E1),
                                    width: 0.8,
                                  ),
                                ),
                                child: Text(
                                  poi.shortName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 8.0,
                                    fontWeight: FontWeight.w700,
                                    color: provider.isFunMode ? const Color(0xFF00E5FF) : Colors.white,
                                  ),
                                ),
                              ),
                              Icon(
                                Icons.location_on,
                                size: 14,
                                color: provider.isFunMode ? const Color(0xFF00E5FF) : const Color(0xFFCBD5E1),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),

          // 2. Center Crosshair Reticle / Pin (When in Map Picker Mode)
          if (_isSelectingOnMapMode)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.surface.withOpacity(0.95),
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(color: const Color(0xFFFFFFFF), width: 0.8),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 4),
                        ],
                      ),
                      child: const Text(
                        'GESER PETA KE TUJUAN',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFFFFFFFF),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Icon(
                      Icons.location_pin,
                      size: 28,
                      color: Color(0xFFFFFFFF),
                      shadows: [
                        BoxShadow(color: Colors.black, blurRadius: 6, offset: Offset(0, 1)),
                      ],
                    ),
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black.withOpacity(0.5),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // 3. Navigation HUD Overlay (Top) - shown when not in map picker mode
          if (!_isSelectingOnMapMode)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: NavigationHud(route: route),
            ),

          // 3b. Offline Map Update Notification Banner (Top) - shown when new offline province update is available
          if (!_isSelectingOnMapMode && provider.shouldShowOfflinePrompt && provider.currentProvince != null)
            Positioned(
              top: route != null ? 40 : 0,
              left: 0,
              right: 0,
              child: OfflineMapUpdateBanner(province: provider.currentProvince!),
            ),

          // 4. Floating Mini Speedometer Pill in Fullscreen Mode (Top-Left)
          if (isFullScreen && !_isSelectingOnMapMode)
            Positioned(
              top: 6,
              left: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF0C0D10).withOpacity(0.9),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppTheme.border, width: 0.8),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 4),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.speed,
                      size: 13,
                      color: provider.isFunMode ? const Color(0xFF00E5FF) : Colors.white,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      provider.speedData.displaySpeed.toStringAsFixed(1),
                      style: const TextStyle(
                        fontSize: 12.0,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        fontFamily: 'monospace',
                      ),
                    ),
                    const SizedBox(width: 3),
                    Text(
                      provider.speedData.unitLabel,
                      style: const TextStyle(
                        fontSize: 9.0,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // 4b. Floating Offline Mode Pill (Bottom-Left)
          if (provider.isOfflineMode && !_isSelectingOnMapMode)
            Positioned(
              bottom: 6,
              left: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A).withOpacity(0.92),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: provider.isFunMode ? const Color(0xFF00E5FF).withOpacity(0.6) : const Color(0xFF64748B),
                    width: 0.8,
                  ),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 4),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.cloud_off,
                      size: 10,
                      color: provider.isFunMode ? const Color(0xFF00E5FF) : const Color(0xFF94A3B8),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      provider.currentProvince != null && provider.currentProvince!.isDownloaded
                          ? 'OFFLINE • ${provider.currentProvince!.name} (${provider.currentProvince!.poiCount}+ POI)'
                          : 'MODE OFFLINE',
                      style: TextStyle(
                        fontSize: 8.5,
                        fontWeight: FontWeight.w800,
                        color: provider.isFunMode ? const Color(0xFF00E5FF) : const Color(0xFFE2E8F0),
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // 5. Floating Banner when in Map Picker Mode (Top)
          if (_isSelectingOnMapMode)
            Positioned(
              top: 6,
              left: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.surface.withOpacity(0.96),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.border, width: 0.8),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 8),
                  ],
                ),
                child: Row(
                  children: [
                    InkWell(
                      onTap: _exitMapPickerMode,
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceElevated,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppTheme.border, width: 0.8),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.arrow_back, size: 13, color: Colors.white),
                            SizedBox(width: 3),
                            Text(
                              'KEMBALI',
                              style: TextStyle(fontSize: 10.0, fontWeight: FontWeight.w800, color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Pilih Titik di Peta: Geser peta atau sentuh untuk menentukan tujuan',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 15, color: AppTheme.textMuted),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
                      onPressed: _exitMapPickerMode,
                    ),
                  ],
                ),
              ),
            ),

          // 6. Floating Bottom Card to Confirm Destination
          if (_isSelectingOnMapMode || _selectedPointOnMap != null)
            Positioned(
              bottom: 6,
              left: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.surface.withOpacity(0.97),
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: AppTheme.border, width: 1.0),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.6), blurRadius: 10),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceElevated,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppTheme.border, width: 0.8),
                      ),
                      child: const Icon(Icons.pin_drop, size: 15, color: Color(0xFFFFFFFF)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'TITIK TUJUAN TERPILIH',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 9.0,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFFFFFFFF),
                              letterSpacing: 0.3,
                            ),
                          ),
                          Text(
                            '${(_selectedPointOnMap ?? position).latitude.toStringAsFixed(4)}, ${(_selectedPointOnMap ?? position).longitude.toStringAsFixed(4)} • ± ${((_distanceCalc.as(LengthUnit.Meter, position, _selectedPointOnMap ?? position)) / 1000).toStringAsFixed(1)} km',
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.textPrimary,
                              fontFamily: 'monospace',
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () async {
                        final target = _selectedPointOnMap ?? position;
                        _exitMapPickerMode();
                        await provider.setCustomRoute(
                          provider.currentPosition,
                          target,
                          'Posisi Terkini',
                          'Titik Pilihan Peta',
                        );
                        // Ensure camera locks onto user location
                        setState(() => _autoFollow = true);
                        try {
                          final h = provider.isHeadingUp ? -provider.currentHeading : 0.0;
                          _mapController.moveAndRotate(provider.currentPosition, 16.5, h);
                        } catch (_) {}
                      },
                      icon: const Icon(Icons.navigation, size: 13),
                      label: const Text('MULAI RUTE', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w900)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFFFFFF),
                        foregroundColor: const Color(0xFF0C0D10),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        minimumSize: const Size(80, 28),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.close, size: 15, color: AppTheme.textMuted),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                      onPressed: _exitMapPickerMode,
                    ),
                  ],
                ),
              ),
            ),

          // 7. Floating Quick Action Controls (Right Bottom - Compact 26x26dp, No Overlapping!)
          if (!_isSelectingOnMapMode && _selectedPointOnMap == null)
            Positioned(
              right: 6,
              bottom: 6,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Fullscreen Map Toggle Button
                  _buildActionButton(
                    icon: isFullScreen ? Icons.fullscreen_exit : Icons.fullscreen,
                    color: isFullScreen ? const Color(0xFFFFFFFF) : AppTheme.surfaceElevated,
                    iconColor: isFullScreen ? const Color(0xFF0C0D10) : const Color(0xFFCBD5E1),
                    tooltip: isFullScreen ? 'Tutup Full Map' : 'Buka Full Map',
                    onTap: () {
                      provider.toggleMapFullScreen();
                    },
                  ),

                  const SizedBox(height: 3),

                  // Dedicated "Select Point on Map" Button (Opens Full Map Picker)
                  _buildActionButton(
                    icon: Icons.add_location_alt_rounded,
                    color: AppTheme.surfaceElevated,
                    iconColor: const Color(0xFFFFFFFF),
                    tooltip: 'Pilih Titik di Peta (Full Map)',
                    onTap: _activateMapPickerMode,
                  ),

                  const SizedBox(height: 3),

                  // Search Routes & Places Dialog
                  _buildActionButton(
                    icon: Icons.alt_route,
                    color: AppTheme.surfaceElevated,
                    iconColor: const Color(0xFFFFFFFF),
                    tooltip: 'Cari Rute & Lokasi',
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (_) => RouteSearchDialog(
                          userPosition: position,
                          onPickOnMapSelected: _activateMapPickerMode,
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 3),

                  // Fit Entire Route (only when active route exists)
                  if (route != null) ...[
                    _buildActionButton(
                      icon: Icons.zoom_out_map,
                      color: AppTheme.surfaceElevated,
                      iconColor: const Color(0xFFCBD5E1),
                      tooltip: 'Lihat Seluruh Rute',
                      onTap: () => _fitRouteBounds(route),
                    ),
                    const SizedBox(height: 3),
                  ],

                  // Compass / Map Orientation Mode (Heading-Up vs North-Up)
                  _buildActionButton(
                    icon: provider.isHeadingUp ? Icons.navigation : Icons.explore,
                    color: provider.isHeadingUp ? const Color(0xFFFFFFFF) : AppTheme.surfaceElevated,
                    iconColor: provider.isHeadingUp ? const Color(0xFF0C0D10) : const Color(0xFFCBD5E1),
                    tooltip: provider.isHeadingUp
                        ? 'Mode Arah Hadap (Klik untuk Kunci ke Utara)'
                        : 'Mode Kunci ke Utara (Klik untuk Arah Hadap)',
                    onTap: () {
                      provider.toggleMapOrientation();
                      setState(() => _autoFollow = true);
                      try {
                        if (provider.isNorthUp) {
                          _mapController.moveAndRotate(position, _mapController.camera.zoom, 0.0);
                        } else {
                          final h = provider.currentHeading;
                          _mapController.moveAndRotate(position, _mapController.camera.zoom, -h);
                        }
                      } catch (_) {}
                    },
                  ),

                  const SizedBox(height: 3),

                  // Recenter GPS Button
                  _buildActionButton(
                    icon: Icons.my_location,
                    color: _autoFollow ? const Color(0xFFFFFFFF) : AppTheme.surfaceElevated,
                    iconColor: _autoFollow ? const Color(0xFF0C0D10) : const Color(0xFFCBD5E1),
                    tooltip: 'Kunci Lokasi Pengguna',
                    onTap: () {
                      setState(() => _autoFollow = true);
                      final h = provider.isHeadingUp ? -provider.currentHeading : 0.0;
                      _mapController.moveAndRotate(position, 16.5, h);
                    },
                  ),

                  const SizedBox(height: 3),

                  // Map Theme Toggle (Day Mode vs Dark Mode)
                  _buildActionButton(
                    icon: provider.isDarkMap ? Icons.dark_mode : Icons.wb_sunny,
                    color: AppTheme.surfaceElevated,
                    iconColor: provider.isDarkMap ? const Color(0xFF38BDF8) : const Color(0xFFF59E0B),
                    tooltip: provider.isDarkMap
                        ? 'Peta: Mode Malam (Klik untuk Mode Siang)'
                        : 'Peta: Mode Siang (Klik untuk Mode Malam)',
                    onTap: () {
                      provider.toggleMapTheme();
                    },
                  ),

                  const SizedBox(height: 3),

                  // Download & Kelola Peta Offline Button
                  _buildActionButton(
                    icon: Icons.download_for_offline,
                    color: AppTheme.surfaceElevated,
                    iconColor: provider.offlineMapService.downloadedProvinces.isNotEmpty
                        ? (provider.offlineMapService.isProvinceUpdatedToday(provider.currentProvince?.id ?? '')
                            ? const Color(0xFF10B981)
                            : const Color(0xFF00E5FF))
                        : const Color(0xFFCBD5E1),
                    tooltip: 'Download Peta (Kelola Peta Offline)',
                    onTap: () {
                      OfflineMapManagerDialog.show(context);
                    },
                  ),

                  const SizedBox(height: 3),

                  // Compact Zoom Pill (+ / - Combined)
                  _buildZoomPill(),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required Color iconColor,
    required VoidCallback onTap,
    String? tooltip,
  }) {
    return Tooltip(
      message: tooltip ?? '',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AppTheme.border.withOpacity(0.5), width: 0.8),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 3),
            ],
          ),
          child: Icon(icon, size: 13.5, color: iconColor),
        ),
      ),
    );
  }

  Widget _buildZoomPill() {
    return Container(
      width: 26,
      decoration: BoxDecoration(
        color: AppTheme.surface.withOpacity(0.92),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppTheme.border.withOpacity(0.5), width: 0.8),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 3),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: () {
              final z = (_mapController.camera.zoom + 1).clamp(4.0, 19.0);
              _mapController.move(_mapController.camera.center, z);
            },
            borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
            child: const SizedBox(
              width: 26,
              height: 23,
              child: Icon(Icons.add, size: 13, color: AppTheme.textPrimary),
            ),
          ),
          Container(
            height: 0.8,
            width: 20,
            color: AppTheme.border.withOpacity(0.4),
          ),
          InkWell(
            onTap: () {
              final z = (_mapController.camera.zoom - 1).clamp(4.0, 19.0);
              _mapController.move(_mapController.camera.center, z);
            },
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(6)),
            child: const SizedBox(
              width: 26,
              height: 23,
              child: Icon(Icons.remove, size: 13, color: AppTheme.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVehicleMarker(double headingDegrees, bool isHeadingUp, bool isFunMode) {
    return _VehicleArrowMarker(
      headingDegrees: headingDegrees,
      isHeadingUp: isHeadingUp,
      isFunMode: isFunMode,
    );
  }
}

class _VehicleArrowMarker extends StatelessWidget {
  final double headingDegrees;
  final bool isHeadingUp;
  final bool isFunMode;

  const _VehicleArrowMarker({
    required this.headingDegrees,
    required this.isHeadingUp,
    this.isFunMode = false,
  });

  @override
  Widget build(BuildContext context) {
    final angle = isHeadingUp ? 0.0 : (headingDegrees * pi / 180.0);

    return Center(
      child: Transform.rotate(
        angle: angle,
        child: CustomPaint(
          size: const Size(36, 36),
          painter: _VehicleArrowPainter(isFunMode: isFunMode),
        ),
      ),
    );
  }
}

class _VehicleArrowPainter extends CustomPainter {
  final bool isFunMode;

  _VehicleArrowPainter({this.isFunMode = false});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final Color accentColor = isFunMode ? const Color(0xFF00E5FF) : Colors.white;

    // 1. Forward Vision / Radar Beam (pointing UP, 40° field of view)
    final conePath = ui.Path()
      ..moveTo(center.dx, center.dy)
      ..arcTo(
        Rect.fromCircle(center: center, radius: 17),
        -pi / 2 - 0.35,
        0.70,
        false,
      )
      ..close();

    final conePaint = Paint()
      ..shader = RadialGradient(
        colors: [
          accentColor.withOpacity(isFunMode ? 0.25 : 0.18),
          accentColor.withOpacity(0.0),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: 17));
    canvas.drawPath(conePath, conePaint);

    // 2. Outer GPS Pulse Halo Ring
    final haloPaint = Paint()
      ..color = accentColor.withOpacity(isFunMode ? 0.35 : 0.16)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawCircle(center, 11, haloPaint);

    // 3. Navigation Chevron Arrow (sleek aero delta arrowhead pointing UP)
    final arrowPath = ui.Path()
      ..moveTo(center.dx, center.dy - 10)       // Tip pointing UP
      ..lineTo(center.dx + 6.5, center.dy + 6)   // Right wing
      ..lineTo(center.dx, center.dy + 2.5)      // Inner notch
      ..lineTo(center.dx - 6.5, center.dy + 6)   // Left wing
      ..close();

    // Arrow Shadow
    final shadowPaint = Paint()
      ..color = accentColor.withOpacity(isFunMode ? 0.45 : 0.25)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5);
    canvas.drawPath(arrowPath, shadowPaint);

    // Arrow Fill (Matte Graphite Obsidian)
    final bodyPaint = Paint()
      ..color = const Color(0xFF10131A)
      ..style = PaintingStyle.fill;
    canvas.drawPath(arrowPath, bodyPaint);

    // Arrow Border
    final borderPaint = Paint()
      ..color = isFunMode ? const Color(0xFF00F0FF) : const Color(0xFFFFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(arrowPath, borderPaint);

    // 4. Center Core Pulse Dot
    final corePaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 2.0, corePaint);
  }

  @override
  bool shouldRepaint(covariant _VehicleArrowPainter oldDelegate) =>
      oldDelegate.isFunMode != isFunMode;
}

class _TacticalGridPainter extends CustomPainter {
  final bool isDark;

  _TacticalGridPainter({this.isDark = true});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = isDark
          ? const Color(0xFF1E293B).withOpacity(0.35)
          : const Color(0xFF94A3B8).withOpacity(0.25)
      ..strokeWidth = 0.5;

    const step = 32.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _TacticalGridPainter oldDelegate) =>
      oldDelegate.isDark != isDark;
}
