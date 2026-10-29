import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'providers/dashboard_provider.dart';
import 'theme/app_theme.dart';
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
          // App Brand & Subtitle
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
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
}
