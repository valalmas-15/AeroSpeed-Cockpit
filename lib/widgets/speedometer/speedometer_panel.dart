import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/speed_data.dart';
import '../../providers/dashboard_provider.dart';
import '../../theme/app_theme.dart';
import 'circular_gauge.dart';
import 'speed_stats_bar.dart';

class SpeedometerPanel extends StatelessWidget {
  const SpeedometerPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DashboardProvider>();
    final speed = provider.speedData;

    return Container(
      decoration: AppTheme.glassCard(radius: 12),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Top Telemetry Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // GPS Status Pill (Green = Active, Amber = Standby)
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceElevated,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: speed.isGpsActive
                              ? (provider.isFunMode
                                  ? const Color(0xFF10B981).withOpacity(0.45)
                                  : const Color(0xFF475569))
                              : const Color(0xFFF59E0B).withOpacity(0.35),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: speed.isGpsActive
                                  ? const Color(0xFF10B981) // Emerald Green
                                  : const Color(0xFFF59E0B), // Amber Orange
                              boxShadow: [
                                BoxShadow(
                                  color: (speed.isGpsActive
                                          ? const Color(0xFF10B981)
                                          : const Color(0xFFF59E0B))
                                      .withOpacity(0.45),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              speed.isGpsActive ? 'GPS ACTIVE' : 'GPS STANDBY',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                color: speed.isGpsActive
                                    ? (provider.isFunMode ? const Color(0xFF10B981) : const Color(0xFFFFFFFF))
                                    : const Color(0xFFF59E0B),
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(width: 4),

                  // Controls: Unit Toggle & Reset
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Unit Switcher
                      InkWell(
                        onTap: provider.toggleSpeedUnit,
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceElevated,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: provider.isFunMode
                                  ? const Color(0xFF00E5FF).withOpacity(0.3)
                                  : const Color(0xFF475569),
                            ),
                          ),
                          child: Text(
                            speed.unit == SpeedUnit.kmh ? 'KM/H' : 'MPH',
                            style: TextStyle(
                              fontSize: 10.0,
                              fontWeight: FontWeight.w800,
                              color: provider.isFunMode ? const Color(0xFF00E5FF) : const Color(0xFFFFFFFF),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(width: 2),

                      // Reset Trip Button
                      IconButton(
                        onPressed: provider.resetTrip,
                        icon: const Icon(Icons.refresh, size: 15),
                        tooltip: 'Reset Trip',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                        color: AppTheme.textMuted,
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 2),

              // 2. Circular Speed Gauge (Expands to available space - live needle always reacts!)
              Expanded(
                child: CircularSpeedGauge(
                  currentSpeed: speed.displaySpeed,
                  maxGaugeSpeed: speed.unit == SpeedUnit.kmh ? 100.0 : 65.0,
                  unitLabel: speed.unitLabel,
                  isSpeedLimitExceeded: speed.isSpeedLimitExceeded,
                  speedLimit: speed.unit == SpeedUnit.kmh ? speed.speedLimit : speed.speedLimit * 0.621371,
                  isFunMode: provider.isFunMode,
                ),
              ),

              const SizedBox(height: 2),

              // Elevasi di tengah panel, tepat di bawah speedometer
              _buildCenterElevationBadge(speed, provider.isFunMode),

              const SizedBox(height: 2),

              // Session Control Bar (Visible when session is running or paused)
              if (!provider.isSessionIdle) ...[
                _buildSessionControlBar(context, provider),
                const SizedBox(height: 2),
              ],

              // 3. Bottom Stats Grid (Ascent/Descent, Max/Avg Speed, Distance/Duration)
              SpeedStatsBar(
                speedData: speed,
                isFunMode: provider.isFunMode,
              ),
            ],
          ),

          // 4. Session Start Reminder Overlay (Only covers the left speedometer panel!)
          if (provider.isSessionIdle)
            _buildSessionStartOverlay(context, provider),
        ],
      ),
    );
  }

  Widget _buildCenterElevationBadge(SpeedData speed, bool isFunMode) {
    final accentColor = isFunMode ? const Color(0xFF38BDF8) : const Color(0xFFCBD5E1);
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2.0),
        decoration: BoxDecoration(
          color: AppTheme.surfaceElevated.withOpacity(0.85),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isFunMode ? const Color(0xFF38BDF8).withOpacity(0.4) : AppTheme.border.withOpacity(0.5),
            width: 0.8,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              Icons.landscape_rounded,
              size: 12.5,
              color: accentColor,
            ),
            const SizedBox(width: 4),
            Text(
              'ELEVASI',
              style: TextStyle(
                fontSize: 8.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '${speed.displayElevation.round()}',
              style: TextStyle(
                fontSize: 12.0,
                fontWeight: FontWeight.w900,
                color: accentColor,
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(width: 2.5),
            Text(
              speed.elevationUnitLabel,
              style: const TextStyle(
                fontSize: 9.0,
                fontWeight: FontWeight.w700,
                color: AppTheme.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionControlBar(BuildContext context, DashboardProvider provider) {
    final isRunning = provider.isSessionActive;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
      decoration: BoxDecoration(
        color: AppTheme.surfaceElevated,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isRunning
              ? (provider.isFunMode ? const Color(0xFF00E5FF).withOpacity(0.5) : const Color(0xFF10B981).withOpacity(0.5))
              : const Color(0xFFF59E0B).withOpacity(0.5),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Status indicator (REC or JEDA)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isRunning ? const Color(0xFFEF4444) : const Color(0xFFF59E0B),
                ),
              ),
              const SizedBox(width: 4),
              Text(
                isRunning ? 'REC' : 'JEDA',
                style: TextStyle(
                  fontSize: 9.0,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                  color: isRunning ? const Color(0xFFEF4444) : const Color(0xFFF59E0B),
                ),
              ),
            ],
          ),

          // Action Buttons: Pause / Resume & Selesai
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Pause / Resume Button
              InkWell(
                borderRadius: BorderRadius.circular(5),
                onTap: isRunning ? provider.pauseSession : provider.resumeSession,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isRunning ? const Color(0xFF78350F) : const Color(0xFF064E3B),
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(
                      color: isRunning ? const Color(0xFFF59E0B) : const Color(0xFF10B981),
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded,
                        size: 11,
                        color: isRunning ? const Color(0xFFFBBF24) : const Color(0xFF34D399),
                      ),
                      const SizedBox(width: 2),
                      Text(
                        isRunning ? 'Jeda' : 'Lanjut',
                        style: TextStyle(
                          fontSize: 8.5,
                          fontWeight: FontWeight.w800,
                          color: isRunning ? const Color(0xFFFBBF24) : const Color(0xFF34D399),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(width: 4),

              // Finish Session Button
              InkWell(
                borderRadius: BorderRadius.circular(5),
                onTap: () => _confirmFinishSession(context, provider),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF450A0A),
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(color: const Color(0xFFEF4444), width: 0.8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.stop_rounded, size: 11, color: Color(0xFFF87171)),
                      SizedBox(width: 2),
                      Text(
                        'Selesai',
                        style: TextStyle(
                          fontSize: 8.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFF87171),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSessionStartOverlay(BuildContext context, DashboardProvider provider) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A).withOpacity(0.97),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: provider.isFunMode ? const Color(0xFF00E5FF).withOpacity(0.7) : const Color(0xFF94A3B8),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.6),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.warning_amber_rounded, size: 12, color: Color(0xFFF59E0B)),
                const SizedBox(width: 4),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'SESI BELUM DIMULAI',
                      style: TextStyle(
                        fontSize: 9.0,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.3,
                        color: provider.isFunMode ? const Color(0xFF00E5FF) : Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            const Text(
              'Mulai sesi untuk merekam durasi, jarak, elevasi, kecepatan & kalori',
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 7.5, color: Color(0xFF94A3B8), height: 1.1),
            ),
            const SizedBox(height: 5),
            SizedBox(
              width: double.infinity,
              height: 26,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: provider.isFunMode ? const Color(0xFF00E5FF) : const Color(0xFF10B981),
                  foregroundColor: const Color(0xFF0C0D10),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  elevation: 2,
                ),
                icon: const Icon(Icons.play_arrow_rounded, size: 15),
                label: const FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'MULAI SESI BERKENDARA',
                    style: TextStyle(fontSize: 9.0, fontWeight: FontWeight.w900, letterSpacing: 0.2),
                  ),
                ),
                onPressed: provider.startSession,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmFinishSession(BuildContext context, DashboardProvider provider) async {
    final speed = provider.speedData;

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
            Icon(Icons.stop_circle_rounded, color: Color(0xFFEF4444), size: 20),
            SizedBox(width: 8),
            Text(
              'SELESAIKAN SESI BERKENDARA?',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900, color: Colors.white),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Semua data dari sesi ini akan disimpan secara otomatis ke menu Riwayat:',
              style: TextStyle(fontSize: 10.5, color: Color(0xFFCBD5E1)),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B).withOpacity(0.6),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  _summaryRow('Jarak Tempuh', '${speed.displayDistance.toStringAsFixed(1)} ${speed.distanceLabel}'),
                  _summaryRow('Durasi Sesi', provider.sessionDuration.inMinutes > 0 ? '${provider.sessionDuration.inMinutes}m ${provider.sessionDuration.inSeconds % 60}s' : '${provider.sessionDuration.inSeconds} detik'),
                  _summaryRow('Kecepatan Rata-rata', '${speed.displayAvgSpeed.toStringAsFixed(1)} ${speed.unitLabel}'),
                  _summaryRow('Kecepatan Maksimal', '${speed.displayMaxSpeed.toStringAsFixed(0)} ${speed.unitLabel}'),
                  _summaryRow('Elevasi (Gain / Loss)', '+${speed.displayAscent.round()} / -${speed.displayDescent.round()} ${speed.elevationUnitLabel}'),
                  _summaryRow('Kalori Terbakar', '${provider.sessionCalories.toStringAsFixed(0)} kcal'),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('BATAL / LANJUT', style: TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('SIMPAN KE RIWAYAT', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final session = await provider.finishSession();
      if (session != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF0F172A),
            duration: const Duration(seconds: 4),
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Sesi berhasil disimpan (${session.totalDistanceKm.toStringAsFixed(1)} km, ${session.duration.inMinutes}m)',
                    style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w700),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    provider.setScreen(AppScreen.history);
                  },
                  child: const Text('LIHAT RIWAYAT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Color(0xFF00E5FF))),
                ),
              ],
            ),
          ),
        );
      }
    }
  }

  static Widget _summaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 9.5, color: Color(0xFF94A3B8))),
          Text(value, style: const TextStyle(fontSize: 10.0, fontWeight: FontWeight.w800, color: Colors.white)),
        ],
      ),
    );
  }
}
