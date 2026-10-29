import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/province_offline_model.dart';
import '../../providers/dashboard_provider.dart';
import '../../services/offline_map_service.dart';
import '../../theme/app_theme.dart';

// 1. Popup Dialog Pembaruan Harian (Muncul Otomatis Jika Hari Ini Belum Update)
class OfflineMapDailyUpdateDialog extends StatefulWidget {
  final ProvinceOfflinePack province;

  const OfflineMapDailyUpdateDialog({
    super.key,
    required this.province,
  });

  static Future<void> show(BuildContext context, ProvinceOfflinePack province) async {
    final provider = context.read<DashboardProvider>();
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => ChangeNotifierProvider.value(
        value: provider,
        child: OfflineMapDailyUpdateDialog(province: province),
      ),
    );
  }

  @override
  State<OfflineMapDailyUpdateDialog> createState() => _OfflineMapDailyUpdateDialogState();
}

class _OfflineMapDailyUpdateDialogState extends State<OfflineMapDailyUpdateDialog> {
  bool _isDownloading = false;
  double _progress = 0.0;
  bool _isFinished = false;
  String? _errorMessage;

  void _startDownload() async {
    final provider = context.read<DashboardProvider>();
    setState(() {
      _isDownloading = true;
      _progress = 0.05;
      _errorMessage = null;
    });

    try {
      await provider.offlineMapService.downloadProvince(
        widget.province.id,
        onProgress: (p) {
          if (mounted) {
            setState(() => _progress = p);
          }
        },
      );

      if (mounted) {
        setState(() {
          _isDownloading = false;
          _isFinished = true;
        });

        await Future.delayed(const Duration(milliseconds: 1200));
        if (mounted) {
          Navigator.of(context, rootNavigator: true).pop();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  void _dismissForToday() async {
    final provider = context.read<DashboardProvider>();
    await provider.dismissOfflinePrompt(widget.province.id);
    if (mounted) {
      Navigator.of(context, rootNavigator: true).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DashboardProvider>();
    final isFunMode = provider.isFunMode;
    final primaryColor = isFunMode ? const Color(0xFF00E5FF) : Colors.white;
    final isConnected = provider.isInternetConnected;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Container(
        width: 480,
        decoration: AppTheme.glassCard(
          borderColor: isFunMode ? const Color(0xFF00E5FF).withOpacity(0.5) : const Color(0xFF475569),
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
                    color: primaryColor.withOpacity(0.12),
                    shape: BoxShape.circle,
                    border: Border.all(color: primaryColor.withOpacity(0.4)),
                  ),
                  child: Icon(Icons.cloud_download, color: primaryColor, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'PEMBARUAN PETA OFFLINE HARIAN',
                        style: TextStyle(
                          fontSize: 12.0,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        'Provinsi: ${widget.province.name} (${widget.province.estimatedSizeMb.toStringAsFixed(1)} MB)',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: isFunMode ? const Color(0xFF00E5FF) : const Color(0xFFCBD5E1),
                        ),
                      ),
                    ],
                  ),
                ),
                if (!_isDownloading && !_isFinished)
                  IconButton(
                    icon: const Icon(Icons.close, size: 18, color: AppTheme.textMuted),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                    onPressed: _dismissForToday,
                  ),
              ],
            ),

            const SizedBox(height: 10),
            const Divider(color: Color(0xFF334155), height: 1),
            const SizedBox(height: 10),

            // Status Badge & Description
            if (!_isDownloading && !_isFinished) ...[
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: const Color(0xFFF59E0B), width: 0.8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.info_outline, size: 11, color: Color(0xFFF59E0B)),
                        SizedBox(width: 4),
                        Text(
                          'HARI INI BELUM UPDATE',
                          style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: Color(0xFFF59E0B)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Perbarui data jalan dan ${widget.province.poiCount}+ tempat offline untuk Provinsi ${widget.province.name} hari ini agar aplikasi dapat digunakan 100% full offline saat berkendara tanpa koneksi internet.',
                style: const TextStyle(
                  fontSize: 11.0,
                  height: 1.4,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textSecondary,
                ),
              ),

              if (!isConnected) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.5), width: 0.8),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.wifi_off, size: 14, color: Color(0xFFEF4444)),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Ponsel sedang offline. Hubungkan ke Wi-Fi / data seluler untuk mengunduh peta.',
                          style: TextStyle(fontSize: 10.0, fontWeight: FontWeight.w600, color: Color(0xFFFCA5A5)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              if (_errorMessage != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFEF4444), width: 0.8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, size: 14, color: Color(0xFFEF4444)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(fontSize: 10.0, fontWeight: FontWeight.w700, color: Color(0xFFFCA5A5)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 14),

              // Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: _dismissForToday,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF94A3B8),
                      side: const BorderSide(color: Color(0xFF475569)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    child: const Text('NANTI / LEWATKAN', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: !isConnected ? null : _startDownload,
                    icon: Icon(!isConnected ? Icons.wifi_off : Icons.download, size: 14),
                    label: Text(
                      !isConnected ? 'OFFLINE (TIDAK BISA UNDUH)' : 'PERBARUI SEKARANG',
                      style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w900),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: !isConnected ? const Color(0xFF334155) : primaryColor,
                      foregroundColor: !isConnected ? const Color(0xFF94A3B8) : const Color(0xFF0C0D10),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                  ),
                ],
              ),
            ],

            // Downloading Progress View
            if (_isDownloading) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Sedang mengunduh data ${widget.province.name}...',
                    style: const TextStyle(fontSize: 11.0, fontWeight: FontWeight.w700, color: Colors.white),
                  ),
                  Text(
                    '${(_progress * 100).round()}%',
                    style: TextStyle(fontSize: 12.0, fontWeight: FontWeight.w900, color: primaryColor, fontFamily: 'monospace'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: _progress,
                  minHeight: 6,
                  backgroundColor: const Color(0xFF1E293B),
                  valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Mengemas ubin peta jalan & database pencarian offline...',
                style: TextStyle(fontSize: 9.5, color: AppTheme.textMuted),
              ),
            ],

            // Finished Success View
            if (_isFinished) ...[
              Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Peta ${widget.province.name} berhasil diperbarui hari ini! Siap dipakai offline.',
                        style: const TextStyle(fontSize: 11.0, fontWeight: FontWeight.w800, color: Color(0xFF10B981)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// 2. Popup Pemastian / Konfirmasi Update Peta Manual (Mencegah Salah Klik)
class OfflineMapConfirmUpdateDialog extends StatefulWidget {
  final ProvinceOfflinePack province;

  const OfflineMapConfirmUpdateDialog({
    super.key,
    required this.province,
  });

  static Future<void> show(BuildContext context, ProvinceOfflinePack province) async {
    final provider = context.read<DashboardProvider>();
    await showDialog(
      context: context,
      builder: (_) => ChangeNotifierProvider.value(
        value: provider,
        child: OfflineMapConfirmUpdateDialog(province: province),
      ),
    );
  }

  @override
  State<OfflineMapConfirmUpdateDialog> createState() => _OfflineMapConfirmUpdateDialogState();
}

class _OfflineMapConfirmUpdateDialogState extends State<OfflineMapConfirmUpdateDialog> {
  bool _isDownloading = false;
  double _progress = 0.0;
  bool _isFinished = false;
  String? _errorMessage;

  void _startDownload() async {
    final provider = context.read<DashboardProvider>();
    setState(() {
      _isDownloading = true;
      _progress = 0.05;
      _errorMessage = null;
    });

    try {
      await provider.offlineMapService.downloadProvince(
        widget.province.id,
        onProgress: (p) {
          if (mounted) {
            setState(() => _progress = p);
          }
        },
      );

      if (mounted) {
        setState(() {
          _isDownloading = false;
          _isFinished = true;
        });

        await Future.delayed(const Duration(milliseconds: 1100));
        if (mounted) {
          Navigator.of(context, rootNavigator: true).pop();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DashboardProvider>();
    final isFunMode = provider.isFunMode;
    final primaryColor = isFunMode ? const Color(0xFF00E5FF) : Colors.white;
    final isConnected = provider.isInternetConnected;
    final isUpdatedToday = provider.offlineMapService.isProvinceUpdatedToday(widget.province.id);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Container(
        width: 460,
        decoration: AppTheme.glassCard(
          borderColor: isFunMode ? const Color(0xFF00E5FF).withOpacity(0.5) : const Color(0xFF475569),
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
                    color: const Color(0xFF3B82F6).withOpacity(0.15),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF3B82F6).withOpacity(0.5)),
                  ),
                  child: const Icon(Icons.cloud_sync, color: Color(0xFF3B82F6), size: 18),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'KONFIRMASI PEMBARUAN PETA',
                        style: TextStyle(
                          fontSize: 12.0,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                      SizedBox(height: 1),
                      Text(
                        'Pembaruan Manual Peta Offline',
                        style: TextStyle(
                          fontSize: 10.0,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!_isDownloading && !_isFinished)
                  IconButton(
                    icon: const Icon(Icons.close, size: 18, color: AppTheme.textMuted),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
              ],
            ),

            const SizedBox(height: 10),
            const Divider(color: Color(0xFF334155), height: 1),
            const SizedBox(height: 10),

            if (!_isDownloading && !_isFinished) ...[
              // Current Status Badge
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: isUpdatedToday ? const Color(0xFF10B981).withOpacity(0.15) : const Color(0xFFF59E0B).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: isUpdatedToday ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                        width: 0.8,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isUpdatedToday ? Icons.check_circle : Icons.warning_amber_rounded,
                          size: 11,
                          color: isUpdatedToday ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isUpdatedToday ? 'HARI INI SUDAH TERUPDATE' : 'HARI INI BELUM TERUPDATE',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            color: isUpdatedToday ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              Text(
                'Apakah Anda yakin ingin mengunduh ulang dan memperbarui data peta offline untuk Provinsi ${widget.province.name}?',
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),

              const SizedBox(height: 4),

              Text(
                'Estimasi ukuran unduhan: ± ${widget.province.estimatedSizeMb.toStringAsFixed(1)} MB (${widget.province.poiCount}+ tempat & ubin peta). Pastikan perangkat terhubung ke internet.',
                style: const TextStyle(
                  fontSize: 10.5,
                  height: 1.35,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textSecondary,
                ),
              ),

              if (!isConnected) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.5), width: 0.8),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.wifi_off, size: 14, color: Color(0xFFEF4444)),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Ponsel sedang offline. Hubungkan ke Wi-Fi / data seluler untuk mengunduh peta.',
                          style: TextStyle(fontSize: 10.0, fontWeight: FontWeight.w600, color: Color(0xFFFCA5A5)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              if (_errorMessage != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFEF4444), width: 0.8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, size: 14, color: Color(0xFFEF4444)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(fontSize: 10.0, fontWeight: FontWeight.w700, color: Color(0xFFFCA5A5)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 14),

              // Action Confirmation Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF94A3B8),
                      side: const BorderSide(color: Color(0xFF475569)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    child: const Text('BATAL', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: !isConnected ? null : _startDownload,
                    icon: Icon(!isConnected ? Icons.wifi_off : Icons.sync, size: 14),
                    label: Text(
                      !isConnected ? 'OFFLINE (TIDAK BISA UNDUH)' : 'YA, PERBARUI',
                      style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w900),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: !isConnected ? const Color(0xFF334155) : primaryColor,
                      foregroundColor: !isConnected ? const Color(0xFF94A3B8) : const Color(0xFF0C0D10),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                  ),
                ],
              ),
            ],

            // Downloading View
            if (_isDownloading) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Mengunduh data ${widget.province.name}...',
                    style: const TextStyle(fontSize: 11.0, fontWeight: FontWeight.w700, color: Colors.white),
                  ),
                  Text(
                    '${(_progress * 100).round()}%',
                    style: TextStyle(fontSize: 12.0, fontWeight: FontWeight.w900, color: primaryColor, fontFamily: 'monospace'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: _progress,
                  minHeight: 6,
                  backgroundColor: const Color(0xFF1E293B),
                  valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                ),
              ),
            ],

            // Finished View
            if (_isFinished) ...[
              Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Peta ${widget.province.name} berhasil diperbarui!',
                        style: const TextStyle(fontSize: 11.0, fontWeight: FontWeight.w800, color: Color(0xFF10B981)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 3. Popup Dialog Download & Kelola Peta Offline
// Bagian Atas: Pembaruan peta yang sudah didownload atau hapus peta yang sudah ada (list pilihan per provinsi)
// Bagian Bawah: Daftar peta per provinsi yang bisa didownload
// ---------------------------------------------------------------------------
class OfflineMapManagerDialog extends StatefulWidget {
  const OfflineMapManagerDialog({super.key});

  static Future<void> show(BuildContext context) async {
    final provider = context.read<DashboardProvider>();
    await showDialog(
      context: context,
      builder: (_) => ChangeNotifierProvider.value(
        value: provider,
        child: const OfflineMapManagerDialog(),
      ),
    );
  }

  @override
  State<OfflineMapManagerDialog> createState() => _OfflineMapManagerDialogState();
}

class _OfflineMapManagerDialogState extends State<OfflineMapManagerDialog> {
  StreamSubscription<ProvinceOfflinePack?>? _updateSub;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _updateSub = OfflineMapService.instance.updateStream.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _updateSub?.cancel();
    super.dispose();
  }

  Future<void> _downloadOrUpdate(ProvinceOfflinePack pack) async {
    setState(() => _errorMessage = null);
    final service = OfflineMapService.instance;

    final hasInternet = await service.checkInternetConnection(force: true);
    if (!hasInternet) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Ponsel sedang offline. Sambungkan WiFi atau data seluler untuk mengunduh peta.';
        });
      }
      return;
    }

    try {
      await service.downloadProvince(pack.id);
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  Future<void> _confirmDelete(BuildContext context, ProvinceOfflinePack pack) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
        ),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444), size: 22),
            const SizedBox(width: 8),
            const Text(
              'HAPUS PETA OFFLINE?',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Colors.white),
            ),
          ],
        ),
        content: Text(
          'Apakah Anda yakin ingin menghapus data peta offline "${pack.name}" (${pack.estimatedSizeMb.toStringAsFixed(0)} MB)?\n\nSetelah dihapus, navigasi offline untuk provinsi ini memerlukan unduh ulang.',
          style: const TextStyle(fontSize: 11, color: Color(0xFFCBD5E1), height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('BATAL', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF94A3B8))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('HAPUS PETA', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final service = OfflineMapService.instance;
      await service.deleteProvince(pack.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DashboardProvider>();
    final service = provider.offlineMapService;
    final isFunMode = provider.isFunMode;
    final primaryColor = isFunMode ? const Color(0xFF00E5FF) : Colors.white;
    final isConnected = provider.isInternetConnected;

    final downloaded = service.downloadedProvinces;
    final available = service.availableProvinces;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 580, maxHeight: 335),
        decoration: AppTheme.glassCard(
          borderColor: isFunMode ? const Color(0xFF00E5FF).withOpacity(0.5) : const Color(0xFF475569),
          fillColor: const Color(0xFF0F172A).withOpacity(0.98),
          radius: 12,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  Icon(Icons.download_for_offline, color: primaryColor, size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'DOWNLOAD & KELOLA PETA OFFLINE',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                            color: primaryColor,
                          ),
                        ),
                        const SizedBox(height: 1),
                        const Text(
                          'Pembaruan harian, hapus peta tersimpan, & download provinsi',
                          style: TextStyle(fontSize: 9.5, color: Color(0xFF94A3B8)),
                        ),
                      ],
                    ),
                  ),
                  // Online/Offline Pill Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: isConnected ? const Color(0xFF064E3B) : const Color(0xFF7F1D1D),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isConnected ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                        width: 1,
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
                            color: isConnected ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isConnected ? 'Online' : 'Offline',
                          style: TextStyle(
                            fontSize: 9.0,
                            fontWeight: FontWeight.w800,
                            color: isConnected ? const Color(0xFF34D399) : const Color(0xFFFCA5A5),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    icon: const Icon(Icons.close, color: Color(0xFF94A3B8), size: 18),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    tooltip: 'Tutup',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            const Divider(color: Color(0xFF334155), height: 1),

            // Error Banner
            if (_errorMessage != null)
              Container(
                color: const Color(0xFFEF4444).withOpacity(0.15),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Color(0xFFEF4444), size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(fontSize: 10.0, color: Color(0xFFFCA5A5), fontWeight: FontWeight.w600),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Color(0xFFFCA5A5), size: 14),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => setState(() => _errorMessage = null),
                    ),
                  ],
                ),
              ),

            // Scrollable Content
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                children: [
                  // ==========================================
                  // 1. BAGIAN ATAS: PETA YANG SUDAH DIDOWNLOAD
                  // ==========================================
                  Row(
                    children: [
                      const Icon(Icons.storage_rounded, size: 15, color: Color(0xFF10B981)),
                      const SizedBox(width: 6),
                      const Text(
                        'PETA YANG SUDAH DIDOWNLOAD',
                        style: TextStyle(
                          fontSize: 10.0,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF94A3B8),
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF064E3B),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFF059669), width: 0.8),
                        ),
                        child: Text(
                          '${downloaded.length} Terpasang',
                          style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.w800, color: Color(0xFF34D399)),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 6),

                  if (downloaded.isEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B).withOpacity(0.3),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF334155).withOpacity(0.5)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline, size: 16, color: Color(0xFF64748B)),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Belum ada peta yang didownload. Pilih provinsi di daftar bawah untuk mulai mengunduh rute offline.',
                              style: TextStyle(fontSize: 10.0, color: Color(0xFF94A3B8), fontStyle: FontStyle.italic),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    ...downloaded.map((pack) => _buildDownloadedItem(
                          context,
                          pack,
                          service,
                          isConnected,
                          isFunMode,
                          primaryColor,
                        )),

                  const SizedBox(height: 12),
                  const Divider(color: Color(0xFF334155), height: 1),
                  const SizedBox(height: 10),

                  // ==========================================
                  // 2. BAGIAN BAWAH: DAFTAR PETA YANG BISA DIDOWNLOAD
                  // ==========================================
                  Row(
                    children: [
                      Icon(Icons.cloud_download_rounded, size: 15, color: primaryColor),
                      const SizedBox(width: 6),
                      const Text(
                        'DAFTAR PETA YANG BISA DIDOWNLOAD',
                        style: TextStyle(
                          fontSize: 10.0,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF94A3B8),
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF083344),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFF0284C7), width: 0.8),
                        ),
                        child: Text(
                          '${available.length} Tersedia',
                          style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w800, color: primaryColor),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 6),

                  if (available.isEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B).withOpacity(0.3),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF334155).withOpacity(0.5)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.check_circle_outline, size: 16, color: Color(0xFF10B981)),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Semua peta provinsi di katalog telah berhasil didownload dan siap offline!',
                              style: TextStyle(fontSize: 10.0, color: Color(0xFF34D399), fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    ...available.map((pack) => _buildAvailableItem(
                          context,
                          pack,
                          service,
                          isConnected,
                          isFunMode,
                          primaryColor,
                        )),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDownloadedItem(
    BuildContext context,
    ProvinceOfflinePack pack,
    OfflineMapService service,
    bool isConnected,
    bool isFunMode,
    Color primaryColor,
  ) {
    final isUpdatedToday = service.isProvinceUpdatedToday(pack.id);

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withOpacity(0.55),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF334155).withOpacity(0.7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          pack.name,
                          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Colors.white),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: isUpdatedToday ? const Color(0xFF064E3B) : const Color(0xFF78350F),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: isUpdatedToday ? const Color(0xFF059669) : const Color(0xFFD97706),
                              width: 0.8,
                            ),
                          ),
                          child: Text(
                            isUpdatedToday ? 'Terupdate Hari Ini' : 'Perlu Pembaruan',
                            style: TextStyle(
                              fontSize: 8.0,
                              fontWeight: FontWeight.w800,
                              color: isUpdatedToday ? const Color(0xFF34D399) : const Color(0xFFFBBF24),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 1),
                    Text(
                      '${pack.estimatedSizeMb.toStringAsFixed(0)} MB • ${pack.poiCount} POI • Versi ${pack.version}',
                      style: const TextStyle(fontSize: 9.0, color: Color(0xFF94A3B8)),
                    ),
                  ],
                ),
              ),

              // Action Buttons
              if (pack.isDownloading)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(strokeWidth: 2, color: primaryColor),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${(pack.downloadProgress * 100).toInt()}%',
                        style: TextStyle(fontSize: 10.0, fontWeight: FontWeight.w800, color: primaryColor),
                      ),
                    ],
                  ),
                )
              else
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Button Update / Perbarui
                    InkWell(
                      borderRadius: BorderRadius.circular(6),
                      onTap: isConnected ? () => _downloadOrUpdate(pack) : null,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isConnected ? const Color(0xFF0F172A) : const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isConnected ? primaryColor.withOpacity(0.6) : const Color(0xFF475569),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.sync, size: 12, color: isConnected ? primaryColor : const Color(0xFF64748B)),
                            const SizedBox(width: 4),
                            Text(
                              'Update',
                              style: TextStyle(
                                fontSize: 9.0,
                                fontWeight: FontWeight.w800,
                                color: isConnected ? primaryColor : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(width: 6),

                    // Button Hapus
                    InkWell(
                      borderRadius: BorderRadius.circular(6),
                      onTap: () => _confirmDelete(context, pack),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF450A0A).withOpacity(0.5),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.6), width: 1),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.delete_outline_rounded, size: 12, color: Color(0xFFEF4444)),
                            SizedBox(width: 3),
                            Text(
                              'Hapus',
                              style: TextStyle(fontSize: 9.0, fontWeight: FontWeight.w800, color: Color(0xFFEF4444)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),

          if (pack.isDownloading) ...[
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: pack.downloadProgress,
                minHeight: 4,
                backgroundColor: const Color(0xFF0F172A),
                valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAvailableItem(
    BuildContext context,
    ProvinceOfflinePack pack,
    OfflineMapService service,
    bool isConnected,
    bool isFunMode,
    Color primaryColor,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withOpacity(0.4),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF334155).withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.public, color: Color(0xFF64748B), size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pack.name,
                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Colors.white),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      '${pack.estimatedSizeMb.toStringAsFixed(0)} MB • ${pack.poiCount} Tempat Wisata & POI • ${pack.code}',
                      style: const TextStyle(fontSize: 9.0, color: Color(0xFF94A3B8)),
                    ),
                  ],
                ),
              ),

              // Download Button or Progress
              if (pack.isDownloading)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(strokeWidth: 2, color: primaryColor),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${(pack.downloadProgress * 100).toInt()}%',
                        style: TextStyle(fontSize: 10.0, fontWeight: FontWeight.w800, color: primaryColor),
                      ),
                    ],
                  ),
                )
              else
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isConnected ? primaryColor : const Color(0xFF334155),
                    foregroundColor: isConnected ? const Color(0xFF0C0D10) : const Color(0xFF94A3B8),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    minimumSize: const Size(0, 26),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                  onPressed: isConnected ? () => _downloadOrUpdate(pack) : null,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isConnected ? Icons.file_download_outlined : Icons.wifi_off,
                        size: 13,
                        color: isConnected ? const Color(0xFF0C0D10) : const Color(0xFF94A3B8),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isConnected ? 'Download' : 'Offline',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          color: isConnected ? const Color(0xFF0C0D10) : const Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),

          if (pack.isDownloading) ...[
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: pack.downloadProgress,
                minHeight: 4,
                backgroundColor: const Color(0xFF0F172A),
                valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

