import 'package:flutter/material.dart';
import '../../models/speed_data.dart';
import '../../theme/app_theme.dart';

class SpeedStatsBar extends StatelessWidget {
  final SpeedData speedData;
  final bool isFunMode;

  const SpeedStatsBar({
    super.key,
    required this.speedData,
    this.isFunMode = false,
  });

  @override
  Widget build(BuildContext context) {
    final duration = speedData.tripDuration;
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;

    // Compact time format: "18:42" or "1h 18m" in English
    final formattedTime = hours > 0
        ? '${hours}h ${minutes.toString().padLeft(2, '0')}m'
        : '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
      decoration: BoxDecoration(
        color: AppTheme.surfaceElevated.withOpacity(0.6),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.border.withOpacity(0.5)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Row 1: MAX & AVG Speed
          Row(
            children: [
              Expanded(
                child: _buildTile(
                  icon: Icons.speed,
                  label: 'MAX SPEED',
                  value: speedData.displayMaxSpeed.toStringAsFixed(0),
                  unit: speedData.unitLabel,
                  accentColor: isFunMode ? const Color(0xFFFF5252) : const Color(0xFFCBD5E1),
                  valueFontSize: 18.0,
                  unitFontSize: 10.5,
                ),
              ),
              Container(width: 1, height: 28, color: AppTheme.border.withOpacity(0.5)),
              Expanded(
                child: _buildTile(
                  icon: Icons.trending_up,
                  label: 'AVG SPEED',
                  value: speedData.displayAvgSpeed.toStringAsFixed(1),
                  unit: speedData.unitLabel,
                  accentColor: isFunMode ? const Color(0xFF00E5FF) : const Color(0xFFCBD5E1),
                  valueFontSize: 18.0,
                  unitFontSize: 10.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Divider(color: AppTheme.border.withOpacity(0.35), height: 1),
          const SizedBox(height: 2),
          // Row 2: DISTANCE & DURATION
          Row(
            children: [
              Expanded(
                child: _buildTile(
                  icon: Icons.alt_route,
                  label: 'DISTANCE',
                  value: speedData.displayDistance.toStringAsFixed(1),
                  unit: speedData.distanceLabel,
                  accentColor: isFunMode ? const Color(0xFF10B981) : const Color(0xFFCBD5E1),
                  valueFontSize: 18.0,
                  unitFontSize: 10.5,
                ),
              ),
              Container(width: 1, height: 28, color: AppTheme.border.withOpacity(0.5)),
              Expanded(
                child: _buildTile(
                  icon: Icons.timer_outlined,
                  label: 'DURATION',
                  value: formattedTime,
                  unit: '',
                  accentColor: isFunMode ? const Color(0xFFA855F7) : const Color(0xFFCBD5E1),
                  valueFontSize: 16.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Divider(color: AppTheme.border.withOpacity(0.35), height: 1),
          const SizedBox(height: 2),
          // Row 3: ELEVATION, TOTAL ASCENT, TOTAL DESCENT
          Row(
            children: [
              Expanded(
                child: _buildTile(
                  icon: Icons.landscape,
                  label: 'ELEV',
                  value: speedData.displayElevation.round().toString(),
                  unit: speedData.elevationUnitLabel,
                  accentColor: isFunMode ? const Color(0xFF38BDF8) : const Color(0xFFCBD5E1),
                  valueFontSize: 15.5,
                  unitFontSize: 9.5,
                  isCompact: true,
                ),
              ),
              Container(width: 1, height: 26, color: AppTheme.border.withOpacity(0.5)),
              Expanded(
                child: _buildTile(
                  icon: Icons.north_east,
                  label: 'ASCENT',
                  value: '+${speedData.displayAscent.round()}',
                  unit: speedData.elevationUnitLabel,
                  accentColor: isFunMode ? const Color(0xFF10B981) : const Color(0xFFCBD5E1),
                  valueFontSize: 15.5,
                  unitFontSize: 9.5,
                  isCompact: true,
                ),
              ),
              Container(width: 1, height: 26, color: AppTheme.border.withOpacity(0.5)),
              Expanded(
                child: _buildTile(
                  icon: Icons.south_east,
                  label: 'DESCENT',
                  value: '-${speedData.displayDescent.round()}',
                  unit: speedData.elevationUnitLabel,
                  accentColor: isFunMode ? const Color(0xFFF59E0B) : const Color(0xFFCBD5E1),
                  valueFontSize: 15.5,
                  unitFontSize: 9.5,
                  isCompact: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTile({
    required IconData icon,
    required String label,
    required String value,
    required String unit,
    required Color accentColor,
    required double valueFontSize,
    double unitFontSize = 10.5,
    bool isCompact = false,
  }) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: isCompact ? 2.5 : 4.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(icon, size: isCompact ? 10.0 : 11.5, color: accentColor),
                const SizedBox(width: 2.5),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: isCompact ? 8.5 : 9.5,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textSecondary,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 1),
            Align(
              alignment: Alignment.center,
              child: RichText(
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                text: TextSpan(
                  text: value,
                  style: TextStyle(
                    fontSize: valueFontSize,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.textPrimary,
                    fontFamily: 'monospace',
                    letterSpacing: -0.3,
                  ),
                  children: [
                    if (unit.isNotEmpty)
                      TextSpan(
                        text: ' $unit',
                        style: TextStyle(
                          fontSize: unitFontSize,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textMuted,
                          letterSpacing: 0,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
