import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/province_offline_model.dart';
import '../../providers/dashboard_provider.dart';
import '../../theme/app_theme.dart';

class OfflineMapUpdateBanner extends StatelessWidget {
  final ProvinceOfflinePack province;

  const OfflineMapUpdateBanner({
    super.key,
    required this.province,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DashboardProvider>();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withOpacity(0.96),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(
          color: provider.isFunMode ? const Color(0xFF00E5FF).withOpacity(0.7) : const Color(0xFF64748B),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.7),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: province.isDownloading
          ? _buildDownloadingState(context)
          : _buildPromptState(context, provider.isFunMode),
    );
  }

  Widget _buildPromptState(BuildContext context, bool isFunMode) {
    return Row(
      children: [
        // Pulsing / Glowing Map Offline Icon
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: (isFunMode ? const Color(0xFF00E5FF) : Colors.white).withOpacity(0.12),
            shape: BoxShape.circle,
            border: Border.all(
              color: isFunMode ? const Color(0xFF00E5FF) : Colors.white,
              width: 1.0,
            ),
          ),
          child: Icon(
            Icons.cloud_download,
            size: 15,
            color: isFunMode ? const Color(0xFF00E5FF) : Colors.white,
          ),
        ),
        const SizedBox(width: 8),

        // Text Info (Cockpit Friendly)
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Text(
                    'UPDATE PETA OFFLINE',
                    style: TextStyle(
                      fontSize: 10.0,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: const Color(0xFF475569), width: 0.5),
                    ),
                    child: Text(
                      province.name,
                      style: TextStyle(
                        fontSize: 9.0,
                        fontWeight: FontWeight.w800,
                        color: isFunMode ? const Color(0xFF00E5FF) : const Color(0xFFE2E8F0),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 1),
              Text(
                'Terhubung internet: Unduh peta & ${province.poiCount}+ tempat (${province.estimatedSizeMb.toStringAsFixed(1)} MB) agar bisa full offline.',
                style: const TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),

        const SizedBox(width: 8),

        // Action: Unduh Sekarang
        ElevatedButton.icon(
          onPressed: () async {
            final ok = await context.read<DashboardProvider>().downloadOfflineProvince(province.id);
            if (!ok && context.mounted) {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('⚠️ Gagal mengunduh peta: Pastikan perangkat terhubung ke internet.'),
                  duration: Duration(seconds: 2),
                  backgroundColor: Color(0xFF1E293B),
                ),
              );
            }
          },
          icon: const Icon(Icons.download, size: 12),
          label: const Text(
            'UNDUH',
            style: TextStyle(fontSize: 10.0, fontWeight: FontWeight.w900),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: isFunMode ? const Color(0xFF00E5FF) : Colors.white,
            foregroundColor: const Color(0xFF0C0D10),
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            minimumSize: const Size(60, 26),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          ),
        ),

        const SizedBox(width: 5),

        // Action: Ingatkan Besok / Tolak (Throttled for 24 hours!)
        OutlinedButton(
          onPressed: () {
            context.read<DashboardProvider>().dismissOfflinePrompt(province.id);
          },
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF94A3B8),
            side: const BorderSide(color: Color(0xFF475569), width: 0.8),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            minimumSize: const Size(50, 26),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          ),
          child: const Text(
            'INGATKAN BESOK',
            style: TextStyle(fontSize: 9.0, fontWeight: FontWeight.w800),
          ),
        ),

        const SizedBox(width: 2),

        // Close Icon (also dismisses for 24 hours)
        IconButton(
          icon: const Icon(Icons.close, size: 14, color: AppTheme.textMuted),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
          onPressed: () {
            context.read<DashboardProvider>().dismissOfflinePrompt(province.id);
          },
        ),
      ],
    );
  }

  Widget _buildDownloadingState(BuildContext context) {
    final pct = (province.downloadProgress * 100).round();

    return Row(
      children: [
        const SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(
            strokeWidth: 2.0,
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00E5FF)),
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Mengunduh Peta Offline ${province.name}...',
                    style: const TextStyle(
                      fontSize: 10.0,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    '$pct%',
                    style: const TextStyle(
                      fontSize: 10.0,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF00E5FF),
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: province.downloadProgress,
                  minHeight: 4,
                  backgroundColor: const Color(0xFF1E293B),
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF00E5FF)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

