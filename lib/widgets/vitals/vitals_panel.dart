import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../theme/app_theme.dart';
import 'bluetooth_device_modal.dart';
import 'ecg_live_graph.dart';

class VitalsPanel extends StatefulWidget {
  const VitalsPanel({super.key});

  @override
  State<VitalsPanel> createState() => _VitalsPanelState();
}

class _VitalsPanelState extends State<VitalsPanel> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  int _lastBpm = 0;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.9, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _syncPulseSpeed(int bpm) {
    if (bpm > 30 && bpm != _lastBpm) {
      _lastBpm = bpm;
      final msPerBeat = (60000 / bpm).round().clamp(300, 1800);
      _pulseController.duration = Duration(milliseconds: msPerBeat);
      if (!_pulseController.isAnimating) {
        _pulseController.repeat(reverse: true);
      }
    } else if (bpm <= 0 && _pulseController.isAnimating) {
      _pulseController.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DashboardProvider>();
    final vitals = provider.vitals;
    final isFun = provider.isFunMode;

    _syncPulseSpeed(vitals.heartRate);

    // Connectivity Color Scheme: Green = Connected, Amber = Auto-connecting, Red = Disconnected
    final Color connectStatusColor;
    final String connectStatusText;
    if (vitals.isConnected) {
      connectStatusColor = const Color(0xFF10B981); // Emerald Green
      connectStatusText = 'CONNECTED';
    } else if (provider.isBleAutoConnecting) {
      connectStatusColor = const Color(0xFFF59E0B); // Amber Orange
      connectStatusText = 'CONNECTING...';
    } else {
      connectStatusColor = const Color(0xFFEF4444); // Crimson Red
      connectStatusText = 'DISCONNECTED';
    }

    // Dynamic HR Zone Color (Fun: Cyan -> Green -> Gold -> Red, Minimalis: Clean White / Silver)
    final Color hrZoneColor = vitals.zone.zoneColor(isFun);
    final Color activeHeartColor = isFun ? hrZoneColor : const Color(0xFFFFFFFF);
    final Color bpmTextColor = isFun
        ? (vitals.heartRate > 0 ? hrZoneColor : const Color(0xFFCBD5E1))
        : const Color(0xFFFFFFFF);

    return Container(
      decoration: AppTheme.glassCard(
        radius: 12,
        borderColor: isFun ? hrZoneColor.withOpacity(0.2) : null,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Top Header: Amazfit Active 2 Status with Connectivity Colors
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Watch Name & Status
              Expanded(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(3.5),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceElevated,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: vitals.isConnected
                              ? connectStatusColor.withOpacity(0.4)
                              : AppTheme.border,
                        ),
                      ),
                      child: Icon(
                        Icons.watch,
                        size: 13,
                        color: vitals.isConnected ? connectStatusColor : const Color(0xFFCBD5E1),
                      ),
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'AMAZFIT ACTIVE 2',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10.0,
                              fontWeight: FontWeight.w900,
                              color: AppTheme.textPrimary,
                              letterSpacing: 0.3,
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 5,
                                height: 5,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: connectStatusColor,
                                  boxShadow: [
                                    BoxShadow(
                                      color: connectStatusColor.withOpacity(0.5),
                                      blurRadius: 3,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 3),
                              Flexible(
                                child: Text(
                                  connectStatusText,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.w800,
                                    color: connectStatusColor,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Connect Button & Battery
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (vitals.isConnected) ...[
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.battery_std, size: 13, color: Color(0xFFCBD5E1)),
                        const SizedBox(width: 2),
                        Text(
                          '${vitals.batteryLevel}%',
                          style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: AppTheme.textMuted),
                        ),
                      ],
                    ),
                    const SizedBox(width: 4),
                  ],

                  IconButton(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (_) => const BluetoothDeviceModal(),
                      );
                    },
                    icon: Icon(
                      Icons.bluetooth,
                      size: 18,
                      color: vitals.isConnected ? connectStatusColor : AppTheme.textMuted,
                    ),
                    tooltip: 'Connect Watch',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 5),

          // 2. Primary Heart Rate Telemetry Card (Color-coded to HR Zone)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.surfaceElevated.withOpacity(0.7),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isFun && vitals.heartRate > 0
                    ? hrZoneColor.withOpacity(0.4)
                    : AppTheme.border.withOpacity(0.6),
                width: 1.0,
              ),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Pulsing Heart Icon (Animated according to BPM and HR Zone)
                    ScaleTransition(
                      scale: vitals.heartRate > 0
                          ? _pulseAnimation
                          : const AlwaysStoppedAnimation(1.0),
                      child: Icon(
                        Icons.favorite,
                        size: 17,
                        color: vitals.heartRate > 0 ? activeHeartColor : AppTheme.textMuted,
                      ),
                    ),

                    // Big BPM Number Readout (Enlarged for Handlebar Glanceability)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          vitals.heartRate > 0 ? '${vitals.heartRate}' : '--',
                          style: TextStyle(
                            fontSize: 24.0,
                            fontWeight: FontWeight.w900,
                            color: bpmTextColor,
                            height: 0.95,
                            letterSpacing: -0.8,
                            fontFamily: 'monospace',
                            shadows: isFun && vitals.heartRate > 0
                                ? [
                                    BoxShadow(
                                      color: hrZoneColor.withOpacity(0.35),
                                      blurRadius: 6,
                                    ),
                                  ]
                                : null,
                          ),
                        ),
                        const SizedBox(width: 2.5),
                        const Text(
                          'BPM',
                          style: TextStyle(
                            fontSize: 10.0,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textMuted,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),

                    // HR Zone Pill
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      decoration: BoxDecoration(
                        color: isFun && vitals.heartRate > 0
                            ? hrZoneColor.withOpacity(0.15)
                            : AppTheme.surfaceElevated,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: isFun && vitals.heartRate > 0
                              ? hrZoneColor.withOpacity(0.6)
                              : AppTheme.border,
                        ),
                      ),
                      child: Text(
                        vitals.heartRate > 0 ? vitals.zone.label : 'READY',
                        style: TextStyle(
                          fontSize: 8.5,
                          fontWeight: FontWeight.w800,
                          color: vitals.heartRate > 0
                              ? (isFun ? hrZoneColor : const Color(0xFFCBD5E1))
                              : AppTheme.textMuted,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 5),

                // Min, Max, Avg HR Badges
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildHrSubStat('MIN', vitals.minHeartRate > 0 ? '${vitals.minHeartRate}' : '--'),
                    _buildHrSubStat('AVG', vitals.avgHeartRate > 0 ? '${vitals.avgHeartRate}' : '--'),
                    _buildHrSubStat('MAX', vitals.maxHeartRate > 0 ? '${vitals.maxHeartRate}' : '--'),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 5),

          // 3. Live ECG Graph (Expands with HR Zone Color curve)
          Expanded(
            child: EcgLiveGraph(
              history: vitals.history,
              strokeColor: vitals.heartRate > 0 ? hrZoneColor : const Color(0xFFCBD5E1),
            ),
          ),

          const SizedBox(height: 5),

          // 4. Calories & Energy Expenditure Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: AppTheme.surfaceElevated.withOpacity(0.6),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.border.withOpacity(0.5)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildEnergyItem(
                    icon: Icons.local_fire_department,
                    label: 'CALORIES',
                    value: '${vitals.caloriesBurned.toStringAsFixed(0)} kcal',
                    color: isFun ? const Color(0xFFFF6D00) : const Color(0xFFCBD5E1),
                  ),
                ),
                Container(width: 1, height: 18, color: AppTheme.border.withOpacity(0.5)),
                Expanded(
                  child: _buildEnergyItem(
                    icon: Icons.bolt,
                    label: 'BURN RATE',
                    value: '${vitals.burnRatePerHour.toStringAsFixed(0)}/h',
                    color: isFun ? const Color(0xFF00E5FF) : const Color(0xFFCBD5E1),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHrSubStat(String label, String value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.w800, color: AppTheme.textMuted),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13.0,
            fontWeight: FontWeight.w900,
            color: AppTheme.textPrimary,
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }

  Widget _buildEnergyItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 3),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.w800, color: AppTheme.textMuted),
              ),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.textPrimary,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
