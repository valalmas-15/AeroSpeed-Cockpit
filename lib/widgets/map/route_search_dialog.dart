import 'package:latlong2/latlong.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../services/offline_map_service.dart';
import '../../services/routing_service.dart';
import '../../theme/app_theme.dart';
import 'cancel_route_dialog.dart';

class RouteSearchDialog extends StatefulWidget {
  final VoidCallback? onPickOnMapSelected;
  final LatLng? userPosition;

  const RouteSearchDialog({
    super.key,
    this.onPickOnMapSelected,
    this.userPosition,
  });

  @override
  State<RouteSearchDialog> createState() => _RouteSearchDialogState();
}

class _RouteSearchDialogState extends State<RouteSearchDialog> {
  final TextEditingController _searchController = TextEditingController();
  List<RouteSearchResult> _searchResults = [];
  bool _isLoading = false;
  String _selectedCategory = 'All';
  Timer? _debounceTimer;

  // Google Maps link parsed location
  ParsedGmapsLocation? _detectedGmapsLocation;
  bool _isParsingLink = false;

  final List<String> _categories = [
    'All',
    'Parks & Squares',
    'Tourism & Landmarks',
    'Sports',
    'Malls',
  ];

  @override
  void initState() {
    super.initState();
    final pos = widget.userPosition ?? const LatLng(-7.7956, 110.3695);
    _searchResults = RoutingService.getRecommendationsNear(pos);
    if (_searchResults.isEmpty) {
      _searchResults = OfflineMapService.instance.searchOfflinePlaces('', userPos: pos);
    }
    _loadDynamicCyclingDestinations(pos);
    _checkClipboardForGmaps();
  }

  Future<void> _loadDynamicCyclingDestinations(LatLng pos) async {
    setState(() => _isLoading = true);
    final dynamicList = await RoutingService.fetchCyclingDestinationsNear(
      pos,
      category: _selectedCategory,
    );
    if (mounted && _searchController.text.isEmpty) {
      setState(() {
        _searchResults = dynamicList;
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  // Auto-detect if user has a Google Maps link in clipboard
  Future<void> _checkClipboardForGmaps() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text?.trim() ?? '';
      if (_isGmapsInput(text)) {
        await _parseLink(text);
      }
    } catch (_) {}
  }

  bool _isGmapsInput(String text) {
    if (text.isEmpty) return false;
    final isUrl = text.contains('goo.gl') ||
        text.contains('google.com/maps') ||
        text.contains('maps.app');
    final isCoord = RegExp(r'(-?\d{1,2}\.\d{3,10})\s*,\s*(-?\d{1,3}\.\d{3,10})').hasMatch(text);
    final isDms = text.contains('°') && (text.contains("'S") || text.contains("'s") || text.contains("'N") || text.contains("'n"));
    return isUrl || isCoord || isDms;
  }

  Future<void> _parseLink(String text) async {
    setState(() => _isParsingLink = true);
    final parsed = await RoutingService.parseGoogleMapsInput(text);
    if (mounted) {
      setState(() {
        _detectedGmapsLocation = parsed;
        _isParsingLink = false;

        // If location was parsed, also add it as the top item in search results list
        if (parsed != null) {
          final provider = context.read<DashboardProvider>();
          const distCalc = Distance();
          final dist = distCalc.as(LengthUnit.Meter, provider.currentPosition, parsed.point) / 1000.0;
          final gmapsItem = RouteSearchResult(
            shortName: parsed.title,
            displayName: 'Location (${parsed.point.latitude.toStringAsFixed(6)}, ${parsed.point.longitude.toStringAsFixed(6)})',
            category: 'Google Maps',
            point: parsed.point,
            distanceKm: dist,
          );
          _searchResults.removeWhere((r) => r.shortName == gmapsItem.shortName);
          _searchResults.insert(0, gmapsItem);
        }
      });
    }
  }

  void _handleInput(String text) {
    _debounceTimer?.cancel();
    final clean = text.trim();

    if (clean.isEmpty) {
      setState(() => _detectedGmapsLocation = null);
      _filterByCategory(_selectedCategory);
      return;
    }

    // 1. If it has a Google Maps link or coordinates, parse it
    if (_isGmapsInput(clean)) {
      _parseLink(clean);
    }

    // 2. Extract any text keywords to perform live place search
    final placeName = RoutingService.extractPlaceName(clean);
    final searchQuery = placeName ?? clean.replaceAll(RegExp(r'https?://\S+'), '').trim();

    if (searchQuery.isNotEmpty && !RegExp(r'^-?\d+\.\d+').hasMatch(searchQuery)) {
      _debounceTimer = Timer(const Duration(milliseconds: 300), () {
        _performSearch(searchQuery);
      });
    } else if (!_isGmapsInput(clean)) {
      _debounceTimer = Timer(const Duration(milliseconds: 300), () {
        _performSearch(clean);
      });
    }
  }

  Future<void> _pasteFromClipboard() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text?.trim() ?? '';
      if (text.isNotEmpty) {
        _searchController.text = text;
        _handleInput(text);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Clipboard is empty or not permitted. Please paste with Ctrl+V (or Cmd+V) in the search field.'),
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Clipboard access restricted. Press Ctrl+V (or Cmd+V) to paste.'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _onSearchChanged(String query) {
    _handleInput(query);
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) {
      _filterByCategory(_selectedCategory);
      return;
    }

    setState(() => _isLoading = true);

    final provider = context.read<DashboardProvider>();
    final pos = widget.userPosition ?? provider.currentPosition;
    final results = await RoutingService.searchPlaces(query, userPos: pos, forceOffline: provider.isOfflineMode);
    if (mounted) {
      setState(() {
        _searchResults = results;
        _isLoading = false;
      });
    }
  }

  void _filterByCategory(String category) {
    setState(() {
      _selectedCategory = category;
      _searchController.clear();
      _detectedGmapsLocation = null;
    });
    final pos = widget.userPosition ?? context.read<DashboardProvider>().currentPosition;
    _searchResults = RoutingService.getRecommendationsNear(pos, category: category);
    if (_searchResults.isEmpty) {
      _searchResults = OfflineMapService.instance.searchOfflinePlaces(category == 'All' ? '' : category, userPos: pos);
    }
    _loadDynamicCyclingDestinations(pos);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DashboardProvider>();
    final screenHeight = MediaQuery.of(context).size.height;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        width: 600,
        constraints: BoxConstraints(maxHeight: screenHeight * 0.90),
        decoration: AppTheme.glassCard(
          borderColor: AppTheme.border,
          fillColor: AppTheme.surface.withOpacity(0.97),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Header with Close Button
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceElevated,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: const Icon(Icons.alt_route, color: Color(0xFFFFFFFF), size: 16),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Popular Cycling Destinations',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      Text(
                        '1-Hour Cycling Radius (≤ 15 km) from Your Location',
                        style: TextStyle(
                          fontSize: 10.5,
                          color: Color(0xFFCBD5E1),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (provider.currentRoute != null) ...[
                  InkWell(
                    onTap: () async {
                      final confirmed = await CancelRouteConfirmDialog.show(context);
                      if (confirmed == true && context.mounted) {
                        Navigator.of(context).pop();
                      }
                    },
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceElevated,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.close, size: 11, color: AppTheme.textSecondary),
                          SizedBox(width: 3),
                          Text(
                            'Batalkan Rute',
                            style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: AppTheme.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
                // Button Paste from clipboard
                InkWell(
                  onTap: _pasteFromClipboard,
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceElevated,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.content_paste, size: 11, color: Color(0xFFCBD5E1)),
                        SizedBox(width: 4),
                        Text(
                          'Paste GMaps Link',
                          style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: Color(0xFFCBD5E1)),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, color: AppTheme.textMuted, size: 18),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                ),
              ],
            ),

            const SizedBox(height: 6),

            // 2. Pick Point on Map Shortcut Banner
            InkWell(
              onTap: () {
                final provider = context.read<DashboardProvider>();
                Navigator.of(context).pop();
                provider.setMapFullScreen(true);
                widget.onPickOnMapSelected?.call();
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceElevated,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.border, width: 1.0),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.add_location_alt_rounded, size: 15, color: Color(0xFFFFFFFF)),
                    SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'SELECT POINT DIRECTLY ON MAP',
                            style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w900, color: Color(0xFFFFFFFF)),
                          ),
                          Text(
                            'Tap or pan map freely to choose your destination',
                            style: TextStyle(fontSize: 8.5, color: AppTheme.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, size: 15, color: Color(0xFFCBD5E1)),
                  ],
                ),
              ),
            ),

            // 3. Detected Google Maps Link Banner (If URL or coordinates parsed)
            if (_isParsingLink)
              Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceElevated,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.border),
                ),
                child: const Row(
                  children: [
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Reading coordinates from Google Maps link...',
                      style: TextStyle(fontSize: 9.5, color: Color(0xFFCBD5E1)),
                    ),
                  ],
                ),
              )
            else if (_detectedGmapsLocation != null)
              Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceElevated,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.border, width: 1.0),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, size: 18, color: Color(0xFFFFFFFF)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'GOOGLE MAPS LINK DETECTED:',
                            style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w800, color: Color(0xFFFFFFFF)),
                          ),
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  _detectedGmapsLocation!.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                                ),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                '(${_detectedGmapsLocation!.point.latitude.toStringAsFixed(4)}, ${_detectedGmapsLocation!.point.longitude.toStringAsFixed(4)})',
                                style: const TextStyle(fontSize: 8.5, fontFamily: 'monospace', color: Color(0xFFCBD5E1), fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        Navigator.of(context).pop();
                        final origin = provider.currentPosition;
                        await provider.setCustomRoute(
                          origin,
                          _detectedGmapsLocation!.point,
                          'My Location',
                          _detectedGmapsLocation!.title,
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFFFFFF),
                        foregroundColor: const Color(0xFF0C0D10),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        minimumSize: const Size(60, 26),
                      ),
                      child: const Text('ROUTE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900)),
                    ),
                  ],
                ),
              )
            else if (_isGmapsInput(_searchController.text) && !_isParsingLink)
              Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppTheme.warningOrange.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.warningOrange.withOpacity(0.5)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, size: 14, color: AppTheme.warningOrange),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Tip: Open short links in browser to copy full URL, or simply search by place name below.',
                        style: TextStyle(fontSize: 8.5, color: AppTheme.warningOrange, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),

            // 4. Search Input Bar + Paste Icon + Explicit "SEARCH" Button
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 36,
                    child: TextField(
                      controller: _searchController,
                      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 11),
                      decoration: InputDecoration(
                        hintText: 'Paste Google Maps link or enter place name...',
                        hintStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 10),
                        prefixIcon: const Icon(Icons.search, color: Color(0xFFFFFFFF), size: 16),
                        suffixIcon: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.content_paste, size: 14, color: Color(0xFFCBD5E1)),
                              tooltip: 'Paste from Clipboard',
                              onPressed: _pasteFromClipboard,
                            ),
                            if (_searchController.text.isNotEmpty)
                              IconButton(
                                icon: const Icon(Icons.clear, size: 14, color: AppTheme.textMuted),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _detectedGmapsLocation = null);
                                  _filterByCategory(_selectedCategory);
                                },
                              ),
                          ],
                        ),
                        filled: true,
                        fillColor: AppTheme.surfaceElevated,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: AppTheme.border.withOpacity(0.6)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Color(0xFFFFFFFF), width: 1.0),
                        ),
                      ),
                      onChanged: _onSearchChanged,
                      onSubmitted: (val) {
                        _handleInput(val);
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                SizedBox(
                  height: 36,
                  child: ElevatedButton(
                    onPressed: () {
                      _handleInput(_searchController.text);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFFFFF),
                      foregroundColor: const Color(0xFF0C0D10),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                          )
                        : const Text(
                            'SEARCH',
                            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800),
                          ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 5),

            // 5. Category Filter Chips
            SizedBox(
              height: 24,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _categories.length,
                separatorBuilder: (_, __) => const SizedBox(width: 4),
                itemBuilder: (context, index) {
                  final cat = _categories[index];
                  final isSelected = _selectedCategory == cat;
                  return InkWell(
                    onTap: () => _filterByCategory(cat),
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFFFFFFFF) : AppTheme.surfaceElevated,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isSelected ? const Color(0xFFFFFFFF) : AppTheme.border,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          cat,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: isSelected ? const Color(0xFF0C0D10) : AppTheme.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 5),

            // 6. Results List
            Expanded(
              child: _searchResults.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.location_off, size: 28, color: AppTheme.textMuted),
                          const SizedBox(height: 4),
                          Text(
                            _isLoading ? 'Searching places...' : 'No places found.',
                            style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      itemCount: _searchResults.length,
                      separatorBuilder: (_, __) => Divider(
                        color: AppTheme.border.withOpacity(0.3),
                        height: 1,
                      ),
                      itemBuilder: (context, index) {
                        final item = _searchResults[index];
                        return ListTile(
                          dense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          leading: Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceElevated,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: AppTheme.border),
                            ),
                            child: Icon(
                              _getCategoryIcon(item.category),
                              size: 14,
                              color: const Color(0xFFFFFFFF),
                            ),
                          ),
                          title: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  item.shortName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 5),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: AppTheme.surfaceElevated,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  item.category,
                                  style: const TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                              ),
                              if (item.formattedDistance.isNotEmpty) ...[
                                const SizedBox(width: 5),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppTheme.surfaceElevated,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: AppTheme.border, width: 0.8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.pedal_bike, size: 11, color: Color(0xFFFFFFFF)),
                                      const SizedBox(width: 3.5),
                                      Text(
                                        '${item.cyclingTimeEstimate} (${item.formattedDistance})',
                                        style: const TextStyle(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFFFFFFFF),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                          subtitle: Text(
                            item.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w500, color: AppTheme.textMuted),
                          ),
                          trailing: ElevatedButton(
                            onPressed: () async {
                              Navigator.of(context).pop();
                              final origin = provider.currentPosition;
                              await provider.setCustomRoute(
                                origin,
                                item.point,
                                'My Location',
                                item.shortName,
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFFFFFF),
                              foregroundColor: const Color(0xFF0C0D10),
                              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                              minimumSize: const Size(54, 28),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            ),
                            child: const Text(
                              'SELECT',
                              style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w900),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    final cat = category.toLowerCase();
    if (cat.contains('google maps') || cat.contains('gmaps')) return Icons.pin_drop;
    if (cat.contains('taman') || cat.contains('alun-alun') || cat.contains('park')) return Icons.park;
    if (cat.contains('olahraga') || cat.contains('stadion')) return Icons.sports_soccer;
    if (cat.contains('wisata') || cat.contains('ikonik') || cat.contains('monumen') || cat.contains('cagar')) return Icons.attractions;
    if (cat.contains('mall') || cat.contains('belanja')) return Icons.shopping_bag;
    return Icons.pedal_bike;
  }
}
