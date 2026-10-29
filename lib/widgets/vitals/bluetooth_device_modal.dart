import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:provider/provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../theme/app_theme.dart';

class BluetoothDeviceModal extends StatefulWidget {
  const BluetoothDeviceModal({super.key});

  @override
  State<BluetoothDeviceModal> createState() => _BluetoothDeviceModalState();
}

class _BluetoothDeviceModalState extends State<BluetoothDeviceModal> {
  bool _showHelpGuide = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ble = context.read<DashboardProvider>().bleService;
      ble.startScan();
    });
  }

  @override
  void dispose() {
    final ble = context.read<DashboardProvider>().bleService;
    ble.stopScan();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DashboardProvider>();
    final ble = provider.bleService;
    final vitals = provider.vitals;

    final screenHeight = MediaQuery.of(context).size.height;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Container(
        width: 560,
        constraints: BoxConstraints(maxHeight: screenHeight * 0.88),
        decoration: AppTheme.glassCard(
          borderColor: AppTheme.border,
          fillColor: AppTheme.surface.withOpacity(0.96),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceElevated,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: const Icon(Icons.bluetooth, color: Color(0xFFFFFFFF), size: 22),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Amazfit Active 2 Connection',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      Text(
                        'Bluetooth Low Energy (BLE) Heart Rate Sensor',
                        style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, color: AppTheme.textMuted),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // 2. Connected Device Status Bar (if connected)
            if (vitals.isConnected)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceElevated,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Color(0xFFFFFFFF), size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Connected: ${vitals.deviceName}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          Text(
                            'Battery: ${vitals.batteryLevel}% • Heart Rate: ${vitals.heartRate} BPM',
                            style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () => provider.disconnectBle(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.surface,
                        foregroundColor: AppTheme.alertRed,
                        side: const BorderSide(color: AppTheme.border),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      ),
                      child: const Text('Disconnect', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),

            // 3. Scan & Auto-Connect Controls
            Row(
              children: [
                StreamBuilder<bool>(
                  stream: ble.isScanningStream,
                  initialData: false,
                  builder: (context, snapshot) {
                    final isScanning = snapshot.data ?? false;
                    return ElevatedButton.icon(
                      onPressed: () => isScanning ? ble.stopScan() : ble.startScan(),
                      icon: isScanning
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                            )
                          : const Icon(Icons.refresh, size: 16),
                      label: Text(
                        isScanning ? 'Scanning...' : 'Rescan',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFFFFFF),
                        foregroundColor: const Color(0xFF0C0D10),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    );
                  },
                ),

                const SizedBox(width: 8),

                // Auto-Connect Status Toggle
                InkWell(
                  onTap: () {
                    ble.toggleAutoConnect(!ble.autoConnectEnabled);
                    setState(() {});
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(
                      color: ble.autoConnectEnabled
                          ? const Color(0xFF2C323E)
                          : AppTheme.surfaceElevated,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: ble.autoConnectEnabled
                            ? const Color(0xFFFFFFFF)
                            : AppTheme.border,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          ble.autoConnectEnabled ? Icons.sync : Icons.sync_disabled,
                          size: 13,
                          color: ble.autoConnectEnabled ? const Color(0xFFFFFFFF) : AppTheme.textMuted,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          ble.autoConnectEnabled ? 'Auto-Connect: ON' : 'Auto-Connect: OFF',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: ble.autoConnectEnabled ? const Color(0xFFFFFFFF) : AppTheme.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const Spacer(),

                // Toggle Help Guide
                TextButton.icon(
                  onPressed: () => setState(() => _showHelpGuide = !_showHelpGuide),
                  icon: Icon(
                    _showHelpGuide ? Icons.list : Icons.help_outline,
                    size: 14,
                    color: AppTheme.textSecondary,
                  ),
                  label: Text(
                    _showHelpGuide ? 'Device List' : 'Zepp Guide',
                    style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // 4. Content: Discovered Devices List OR Amazfit Guide
            Expanded(
              child: _showHelpGuide
                  ? _buildZeppGuide()
                  : _buildDeviceList(ble, provider),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceList(dynamic ble, DashboardProvider provider) {
    return StreamBuilder<List<ScanResult>>(
      stream: ble.scanResultsStream,
      initialData: const [],
      builder: (context, snapshot) {
        final results = snapshot.data ?? [];

        if (results.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.bluetooth_searching, size: 40, color: AppTheme.textMuted),
                const SizedBox(height: 8),
                const Text(
                  'Searching for nearby Bluetooth devices...',
                  style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                ),
                const SizedBox(height: 4),
                TextButton(
                  onPressed: () => setState(() => _showHelpGuide = true),
                  child: const Text(
                    'How to connect Amazfit Active 2?',
                    style: TextStyle(fontSize: 11, color: Color(0xFFFFFFFF)),
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          itemCount: results.length,
          separatorBuilder: (_, __) => Divider(color: AppTheme.border.withOpacity(0.3), height: 1),
          itemBuilder: (context, index) {
            final item = results[index];
            final name = item.device.platformName.isNotEmpty
                ? item.device.platformName
                : 'BLE Device (${item.device.remoteId.str.substring(0, 8)})';

            final isAmazfit = name.toLowerCase().contains('amazfit') ||
                name.toLowerCase().contains('active');

            return Container(
              margin: const EdgeInsets.symmetric(vertical: 2),
              decoration: BoxDecoration(
                color: isAmazfit ? const Color(0xFF1D222A) : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                border: isAmazfit
                    ? Border.all(color: const Color(0xFF475569))
                    : null,
              ),
              child: ListTile(
                dense: true,
                leading: CircleAvatar(
                  backgroundColor: isAmazfit ? const Color(0xFFFFFFFF) : AppTheme.surfaceElevated,
                  radius: 16,
                  child: Icon(
                    Icons.watch,
                    size: 16,
                    color: isAmazfit ? const Color(0xFF0C0D10) : AppTheme.textSecondary,
                  ),
                ),
                title: Row(
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: isAmazfit ? const Color(0xFFFFFFFF) : AppTheme.textPrimary,
                        ),
                      ),
                    ),
                    if (isAmazfit) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFFFF),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'AMAZFIT',
                          style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: Color(0xFF0C0D10)),
                        ),
                      ),
                    ],
                  ],
                ),
                subtitle: Text(
                  'ID: ${item.device.remoteId} • Signal: ${item.rssi} dBm',
                  style: const TextStyle(fontSize: 10, color: AppTheme.textMuted),
                ),
                trailing: ElevatedButton(
                  onPressed: () async {
                    Navigator.of(context).pop();
                    await provider.connectToDevice(item.device);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isAmazfit ? const Color(0xFFFFFFFF) : AppTheme.surfaceElevated,
                    foregroundColor: isAmazfit ? const Color(0xFF0C0D10) : AppTheme.textPrimary,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Connect', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildZeppGuide() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceElevated.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'AMAZFIT ACTIVE 2 HEART RATE SETUP GUIDE',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: AppTheme.neonCyan,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 10),
            _buildGuideStep(
              number: '1',
              title: 'Open Zepp App on Phone',
              desc: 'Go to Profile > Select your Amazfit Active 2 watch.',
            ),
            _buildGuideStep(
              number: '2',
              title: 'Enable "Heart Rate Sharing"',
              desc: 'Select "Health Monitoring" or "Workout Heart Rate" > Enable "HR Broadcast / Heart Rate Sharing".',
            ),
            _buildGuideStep(
              number: '3',
              title: 'Or Enable Directly on Watch',
              desc: 'On Amazfit Active 2: Settings > Workout Preferences > Heart Rate Sharing > Enable.',
            ),
            _buildGuideStep(
              number: '4',
              title: 'Tap "Rescan"',
              desc: 'Return to this app and tap "Rescan". The Amazfit Active 2 will be detected via standard Bluetooth SIG 0x180D.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGuideStep({
    required String number,
    required String title,
    required String desc,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 10,
            backgroundColor: AppTheme.neonCyan.withOpacity(0.2),
            child: Text(
              number,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.neonCyan),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                ),
                const SizedBox(height: 1),
                Text(
                  desc,
                  style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
