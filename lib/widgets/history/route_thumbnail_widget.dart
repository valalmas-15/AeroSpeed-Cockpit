import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart' hide Path;
import '../../models/workout_session_model.dart';
import '../../theme/app_theme.dart';

/// Widget ikon / thumbnail preview siluet rute berkendara untuk daftar riwayat
class RouteThumbnailWidget extends StatelessWidget {
  final WorkoutSession session;
  final double width;
  final double height;
  final bool isFun;

  const RouteThumbnailWidget({
    super.key,
    required this.session,
    this.width = 68,
    this.height = 50,
    this.isFun = true,
  });

  @override
  Widget build(BuildContext context) {
    final thumbPath = session.routeThumbnailPath;
    final hasFile = thumbPath != null && thumbPath.isNotEmpty && File(thumbPath).existsSync();

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isFun ? const Color(0xFF00E5FF).withOpacity(0.35) : const Color(0xFF334155),
          width: 0.9,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(7.2),
        child: hasFile
            ? Image.file(
                File(thumbPath!),
                width: width,
                height: height,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _buildVectorFallback(),
              )
            : _buildVectorFallback(),
      ),
    );
  }

  Widget _buildVectorFallback() {
    if (!session.hasRoute) {
      return Center(
        child: Icon(
          Icons.directions_bike_rounded,
          size: min(width, height) * 0.45,
          color: isFun ? const Color(0xFF00E5FF).withOpacity(0.4) : const Color(0xFF64748B),
        ),
      );
    }

    return CustomPaint(
      size: Size(width, height),
      painter: RouteSilhouettePainter(
        points: session.routePoints,
        isFun: isFun,
      ),
    );
  }
}

/// CustomPainter untuk menggambar siluet rute GPS dengan cepat dan tajam
class RouteSilhouettePainter extends CustomPainter {
  final List<LatLng> points;
  final bool isFun;

  const RouteSilhouettePainter({
    required this.points,
    this.isFun = true,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    if (points.length == 1) {
      final center = Offset(size.width / 2, size.height / 2);
      final dotPaint = Paint()..color = const Color(0xFF00E5FF);
      canvas.drawCircle(center, 4.0, dotPaint);
      return;
    }

    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (final p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }

    double latSpan = maxLat - minLat;
    double lngSpan = maxLng - minLng;

    if (latSpan < 0.0001) latSpan = 0.0001;
    if (lngSpan < 0.0001) lngSpan = 0.0001;

    const padding = 7.0;
    final drawW = size.width - (padding * 2);
    final drawH = size.height - (padding * 2);

    final scaleX = drawW / lngSpan;
    final scaleY = drawH / latSpan;
    final scale = min(scaleX, scaleY);

    final offsetX = padding + (drawW - (lngSpan * scale)) / 2;
    final offsetY = padding + (drawH - (latSpan * scale)) / 2;

    Offset project(LatLng p) {
      final x = offsetX + ((p.longitude - minLng) * scale);
      final y = size.height - (offsetY + ((p.latitude - minLat) * scale));
      return Offset(x, y);
    }

    final offsets = points.map(project).toList();

    final path = Path();
    path.moveTo(offsets.first.dx, offsets.first.dy);
    for (int i = 1; i < offsets.length; i++) {
      path.lineTo(offsets[i].dx, offsets[i].dy);
    }

    // A. Glow luar
    final glowColor = isFun
        ? const Color(0xFF00E5FF).withOpacity(0.35)
        : const Color(0xFF38BDF8).withOpacity(0.35);
    final glowPaint = Paint()
      ..color = glowColor
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = 4.5;
    canvas.drawPath(path, glowPaint);

    // B. Garis gelap kontras
    final darkPaint = Paint()
      ..color = const Color(0xFF0A0E17)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = 3.2;
    canvas.drawPath(path, darkPaint);

    // C. Garis neon
    final neonColor = isFun ? const Color(0xFF00E5FF) : const Color(0xFF38BDF8);
    final neonPaint = Paint()
      ..color = neonColor
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = 1.8;
    canvas.drawPath(path, neonPaint);

    // D. Start Dot (Hijau)
    final startPaint = Paint()..color = const Color(0xFF10B981);
    final startBorder = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    canvas.drawCircle(offsets.first, 2.5, startPaint);
    canvas.drawCircle(offsets.first, 2.5, startBorder);

    // E. Finish Dot (Merah)
    final finishPaint = Paint()..color = const Color(0xFFEF4444);
    final finishBorder = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    canvas.drawCircle(offsets.last, 2.5, finishPaint);
    canvas.drawCircle(offsets.last, 2.5, finishBorder);
  }

  @override
  bool shouldRepaint(covariant RouteSilhouettePainter oldDelegate) {
    return oldDelegate.points != points || oldDelegate.isFun != isFun;
  }
}
