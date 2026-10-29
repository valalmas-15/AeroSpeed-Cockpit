import 'dart:math';
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// A modern, fully-digital instrument cluster gauge (no analog needle).
/// Features:
/// 1. Digital Clock Style 7-Segment LED speed readout in the center.
/// 2. Scaled for motorcycle/speedometer range (0 - 100 km/h).
/// 3. Digital progressive LED segmented arc blocks inspired by modern sports bikes & EV cockpits.
class CircularSpeedGauge extends StatelessWidget {
  final double currentSpeed;
  final double maxGaugeSpeed;
  final String unitLabel;
  final bool isSpeedLimitExceeded;
  final double speedLimit;
  final bool isFunMode;

  const CircularSpeedGauge({
    super.key,
    required this.currentSpeed,
    this.maxGaugeSpeed = 100.0,
    required this.unitLabel,
    this.isSpeedLimitExceeded = false,
    this.speedLimit = 60.0,
    this.isFunMode = false,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = min(constraints.maxWidth, constraints.maxHeight);
        final isCompact = size < 190;

        return Center(
          child: SizedBox(
            width: size,
            height: size,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // 1. Digital LED Segmented Cluster Painter (Modern Digital Arc, No Needle)
                CustomPaint(
                  size: Size(size, size),
                  painter: _DigitalClusterArcPainter(
                    speed: currentSpeed.clamp(0.0, maxGaugeSpeed),
                    maxSpeed: maxGaugeSpeed,
                    speedLimit: speedLimit,
                    isExceeded: isSpeedLimitExceeded,
                    isCompact: isCompact,
                    isFunMode: isFunMode,
                  ),
                ),

                // 2. Center Digital Clock 7-Segment Readout
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Overspeed Alert Badge
                    if (isSpeedLimitExceeded)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                        margin: const EdgeInsets.only(bottom: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.alertRed.withOpacity(0.25),
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(color: AppTheme.alertRed, width: 1.0),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.alertRed.withOpacity(0.5),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                        child: const Text(
                          'LIMIT EXCEEDED',
                          style: TextStyle(
                            color: AppTheme.alertRed,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),

                    // 7-Segment Digital Clock Display (Enlarged for Handlebar Viewing)
                    TweenAnimationBuilder<double>(
                      tween: Tween<double>(begin: 0, end: currentSpeed),
                      duration: const Duration(milliseconds: 180),
                      builder: (context, value, _) {
                        return _SevenSegmentSpeedDisplay(
                          speed: value.round().clamp(0, 999),
                          isExceeded: isSpeedLimitExceeded,
                          digitHeight: (size * 0.40).clamp(48.0, 78.0),
                          isFunMode: isFunMode,
                        );
                      },
                    ),

                    const SizedBox(height: 3),

                    // Digital Unit Badge
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: isCompact ? 8 : 10,
                        vertical: 2.5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF14171E),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isSpeedLimitExceeded
                              ? AppTheme.alertRed.withOpacity(0.6)
                              : (isFunMode ? const Color(0xFF00E5FF).withOpacity(0.4) : AppTheme.border),
                          width: 0.8,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: (isSpeedLimitExceeded
                                    ? AppTheme.alertRed
                                    : (isFunMode ? const Color(0xFF00E5FF) : Colors.white))
                                .withOpacity(isFunMode ? 0.15 : 0.06),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: Text(
                        unitLabel,
                        style: TextStyle(
                          fontSize: isCompact ? 10.5 : 12.0,
                          fontWeight: FontWeight.w800,
                          color: isSpeedLimitExceeded
                              ? AppTheme.alertRed
                              : (isFunMode ? const Color(0xFF00E5FF) : Colors.white),
                          letterSpacing: 1.2,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// 7-SEGMENT DIGITAL CLOCK DISPLAY WIDGET
// ---------------------------------------------------------------------------
class _SevenSegmentSpeedDisplay extends StatelessWidget {
  final int speed;
  final bool isExceeded;
  final double digitHeight;
  final bool isFunMode;

  const _SevenSegmentSpeedDisplay({
    required this.speed,
    required this.isExceeded,
    required this.digitHeight,
    this.isFunMode = false,
  });

  @override
  Widget build(BuildContext context) {
    final digitWidth = digitHeight * 0.58;
    final speedStr = speed.toString();
    final digits = speed < 10 ? ['0', speedStr] : speedStr.split('');

    final activeColor = isExceeded
        ? AppTheme.alertRed
        : (isFunMode ? const Color(0xFF00F0FF) : Colors.white);
    final inactiveColor = isExceeded
        ? AppTheme.alertRed.withOpacity(0.08)
        : (isFunMode ? const Color(0xFF0F1E2E) : const Color(0xFF181D26));

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: digits.map((char) {
        final val = int.tryParse(char) ?? 0;
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: digitHeight * 0.04),
          child: Transform(
            transform: Matrix4.skewX(-0.11), // Sporty digital clock slant
            alignment: Alignment.center,
            child: SizedBox(
              width: digitWidth,
              height: digitHeight,
              child: CustomPaint(
                painter: _SingleSevenSegmentPainter(
                  digit: val,
                  activeColor: activeColor,
                  inactiveColor: inactiveColor,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _SingleSevenSegmentPainter extends CustomPainter {
  final int digit;
  final Color activeColor;
  final Color inactiveColor;

  _SingleSevenSegmentPainter({
    required this.digit,
    required this.activeColor,
    required this.inactiveColor,
  });

  // 7-segment mapping for digits 0-9: [a, b, c, d, e, f, g]
  // a: top, b: top-right, c: bottom-right, d: bottom, e: bottom-left, f: top-left, g: middle
  static const Map<int, List<bool>> _segmentsMap = {
    0: [true, true, true, true, true, true, false],
    1: [false, true, true, false, false, false, false],
    2: [true, true, false, true, true, false, true],
    3: [true, true, true, true, false, false, true],
    4: [false, true, true, false, false, true, true],
    5: [true, false, true, true, false, true, true],
    6: [true, false, true, true, true, true, true],
    7: [true, true, true, false, false, false, false],
    8: [true, true, true, true, true, true, true],
    9: [true, true, true, true, false, true, true],
  };

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final t = (w * 0.17).clamp(2.5, 8.0); // segment thickness
    final p = t * 0.35; // margin gap between segments

    final activeSegs = _segmentsMap[digit] ?? _segmentsMap[8]!;

    void drawSegment(int index, RRect rrect) {
      final isActive = activeSegs[index];
      final paint = Paint()
        ..color = isActive ? activeColor : inactiveColor
        ..style = PaintingStyle.fill;

      // Subtle soft aura for lit segments (anti-glare at night, crisp contrast)
      if (isActive) {
        final glowPaint = Paint()
          ..color = activeColor.withOpacity(0.22)
          ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 2.0);
        canvas.drawRRect(rrect, glowPaint);
      }

      canvas.drawRRect(rrect, paint);
    }

    final cornerRad = Radius.circular(t * 0.35);

    // Segment a (Top horizontal)
    drawSegment(
      0,
      RRect.fromRectAndRadius(
        Rect.fromLTWH(p + t, 0, w - 2 * p - 2 * t, t),
        cornerRad,
      ),
    );

    // Segment b (Top-right vertical)
    drawSegment(
      1,
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w - t, p + t, t, h / 2 - 2 * p - 1.5 * t),
        cornerRad,
      ),
    );

    // Segment c (Bottom-right vertical)
    drawSegment(
      2,
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w - t, h / 2 + p + 0.5 * t, t, h / 2 - 2 * p - 1.5 * t),
        cornerRad,
      ),
    );

    // Segment d (Bottom horizontal)
    drawSegment(
      3,
      RRect.fromRectAndRadius(
        Rect.fromLTWH(p + t, h - t, w - 2 * p - 2 * t, t),
        cornerRad,
      ),
    );

    // Segment e (Bottom-left vertical)
    drawSegment(
      4,
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, h / 2 + p + 0.5 * t, t, h / 2 - 2 * p - 1.5 * t),
        cornerRad,
      ),
    );

    // Segment f (Top-left vertical)
    drawSegment(
      5,
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, p + t, t, h / 2 - 2 * p - 1.5 * t),
        cornerRad,
      ),
    );

    // Segment g (Middle horizontal)
    drawSegment(
      6,
      RRect.fromRectAndRadius(
        Rect.fromLTWH(p + t, h / 2 - t / 2, w - 2 * p - 2 * t, t),
        cornerRad,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant _SingleSevenSegmentPainter oldDelegate) {
    return oldDelegate.digit != digit ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.inactiveColor != inactiveColor;
  }
}

// ---------------------------------------------------------------------------
// MODERN DIGITAL CLUSTER ARC PAINTER (NO NEEDLE)
// ---------------------------------------------------------------------------
class _DigitalClusterArcPainter extends CustomPainter {
  final double speed;
  final double maxSpeed; // Default: 100 km/h
  final double speedLimit;
  final bool isExceeded;
  final bool isCompact;
  final bool isFunMode;

  _DigitalClusterArcPainter({
    required this.speed,
    required this.maxSpeed,
    required this.speedLimit,
    required this.isExceeded,
    this.isCompact = false,
    this.isFunMode = false,
  });

  // Gauge angles: 140 degrees to 400 degrees => span of 260 deg
  static const double _startAngle = 140 * pi / 180;
  static const double _sweepAngle = 260 * pi / 180;
  static const int _numTicks = 101; // 101 high-density fine needle ticks ("jarum-jarum kecil")

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outerRadius = size.width / 2 - (isCompact ? 8.0 : 12.0);

    // 1. Sleek Outer Bezel Ring Track
    final outerTrackPaint = Paint()
      ..color = const Color(0xFF1B202C)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: outerRadius + 1.0),
      _startAngle,
      _sweepAngle,
      false,
      outerTrackPaint,
    );

    // 2. Subtle Inner Baseline Track
    final majorTickLen = isCompact ? 13.0 : 16.0;
    final innerTrackPaint = Paint()
      ..color = const Color(0xFF13171F)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: outerRadius - majorTickLen),
      _startAngle,
      _sweepAngle,
      false,
      innerTrackPaint,
    );

    // 3. High-Density Fine Needle Ticks ("Jarum-jarum Kecil")
    final progress = (speed / maxSpeed).clamp(0.0, 1.0);
    final activeTickCount = (progress * (_numTicks - 1)).round();
    final hasSpeed = speed > 0.4;

    for (int i = 0; i < _numTicks; i++) {
      final t = i / (_numTicks - 1);
      final angle = _startAngle + (_sweepAngle * t);
      final isActive = hasSpeed && (i <= activeTickCount);
      final isLeading = isActive && (i == activeTickCount);

      // Hierarchy of needle ticks (major every 10, medium every 5, minor for rest)
      final bool isMajor = (i % 10 == 0);
      final bool isMedium = !isMajor && (i % 5 == 0);

      final double tickLength;
      final double strokeWidth;
      if (isMajor) {
        tickLength = isCompact ? 13.0 : 16.0;
        strokeWidth = isCompact ? 2.0 : 2.5;
      } else if (isMedium) {
        tickLength = isCompact ? 9.5 : 12.0;
        strokeWidth = isCompact ? 1.5 : 1.9;
      } else {
        tickLength = isCompact ? 6.5 : 8.5;
        strokeWidth = isCompact ? 1.1 : 1.4;
      }

      // Needle tick color calculation
      Color needleColor;
      if (isActive) {
        if (isExceeded) {
          needleColor = AppTheme.alertRed;
        } else if (isFunMode) {
          if (t < 0.35) {
            needleColor = const Color(0xFF00E5FF); // Electric Ice Cyan
          } else if (t < 0.70) {
            needleColor = const Color(0xFF38BDF8); // Sky Azure Blue
          } else {
            needleColor = const Color(0xFFA855F7); // Futuristic Neon Violet
          }
        } else {
          if (t < 0.60) {
            needleColor = const Color(0xFFCBD5E1); // Sleek Silver Slate
          } else {
            needleColor = const Color(0xFFFFFFFF); // Crisp Bright White
          }
        }
      } else {
        // Dark graphite inactive ticks
        if (isMajor) {
          needleColor = const Color(0xFF28303F);
        } else if (isMedium) {
          needleColor = const Color(0xFF1E2430);
        } else {
          needleColor = const Color(0xFF151922);
        }
      }

      final pOuter = Offset(
        center.dx + outerRadius * cos(angle),
        center.dy + outerRadius * sin(angle),
      );
      final pInner = Offset(
        center.dx + (outerRadius - tickLength) * cos(angle),
        center.dy + (outerRadius - tickLength) * sin(angle),
      );

      final needlePaint = Paint()
        ..color = isLeading ? (isFunMode ? const Color(0xFF53FAFF) : Colors.white) : needleColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = isLeading ? strokeWidth + 0.8 : strokeWidth
        ..strokeCap = StrokeCap.round;

      // Subtle soft glow for active needles
      if (isActive) {
        final glowPaint = Paint()
          ..color = needleColor.withOpacity(isLeading ? 0.45 : 0.12)
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth + (isLeading ? 2.5 : 1.0)
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0);
        canvas.drawLine(pInner, pOuter, glowPaint);
      }

      canvas.drawLine(pInner, pOuter, needlePaint);

      // Leading Cursor Head Pip (Ultra-satisfying laser-like leading indicator)
      if (isLeading) {
        final glowColor = isExceeded
            ? AppTheme.alertRed
            : (isFunMode ? const Color(0xFF00E5FF) : Colors.white);

        final cursorGlowPaint = Paint()
          ..color = glowColor.withOpacity(0.5)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.5);
        canvas.drawCircle(pOuter, isCompact ? 3.0 : 4.0, cursorGlowPaint);

        final cursorBeadPaint = Paint()
          ..color = isExceeded
              ? AppTheme.alertRed
              : (isFunMode ? const Color(0xFF53FAFF) : Colors.white)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(pOuter, isCompact ? 1.6 : 2.2, cursorBeadPaint);
      }
    }

  }

  @override
  bool shouldRepaint(covariant _DigitalClusterArcPainter oldDelegate) {
    return oldDelegate.speed != speed ||
        oldDelegate.isExceeded != isExceeded ||
        oldDelegate.speedLimit != speedLimit ||
        oldDelegate.maxSpeed != maxSpeed ||
        oldDelegate.isCompact != isCompact ||
        oldDelegate.isFunMode != isFunMode;
  }
}
