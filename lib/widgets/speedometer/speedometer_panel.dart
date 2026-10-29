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
      child: Column(
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

          // 2. Circular Speed Gauge (Expands to available space)
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

          // 3. Bottom Stats Grid (2x2 optimized for J6+)
          SpeedStatsBar(
            speedData: speed,
            isFunMode: provider.isFunMode,
          ),
        ],
      ),
    );
  }
}
