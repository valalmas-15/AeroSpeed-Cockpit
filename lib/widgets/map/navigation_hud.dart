import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/route_model.dart';
import '../../providers/dashboard_provider.dart';
import '../../theme/app_theme.dart';
import 'cancel_route_dialog.dart';

class NavigationHud extends StatelessWidget {
  final NavigationRoute? route;

  const NavigationHud({super.key, this.route});

  @override
  Widget build(BuildContext context) {
    if (route == null) return const SizedBox.shrink();

    final provider = context.watch<DashboardProvider>();
    final isRerouting = provider.isRerouting;
    final step = route!.currentStep;
    if (step == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3.5),
      decoration: BoxDecoration(
        color: AppTheme.surfaceElevated.withOpacity(0.96),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.border, width: 0.8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.55),
            blurRadius: 8,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          // 1. Maneuver Icon inside glowing badge
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: isRerouting ? AppTheme.alertRed : const Color(0xFF475569),
                width: 1.0,
              ),
            ),
            child: isRerouting
                ? const Padding(
                    padding: EdgeInsets.all(5),
                    child: CircularProgressIndicator(
                      strokeWidth: 2.0,
                      color: Colors.white,
                    ),
                  )
                : Icon(
                    step.maneuver.icon,
                    size: 16,
                    color: Colors.white,
                  ),
          ),

          const SizedBox(width: 6),

          // 2. Turn Distance and Street Name (with Reroute indicator)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isRerouting)
                  const Row(
                    children: [
                      Text(
                        'REROUTING...',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 0.4,
                        ),
                      ),
                      SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          'Mencari rute baru...',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  )
                else ...[
                  Row(
                    children: [
                      Text(
                        step.formattedDistance,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFFFFFFFF),
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          step.instruction,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFF1F5F9),
                          ),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    step.streetName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(width: 5),

          // 3. ETA, Remaining Distance & Time
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2.5),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppTheme.border, width: 0.8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.schedule, size: 10, color: Color(0xFFCBD5E1)),
                    const SizedBox(width: 2.5),
                    Text(
                      route!.formattedEta,
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFFFFFFFF),
                      ),
                    ),
                  ],
                ),
                Text(
                  '${route!.formattedRemainingDistance} • ${route!.formattedDuration}',
                  style: const TextStyle(
                    fontSize: 8.5,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textMuted,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 5),

          // 4. Cancel Route Button (with confirmation to prevent accidental clicks)
          Tooltip(
            message: 'Batalkan Rute',
            child: InkWell(
              onTap: () {
                CancelRouteConfirmDialog.show(context);
              },
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding: const EdgeInsets.all(5.5),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppTheme.border, width: 0.8),
                ),
                child: const Icon(Icons.close, size: 13, color: AppTheme.textSecondary),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
