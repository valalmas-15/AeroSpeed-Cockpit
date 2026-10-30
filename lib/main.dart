import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'providers/dashboard_provider.dart';
import 'theme/app_theme.dart';
import 'models/workout_session_model.dart';
import 'services/workout_history_service.dart';
import 'widgets/history/workout_history_screen.dart';
import 'widgets/history/workout_route_map_screen.dart';
import 'widgets/map/map_panel.dart';
import 'widgets/speedometer/speedometer_panel.dart';
import 'widgets/vitals/vitals_panel.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Force Landscape Orientation for horizontal cockpit view
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  // Immersive Sticky Mode (hide navigation and status bars for true HUD cockpit experience)
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  // Keep screen awake while driving/cycling
  try {
    await WakelockPlus.enable();
  } catch (_) {}

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => DashboardProvider()),
      ],
      child: const SpeedometerCockpitApp(),
    ),
  );
}

class SpeedometerCockpitApp extends StatelessWidget {
  const SpeedometerCockpitApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AeroSpeed Cockpit',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.themeData,
      home: const DashboardCockpitScreen(),
    );
  }
}

class DashboardCockpitScreen extends StatelessWidget {
  const DashboardCockpitScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DashboardProvider>();

    // Jika sedang di layar Peta Rute Detail (Strava-like view)
    if (provider.currentScreen == AppScreen.routeMap && provider.selectedRouteMapSession != null) {
      return WorkoutRouteMapScreen(
        session: provider.selectedRouteMapSession!,
        initialDarkMap: provider.isDarkMap,
        onBack: provider.closeRouteMap,
      );
    }

    // Jika sedang di layar Riwayat Workout
    if (provider.currentScreen == AppScreen.history) {
      return const WorkoutHistoryScreen();
    }

    final isFullMap = provider.isMapFullScreen;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Column(
            children: [
              if (!isFullMap) ...[
                // 1. Subtle Ambient Header (Ultra-compact for 360dp landscape height)
                _buildTopAmbientHeader(context),
                const SizedBox(height: 4),
              ],

              // 2. Horizontal 3-Column Cockpit Layout or Full Map View Optimized for Galaxy J6+ (18.5:9 display)
              Expanded(
                child: isFullMap
                    ? const MapPanel(isFullScreen: true)
                    : const Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // KIRI: Speedometer & Telemetry (flex 32 ~225dp)
                          Expanded(
                            flex: 32,
                            child: SpeedometerPanel(),
                          ),

                          SizedBox(width: 5),

                          // TENGAH: Maps & Route Navigation (flex 40 ~285dp)
                          Expanded(
                            flex: 40,
                            child: MapPanel(isFullScreen: false),
                          ),

                          SizedBox(width: 5),

                          // KANAN: Tanda Vital & Amazfit Active 2 (flex 28 ~200dp)
                          Expanded(
                            flex: 28,
                            child: VitalsPanel(),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopAmbientHeader(BuildContext context) {
    final provider = context.watch<DashboardProvider>();
    final now = DateTime.now();
    final timeStr = DateFormat('HH:mm').format(now);
    final dateStr = DateFormat('EEE, d MMM').format(now);

    final isFun = provider.isFunMode;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
      decoration: BoxDecoration(
        color: AppTheme.surface.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isFun
              ? const Color(0xFF6366F1).withOpacity(0.3)
              : AppTheme.border.withOpacity(0.3),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Hamburger Menu & App Brand
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Hamburger Menu Button
              IconButton(
                icon: const Icon(Icons.menu_rounded, size: 20, color: Color(0xFFCBD5E1)),
                tooltip: 'Menu Utama',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                onPressed: () => _showNavigationMenu(context, provider),
              ),
              const SizedBox(width: 4),

              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isFun ? const Color(0xFF00E5FF) : const Color(0xFFFFFFFF),
                  boxShadow: [
                    BoxShadow(
                      color: (isFun ? const Color(0xFF00E5FF) : Colors.white).withOpacity(0.4),
                      blurRadius: 4,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              const Text(
                'AEROSPEED',
                style: TextStyle(
                  fontSize: 12.0,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.textPrimary,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(width: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.0),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceElevated,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: AppTheme.border, width: 0.8),
                ),
                child: const Text(
                  'HUD',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFCBD5E1),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(width: 6),

          // Controls & Status with Responsive Scale-Down (Never Overflows!)
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Route destination pill (if active)
                  if (provider.currentRoute != null) ...[
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.navigation,
                            size: 12,
                            color: isFun ? const Color(0xFF00E5FF) : const Color(0xFFCBD5E1),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            provider.currentRoute!.destinationName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11.0,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Mode Network: [ ONLINE | OFFLINE ]
                  _buildNetworkModeSelector(provider, context),

                  const SizedBox(width: 4),

                  // Interactive Mode Switcher: [ MINIMALIS | FUN ]
                  _buildModeSelector(provider),

                  const SizedBox(width: 6),

                  // Real-time Clock
                  Text(
                    '$dateStr • $timeStr',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNetworkModeSelector(DashboardProvider provider, BuildContext context) {
    final isOnlineMode = provider.isOnlineMode;
    final isConnected = provider.isInternetConnected;
    final isFun = provider.isFunMode;

    return Container(
      height: 26,
      padding: const EdgeInsets.all(2.5),
      decoration: BoxDecoration(
        color: const Color(0xFF0E1116),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: isOnlineMode
              ? (isFun ? const Color(0xFF00E5FF).withOpacity(0.4) : const Color(0xFF475569))
              : const Color(0xFFE11D48).withOpacity(0.4),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Online Mode Option (Re-probes connection on tap)
          Tooltip(
            message: !isConnected
                ? 'Tidak ada koneksi internet (Klik untuk cek koneksi)'
                : 'Mode Online (Peta Live & Routing Server)',
            child: GestureDetector(
              onTap: () async {
                if (isOnlineMode) return;
                final success = await provider.setNetworkMode(NetworkMode.online);
                if (!success && context.mounted) {
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('⚠️ Ponsel sedang tidak terhubung ke internet. Mode Online tidak dapat diaktifkan.'),
                      duration: Duration(seconds: 2),
                      backgroundColor: Color(0xFF1E293B),
                    ),
                  );
                }
              },
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.0),
                decoration: BoxDecoration(
                  color: isOnlineMode
                      ? (isFun ? const Color(0xFF00E5FF).withOpacity(0.2) : const Color(0xFF1E2430))
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  border: isOnlineMode
                      ? Border.all(
                          color: isFun ? const Color(0xFF00E5FF) : const Color(0xFF475569),
                          width: 0.8,
                        )
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isConnected ? Icons.wifi : Icons.wifi_off,
                      size: 10,
                      color: !isConnected
                          ? const Color(0xFF475569) // Greyed out / disabled
                          : (isOnlineMode
                              ? (isFun ? const Color(0xFF00E5FF) : Colors.white)
                              : const Color(0xFF64748B)),
                    ),
                    const SizedBox(width: 3.5),
                    Text(
                      'ONLINE',
                      style: TextStyle(
                        fontSize: 9.0,
                        fontWeight: isOnlineMode ? FontWeight.w800 : FontWeight.w600,
                        color: !isConnected
                            ? const Color(0xFF475569) // Greyed out / disabled
                            : (isOnlineMode
                                ? (isFun ? const Color(0xFF00E5FF) : Colors.white)
                                : const Color(0xFF64748B)),
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(width: 2.5),

          // Offline Mode Option (Always functional!)
          Tooltip(
            message: 'Mode Offline (100% Menggunakan Data Tersimpan)',
            child: GestureDetector(
              onTap: () => provider.setNetworkMode(NetworkMode.offline),
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.0),
                decoration: BoxDecoration(
                  color: !isOnlineMode
                      ? const Color(0xFFE11D48).withOpacity(0.25)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  border: !isOnlineMode
                      ? Border.all(color: const Color(0xFFE11D48), width: 0.8)
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.cloud_off,
                      size: 10,
                      color: !isOnlineMode ? const Color(0xFFFF5252) : const Color(0xFF64748B),
                    ),
                    const SizedBox(width: 3.5),
                    Text(
                      'OFFLINE',
                      style: TextStyle(
                        fontSize: 9.0,
                        fontWeight: !isOnlineMode ? FontWeight.w800 : FontWeight.w600,
                        color: !isOnlineMode ? const Color(0xFFFF5252) : const Color(0xFF64748B),
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeSelector(DashboardProvider provider) {
    final isFun = provider.isFunMode;

    return Container(
      height: 26,
      padding: const EdgeInsets.all(2.5),
      decoration: BoxDecoration(
        color: const Color(0xFF0E1116),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: isFun ? const Color(0xFF6366F1).withOpacity(0.4) : const Color(0xFF2C323E),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Minimalis Mode Option
          GestureDetector(
            onTap: () => provider.setCockpitMode(CockpitMode.minimalis),
            behavior: HitTestBehavior.opaque,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2.0),
              decoration: BoxDecoration(
                color: !isFun ? const Color(0xFF1E2430) : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                border: !isFun
                    ? Border.all(color: const Color(0xFF475569), width: 0.8)
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.adjust,
                    size: 10,
                    color: !isFun ? const Color(0xFFFFFFFF) : const Color(0xFF64748B),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'MINIMAL',
                    style: TextStyle(
                      fontSize: 10.0,
                      fontWeight: !isFun ? FontWeight.w800 : FontWeight.w600,
                      color: !isFun ? const Color(0xFFFFFFFF) : const Color(0xFF64748B),
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(width: 3),

          // Fun Mode Option
          GestureDetector(
            onTap: () => provider.setCockpitMode(CockpitMode.fun),
            behavior: HitTestBehavior.opaque,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2.0),
              decoration: BoxDecoration(
                gradient: isFun
                    ? const LinearGradient(
                        colors: [Color(0xFF6366F1), Color(0xFF06B6D4)],
                      )
                    : null,
                borderRadius: BorderRadius.circular(10),
                boxShadow: isFun
                    ? [
                        BoxShadow(
                          color: const Color(0xFF06B6D4).withOpacity(0.35),
                          blurRadius: 5,
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.auto_awesome,
                    size: 10,
                    color: isFun ? Colors.white : const Color(0xFF64748B),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'FUN',
                    style: TextStyle(
                      fontSize: 10.0,
                      fontWeight: isFun ? FontWeight.w900 : FontWeight.w600,
                      color: isFun ? Colors.white : const Color(0xFF64748B),
                      letterSpacing: 0.6,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showNavigationMenu(BuildContext context, DashboardProvider provider) {
    final isFun = provider.isFunMode;
    final primaryColor = isFun ? const Color(0xFF00E5FF) : Colors.white;

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Container(
          width: 380,
          decoration: AppTheme.glassCard(
            borderColor: isFun ? const Color(0xFF00E5FF).withOpacity(0.5) : const Color(0xFF475569),
            fillColor: const Color(0xFF0F172A).withOpacity(0.98),
            radius: 12,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  children: [
                    Icon(Icons.menu_open_rounded, color: primaryColor, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'MENU NAVIGASI',
                            style: TextStyle(
                              fontSize: 12.0,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.6,
                              color: primaryColor,
                            ),
                          ),
                          const SizedBox(height: 1),
                          const Text(
                            'Pilih layar aplikasi',
                            style: TextStyle(fontSize: 9.0, color: Color(0xFF94A3B8)),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Color(0xFF94A3B8), size: 16),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
              ),

              const Divider(color: Color(0xFF334155), height: 1),

              // Menu Options
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                child: Column(
                  children: [
                    // Item 1: Dashboard Cockpit
                    _buildMenuItem(
                      icon: Icons.dashboard_rounded,
                      title: 'Dashboard Cockpit',
                      subtitle: 'Speedometer, peta navigasi & vital signs',
                      isActive: provider.currentScreen == AppScreen.dashboard,
                      activeColor: primaryColor,
                      onTap: () {
                        Navigator.of(ctx).pop();
                        provider.setScreen(AppScreen.dashboard);
                      },
                    ),

                    const SizedBox(height: 6),

                    // Item 2: Riwayat Workout
                    StreamBuilder<List<WorkoutSession>>(
                      stream: provider.historyService.historyStream,
                      initialData: provider.historyService.sessions,
                      builder: (context, snapshot) {
                        final count = snapshot.data?.length ?? 0;
                        return _buildMenuItem(
                          icon: Icons.history_rounded,
                          title: 'Riwayat Workout',
                          subtitle: 'Catatan sesi berkendara yang disimpan',
                          badgeText: count > 0 ? '$count Sesi' : null,
                          isActive: provider.currentScreen == AppScreen.history,
                          activeColor: const Color(0xFF10B981),
                          onTap: () {
                            Navigator.of(ctx).pop();
                            provider.setScreen(AppScreen.history);
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),

              // Session Status Footer
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B).withOpacity(0.5),
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                  border: const Border(top: BorderSide(color: Color(0xFF334155), width: 0.8)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: provider.isSessionActive
                            ? const Color(0xFF10B981)
                            : (provider.isSessionPaused ? const Color(0xFFF59E0B) : const Color(0xFF64748B)),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        provider.isSessionActive
                            ? 'Sesi Aktif: ${provider.sessionDuration.inMinutes}m ${provider.sessionDuration.inSeconds % 60}s (${provider.sessionDistanceKm.toStringAsFixed(1)} km)'
                            : (provider.isSessionPaused
                                ? 'Sesi Dijeda (${provider.sessionDuration.inMinutes}m)'
                                : 'Sesi Belum Dimulai'),
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          color: provider.isSessionActive
                              ? const Color(0xFF34D399)
                              : (provider.isSessionPaused ? const Color(0xFFFBBF24) : const Color(0xFF94A3B8)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required String subtitle,
    String? badgeText,
    required bool isActive,
    required Color activeColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? activeColor.withOpacity(0.12) : const Color(0xFF1E293B).withOpacity(0.4),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive ? activeColor.withOpacity(0.6) : const Color(0xFF334155),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: isActive ? activeColor.withOpacity(0.2) : const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(icon, size: 18, color: isActive ? activeColor : const Color(0xFFCBD5E1)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: isActive ? Colors.white : const Color(0xFFCBD5E1),
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 9.0, color: Color(0xFF94A3B8)),
                  ),
                ],
              ),
            ),
            if (badgeText != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF064E3B),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF059669), width: 0.8),
                ),
                child: Text(
                  badgeText,
                  style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.w800, color: Color(0xFF34D399)),
                ),
              ),
            if (isActive) ...[
              const SizedBox(width: 6),
              Icon(Icons.check_circle_rounded, size: 14, color: activeColor),
            ],
          ],
        ),
      ),
    );
  }
}
