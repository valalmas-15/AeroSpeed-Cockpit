import 'package:flutter/material.dart';
import '../../models/vital_signs.dart';
import '../../theme/app_theme.dart';

class EcgLiveGraph extends StatelessWidget {
  final List<HeartRateDataPoint> history;
  final Color strokeColor;

  const EcgLiveGraph({
    super.key,
    required this.history,
    this.strokeColor = AppTheme.alertRed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.surfaceElevated.withOpacity(0.5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.border.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.show_chart, size: 12, color: strokeColor),
                    const SizedBox(width: 3),
                    Flexible(
                      child: Text(
                        'LIVE ECG / PULSE',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 9.0,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textSecondary,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${history.length} pts',
                style: const TextStyle(
                  fontSize: 8.5,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: CustomPaint(
                painter: _EcgPainter(
                  history: history,
                  lineColor: strokeColor,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EcgPainter extends CustomPainter {
  final List<HeartRateDataPoint> history;
  final Color lineColor;

  _EcgPainter({required this.history, required this.lineColor});

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Telemetry Grid Lines (Subtle Slate Monochrome)
    final gridPaint = Paint()
      ..color = const Color(0xFF2C323E).withOpacity(0.4)
      ..strokeWidth = 0.8;

    const int vCols = 5;
    for (int i = 1; i < vCols; i++) {
      final x = size.width * (i / vCols);
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    const int hRows = 2;
    for (int i = 1; i < hRows; i++) {
      final y = size.height * (i / hRows);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    if (history.length < 2) {
      final basePaint = Paint()
        ..color = lineColor.withOpacity(0.2)
        ..strokeWidth = 1.0;
      canvas.drawLine(
        Offset(0, size.height / 2),
        Offset(size.width, size.height / 2),
        basePaint,
      );
      return;
    }

    // 2. Find min and max for scaling
    int minBpm = 50;
    int maxBpm = 180;
    for (var p in history) {
      if (p.bpm < minBpm) minBpm = p.bpm - 5;
      if (p.bpm > maxBpm) maxBpm = p.bpm + 5;
    }
    final range = (maxBpm - minBpm).clamp(20, 200);

    // 3. Build Smooth Bezier Path
    final path = Path();
    final fillPath = Path();

    final stepX = size.width / (history.length - 1);

    for (int i = 0; i < history.length; i++) {
      final bpm = history[i].bpm;
      final normalized = (bpm - minBpm) / range;
      final y = size.height - (normalized * (size.height - 8)) - 4;
      final x = i * stepX;

      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        final prevBpm = history[i - 1].bpm;
        final prevNorm = (prevBpm - minBpm) / range;
        final prevY = size.height - (prevNorm * (size.height - 8)) - 4;
        final prevX = (i - 1) * stepX;

        final midX = (prevX + x) / 2;
        path.cubicTo(midX, prevY, midX, y, x, y);
        fillPath.cubicTo(midX, prevY, midX, y, x, y);
      }

      if (i == history.length - 1) {
        fillPath.lineTo(x, size.height);
        fillPath.close();
      }
    }

    // 4. Fill Gradient under Curve (Soft, Anti-glare)
    final fillGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        lineColor.withOpacity(0.12),
        lineColor.withOpacity(0.0),
      ],
    );

    final fillPaint = Paint()
      ..shader = fillGradient.createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;
    canvas.drawPath(fillPath, fillPaint);

    // 5. Stroke Waveform
    final strokePaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, strokePaint);

    // 6. Glowing dot at the newest data point
    final lastBpm = history.last.bpm;
    final lastNorm = (lastBpm - minBpm) / range;
    final lastY = size.height - (lastNorm * (size.height - 8)) - 4;
    final lastPoint = Offset(size.width, lastY);

    canvas.drawCircle(
      lastPoint,
      3.0,
      Paint()..color = lineColor,
    );
  }

  @override
  bool shouldRepaint(covariant _EcgPainter oldDelegate) {
    return oldDelegate.history.length != history.length ||
        oldDelegate.lineColor != lineColor;
  }
}
