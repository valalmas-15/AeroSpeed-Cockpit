import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/workout_session_model.dart';
import '../../providers/dashboard_provider.dart';
import '../../services/workout_history_service.dart';
import '../../theme/app_theme.dart';
import 'route_thumbnail_widget.dart';
import 'workout_route_map_screen.dart';

/// Halaman Riwayat Sesi Berkendara / Workout
class WorkoutHistoryScreen extends StatelessWidget {
  const WorkoutHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DashboardProvider>();
    final historyService = provider.historyService;
    if (!historyService.isLoaded) {
      historyService.loadSessions();
    }
    final isFun = provider.isFunMode;
    final primaryColor = isFun ? const Color(0xFF00E5FF) : Colors.white;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Column(
            children: [
              // 1. Top Header Bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.surface.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isFun
                        ? const Color(0xFF6366F1).withOpacity(0.3)
                        : AppTheme.border.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    // Back to Dashboard Button
                    InkWell(
                      borderRadius: BorderRadius.circular(6),
                      onTap: () => provider.setScreen(AppScreen.dashboard),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceElevated,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppTheme.border, width: 0.8),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.arrow_back_rounded, size: 14, color: Color(0xFFCBD5E1)),
                            SizedBox(width: 4),
                            Text(
                              'COCKPIT',
                              style: TextStyle(
                                fontSize: 10.0,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFFCBD5E1),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(width: 10),

                    // Title & Count
                    Expanded(
                      child: Row(
                        children: [
                          Icon(Icons.history_rounded, size: 18, color: primaryColor),
                          const SizedBox(width: 6),
                          Text(
                            'RIWAYAT WORKOUT & BERKENDARA',
                            style: TextStyle(
                              fontSize: 12.0,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.8,
                              color: primaryColor,
                            ),
                          ),
                          const SizedBox(width: 8),
                          StreamBuilder<List<WorkoutSession>>(
                            stream: historyService.historyStream,
                            initialData: historyService.sessions,
                            builder: (context, snapshot) {
                              final count = snapshot.data?.length ?? 0;
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isFun ? const Color(0xFF083344) : const Color(0xFF1E293B),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isFun ? const Color(0xFF0284C7) : const Color(0xFF475569),
                                    width: 0.8,
                                  ),
                                ),
                                child: Text(
                                  '$count Sesi Tersimpan',
                                  style: TextStyle(
                                    fontSize: 9.0,
                                    fontWeight: FontWeight.w800,
                                    color: primaryColor,
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),

                    // Clear All Button
                    StreamBuilder<List<WorkoutSession>>(
                      stream: historyService.historyStream,
                      initialData: historyService.sessions,
                      builder: (context, snapshot) {
                        final sessions = snapshot.data ?? [];
                        if (sessions.isEmpty) return const SizedBox.shrink();

                        return IconButton(
                          icon: const Icon(Icons.delete_sweep_rounded, size: 18, color: Color(0xFFEF4444)),
                          tooltip: 'Hapus Semua Riwayat',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () => _confirmClearAll(context, historyService),
                        );
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 6),

              // 2. Body List of Workout Sessions
              Expanded(
                child: StreamBuilder<List<WorkoutSession>>(
                  stream: historyService.historyStream,
                  initialData: historyService.sessions,
                  builder: (context, snapshot) {
                    final sessions = snapshot.data ?? [];

                    if (sessions.isEmpty) {
                      return _buildEmptyState(context, provider, isFun, primaryColor);
                    }

                    return ListView.builder(
                      itemCount: sessions.length,
                      padding: const EdgeInsets.only(bottom: 8),
                      itemBuilder: (context, index) {
                        final session = sessions[index];
                        return _buildSessionCard(context, session, historyService, isFun, primaryColor);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(
    BuildContext context,
    DashboardProvider provider,
    bool isFun,
    Color primaryColor,
  ) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        padding: const EdgeInsets.all(20),
        decoration: AppTheme.glassCard(radius: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.directions_bike_rounded,
              size: 48,
              color: primaryColor.withOpacity(0.6),
            ),
            const SizedBox(height: 10),
            const Text(
              'BELUM ADA RIWAYAT SESI',
              style: TextStyle(
                fontSize: 13.0,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.8,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Mulai sesi berkendara di dashboard untuk merekam jarak, durasi, kecepatan, elevasi, kalori, dan detak jantung.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8), height: 1.3),
            ),
            const SizedBox(height: 14),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: const Color(0xFF0C0D10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              icon: const Icon(Icons.speed, size: 16),
              label: const Text(
                'BUKA DASHBOARD & MULAI SESI',
                style: TextStyle(fontSize: 11.0, fontWeight: FontWeight.w900),
              ),
              onPressed: () => provider.setScreen(AppScreen.dashboard),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionCard(
    BuildContext context,
    WorkoutSession session,
    WorkoutHistoryService historyService,
    bool isFun,
    Color primaryColor,
  ) {
    String dateStr;
    try {
      dateStr = DateFormat('EEEE, d MMM yyyy • HH:mm', 'id_ID').format(session.startTime);
    } catch (_) {
      dateStr = DateFormat('EEE, d MMM yyyy • HH:mm').format(session.startTime);
    }

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () {
        context.read<DashboardProvider>().openRouteMap(session);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: AppTheme.surfaceElevated.withOpacity(0.75),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isFun
                ? const Color(0xFF00E5FF).withOpacity(0.25)
                : AppTheme.border.withOpacity(0.4),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Route Shape Thumbnail Icon (PNG file or vector silhouette fallback)
            RouteThumbnailWidget(
              session: session,
              width: 70,
              height: 52,
              isFun: isFun,
            ),
            const SizedBox(width: 10),

            // Card Content: Header & Metrics
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Card Header: Date, Route Name, Open Map, Delete Action
                  Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isFun ? const Color(0xFF10B981) : Colors.white,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          dateStr,
                          style: const TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFCBD5E1),
                          ),
                        ),
                      ),
                      // Route Name Pill
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFF334155), width: 0.8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.alt_route, size: 10, color: Color(0xFF00E5FF)),
                            const SizedBox(width: 4),
                            Text(
                              session.routeName,
                              style: const TextStyle(
                                fontSize: 9.0,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      // Open Route Map Button (Strava-like map viewer)
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          context.read<DashboardProvider>().openRouteMap(session);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isFun ? const Color(0xFF083344) : const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: isFun ? const Color(0xFF00E5FF) : const Color(0xFF38BDF8),
                              width: 0.8,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.map_rounded,
                                size: 11,
                                color: isFun ? const Color(0xFF00E5FF) : const Color(0xFF38BDF8),
                              ),
                              const SizedBox(width: 3),
                              Text(
                                'BUKA PETA',
                                style: TextStyle(
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w900,
                                  color: isFun ? const Color(0xFF00E5FF) : const Color(0xFF38BDF8),
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      // Delete Button
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, size: 15, color: Color(0xFFEF4444)),
                        tooltip: 'Hapus Sesi',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => _confirmDeleteSession(context, session, historyService),
                      ),
                    ],
                  ),

                  const SizedBox(height: 5),
                  const Divider(color: Color(0xFF334155), height: 1),
                  const SizedBox(height: 5),

                  // Primary Metrics Grid (Tap to open route map)
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => context.read<DashboardProvider>().openRouteMap(session),
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
                        // Durasi
                        Expanded(
                          child: _buildMetricTile(
                            label: 'DURASI',
                            value: session.formattedDuration,
                            unit: '',
                            color: const Color(0xFFA855F7),
                          ),
                        ),
                        // Rata-rata Kecepatan
                        Expanded(
                          child: _buildMetricTile(
                            label: 'KECEPATAN RATA2',
                            value: session.displayAvgSpeed.toStringAsFixed(1),
                            unit: session.speedUnitLabel,
                            color: const Color(0xFF00E5FF),
                          ),
                        ),
                        // Max Kecepatan
                        Expanded(
                          child: _buildMetricTile(
                            label: 'MAX SPEED',
                            value: session.displayMaxSpeed.toStringAsFixed(0),
                            unit: session.speedUnitLabel,
                            color: const Color(0xFFFF5252),
                          ),
                        ),
                        // Kalori
                        Expanded(
                          child: _buildMetricTile(
                            label: 'KALORI',
                            value: session.calories.toStringAsFixed(0),
                            unit: 'kcal',
                            color: const Color(0xFFF59E0B),
                          ),
                        ),
                        // Heart Rate
                        Expanded(
                          child: _buildMetricTile(
                            label: 'DETAK JANTUNG',
                            value: session.avgHeartRate > 0 ? '${session.avgHeartRate}' : '--',
                            unit: 'bpm',
                            color: const Color(0xFFEC4899),
                          ),
                        ),
                        // Elevasi Gain/Loss
                        Expanded(
                          child: _buildMetricTile(
                            label: 'ELEVASI (+/-)',
                            value: '+${session.displayAscent.toStringAsFixed(0)} / -${session.displayDescent.toStringAsFixed(0)}',
                            unit: session.elevationUnitLabel,
                            color: const Color(0xFF60A5FA),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricTile({
    required String label,
    required String value,
    required String unit,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
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
            Flexible(
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w900,
                  color: color,
                ),
              ),
            ),
            if (unit.isNotEmpty) ...[
              const SizedBox(width: 2),
              Text(
                unit,
                style: const TextStyle(
                  fontSize: 8.5,
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

  Future<void> _confirmDeleteSession(
    BuildContext context,
    WorkoutSession session,
    WorkoutHistoryService historyService,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFFEF4444), width: 1.2),
        ),
        title: const Row(
          children: [
            Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 20),
            SizedBox(width: 8),
            Text(
              'HAPUS SESI INI?',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Colors.white),
            ),
          ],
        ),
        content: Text(
          'Hapus data sesi "${session.routeName}" (${session.displayDistance.toStringAsFixed(1)} ${session.distanceUnitLabel}) dari riwayat?',
          style: const TextStyle(fontSize: 11, color: Color(0xFFCBD5E1)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('BATAL', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('HAPUS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await historyService.deleteSession(session.id);
    }
  }

  Future<void> _confirmClearAll(
    BuildContext context,
    WorkoutHistoryService historyService,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
        ),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444), size: 22),
            SizedBox(width: 8),
            Text(
              'HAPUS SEMUA RIWAYAT?',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Colors.white),
            ),
          ],
        ),
        content: const Text(
          'Semua catatan sesi berkendara yang tersimpan akan dihapus secara permanen. Tindakan ini tidak dapat dibatalkan.',
          style: TextStyle(fontSize: 11, color: Color(0xFFCBD5E1), height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('BATAL', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('HAPUS SEMUA', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await historyService.clearAll();
    }
  }
}
