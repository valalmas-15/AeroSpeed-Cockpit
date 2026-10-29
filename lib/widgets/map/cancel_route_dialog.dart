import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/route_model.dart';
import '../../providers/dashboard_provider.dart';
import '../../theme/app_theme.dart';

class CancelRouteConfirmDialog extends StatelessWidget {
  final NavigationRoute route;

  const CancelRouteConfirmDialog({
    super.key,
    required this.route,
  });

  /// Shows the confirmation dialog. Returns true if user confirmed cancellation.
  static Future<bool> show(BuildContext context) async {
    final provider = context.read<DashboardProvider>();
    final activeRoute = provider.currentRoute;
    if (activeRoute == null) return false;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (_) => ChangeNotifierProvider.value(
        value: provider,
        child: CancelRouteConfirmDialog(route: activeRoute),
      ),
    );

    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DashboardProvider>();
    final isFunMode = provider.isFunMode;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Container(
        width: 440,
        decoration: AppTheme.glassCard(
          borderColor: const Color(0xFFE11D48).withOpacity(0.6),
          fillColor: const Color(0xFF0F172A).withOpacity(0.98),
          radius: 12,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE11D48).withOpacity(0.15),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFE11D48).withOpacity(0.5)),
                  ),
                  child: const Icon(Icons.close_rounded, color: Color(0xFFF43F5E), size: 18),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'BATALKAN NAVIGASI RUTE?',
                        style: TextStyle(
                          fontSize: 12.0,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                      SizedBox(height: 1),
                      Text(
                        'Konfirmasi Penghentian Petunjuk Arah',
                        style: TextStyle(
                          fontSize: 10.0,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 18, color: AppTheme.textMuted),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                  onPressed: () => Navigator.of(context).pop(false),
                ),
              ],
            ),

            const SizedBox(height: 10),
            const Divider(color: Color(0xFF334155), height: 1),
            const SizedBox(height: 10),

            // Route Destination Card
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B).withOpacity(0.6),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF334155), width: 0.8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.navigation,
                    size: 16,
                    color: isFunMode ? const Color(0xFF00E5FF) : const Color(0xFFCBD5E1),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          route.destinationName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Sisa: ${route.formattedRemainingDistance} • Estimasi ${route.formattedDuration}',
                          style: const TextStyle(
                            fontSize: 10.0,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            const Text(
              'Apakah Anda yakin ingin menghentikan petunjuk arah dan membatalkan rute perjalanan saat ini?',
              style: TextStyle(
                fontSize: 11.0,
                height: 1.35,
                fontWeight: FontWeight.w500,
                color: AppTheme.textSecondary,
              ),
            ),

            const SizedBox(height: 14),

            // Action Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Button 1: Tetap Lanjutkan (Aman / Safe default)
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E293B),
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Color(0xFF475569)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                  child: const Text(
                    'LANJUTKAN RUTE',
                    style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(width: 8),
                // Button 2: Ya, Batalkan (Danger / Red Accent)
                ElevatedButton.icon(
                  onPressed: () {
                    provider.cancelCurrentRoute();
                    Navigator.of(context).pop(true);
                  },
                  icon: const Icon(Icons.close, size: 14),
                  label: const Text(
                    'YA, BATALKAN',
                    style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w900),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE11D48),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

