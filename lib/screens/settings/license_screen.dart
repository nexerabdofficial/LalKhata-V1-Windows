import 'package:flutter/material.dart';

import '../../services/license_service.dart';

class LicenseScreen extends StatefulWidget {
  const LicenseScreen({super.key});

  @override
  State<LicenseScreen> createState() => _LicenseScreenState();
}

class _LicenseScreenState extends State<LicenseScreen> {
  final LicenseService _licenseService =
      LicenseService.instance;

  LicenseResult? _result;

  bool _loading = true;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    _loadLicense();
  }

  // ==========================================================
  // LOAD LICENSE
  // ==========================================================

  Future<void> _loadLicense() async {
    if (mounted) {
      setState(() {
        _loading = true;
      });
    }

    final result =
        await _licenseService.verifyNow();

    if (!mounted) return;

    setState(() {
      _result = result;
      _loading = false;
    });
  }

  // ==========================================================
  // REFRESH
  // ==========================================================

  Future<void> _refreshLicense() async {
    if (_refreshing) return;

    setState(() {
      _refreshing = true;
    });

    final result =
        await _licenseService.verifyNow();

    if (!mounted) return;

    setState(() {
      _result = result;
      _refreshing = false;
    });
  }

  // ==========================================================
  // DATE
  // ==========================================================

  String _formatDate(DateTime? date) {
    if (date == null) return 'Lifetime';

    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    return '${date.day.toString().padLeft(2, '0')} '
        '${months[date.month - 1]} '
        '${date.year}';
  }

  // ==========================================================
  // DURATION
  // ==========================================================

  String _formatDuration(String? duration) {
    switch (duration) {
      case '7_days':
        return '7 Days';

      case '30_days':
        return '30 Days';

      case '1_year':
        return '1 Year';

      case 'lifetime':
        return 'Lifetime';

      default:
        return duration ?? '-';
    }
  }

  // ==========================================================
  // PLATFORM
  // ==========================================================

  IconData _platformIcon(String platform) {
    switch (platform.toLowerCase()) {
      case 'android':
        return Icons.phone_android_rounded;

      case 'ios':
        return Icons.phone_iphone_rounded;

      case 'windows':
        return Icons.desktop_windows_rounded;

      case 'linux':
        return Icons.computer_rounded;

      case 'macos':
        return Icons.laptop_mac_rounded;

      case 'web':
        return Icons.language_rounded;

      default:
        return Icons.devices_rounded;
    }
  }

  String _platformName(String platform) {
    switch (platform.toLowerCase()) {
      case 'android':
        return 'Android';

      case 'ios':
        return 'iPhone / iOS';

      case 'windows':
        return 'Windows';

      case 'linux':
        return 'Linux';

      case 'macos':
        return 'macOS';

      case 'web':
        return 'Web';

      default:
        return platform.isEmpty
            ? 'Unknown Device'
            : platform;
    }
  }

  // ==========================================================
  // STATUS COLOR
  // ==========================================================

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return Colors.green;

      case 'inactive':
        return Colors.orange;

      default:
        return Colors.grey;
    }
  }

  // ==========================================================
  // BUILD
  // ==========================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'License & Devices',
          style: TextStyle(
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed:
                _refreshing ? null : _refreshLicense,
            icon: _refreshing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child:
                        CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(
                    Icons.refresh_rounded,
                  ),
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : RefreshIndicator(
              onRefresh: _refreshLicense,
              child: ListView(
                physics:
                    const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                  16,
                  16,
                  16,
                  32,
                ),
                children: [
                  _buildLicenseOverview(),
                  const SizedBox(height: 16),
                  _buildDeviceUsage(),
                  const SizedBox(height: 16),
                  _buildRegisteredDevices(),
                  const SizedBox(height: 16),
                  _buildSupportCard(),
                ],
              ),
            ),
    );
  }

  // ==========================================================
  // LICENSE OVERVIEW
  // ==========================================================

  Widget _buildLicenseOverview() {
    final result = _result;

    final active =
        result?.success == true;

    final statusColor =
        active ? Colors.green : Colors.red;

    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: statusColor.withValues(
              alpha: 0.25,
            ),
          ),
          borderRadius:
              BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: statusColor.withValues(
                      alpha: 0.10,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    active
                        ? Icons.verified_rounded
                        : Icons.error_outline_rounded,
                    color: statusColor,
                    size: 30,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'License Status',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        active
                            ? 'Active'
                            : 'Inactive',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight:
                              FontWeight.w800,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest
                    .withValues(alpha: 0.45),
                borderRadius:
                    BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Business',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    result?.businessName ?? '-',
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight:
                          FontWeight.w700,
                    ),
                  ),
                  if (result?.customerCode !=
                      null) ...[
                    const SizedBox(height: 4),
                    Text(
                      result!.customerCode!,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.grey,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 20),

            _buildLicenseInfoRow(
              Icons.workspace_premium_rounded,
              'Plan',
              _formatDuration(
                result?.duration,
              ),
            ),

            _buildLicenseInfoRow(
              Icons.calendar_today_rounded,
              'Activated',
              _formatDate(
                result?.activatedAt,
              ),
            ),

            _buildLicenseInfoRow(
              Icons.event_rounded,
              'Expires',
              result?.duration ==
                      'lifetime'
                  ? 'Never'
                  : _formatDate(
                      result?.expiresAt,
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================
  // DEVICE USAGE
  // ==========================================================

  Widget _buildDeviceUsage() {
    final result = _result;

    final maxDevices =
        result?.maxDevices ?? 1;

    final usedDevices =
        result?.usedDevices ?? 0;

    final safeMax =
        maxDevices <= 0 ? 1 : maxDevices;

    final progress =
        (usedDevices / safeMax)
            .clamp(0.0, 1.0);

    final isFull =
        usedDevices >= safeMax;

    final color =
        isFull ? Colors.orange : Colors.green;

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.devices_rounded,
                  size: 24,
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Device Usage',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight:
                          FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  '$usedDevices / $maxDevices',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight:
                        FontWeight.w800,
                    color: color,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            ClipRRect(
              borderRadius:
                  BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 9,
                backgroundColor:
                    Colors.grey.shade200,
                color: color,
              ),
            ),

            const SizedBox(height: 10),

            Text(
              isFull
                  ? 'All available device slots are currently in use.'
                  : '${safeMax - usedDevices} device slot available.',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================
  // REGISTERED DEVICES
  // ==========================================================

  Widget _buildRegisteredDevices() {
    final devices =
        _result?.devices ?? [];

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.devices_other_rounded,
                  size: 24,
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Registered Devices',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight:
                          FontWeight.w700,
                    ),
                  ),
                ),
                if (devices.isNotEmpty)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      borderRadius:
                          BorderRadius.circular(20),
                      color: Colors.green
                          .withValues(
                        alpha: 0.10,
                      ),
                    ),
                    child: Text(
                      '${devices.length}',
                      style: const TextStyle(
                        fontWeight:
                            FontWeight.w700,
                        color: Colors.green,
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 16),

            if (devices.isEmpty)
              _buildEmptyDevices()
            else
              ...devices.map(
                _buildDeviceTile,
              ),
          ],
        ),
      ),
    );
  }

  // ==========================================================
  // EMPTY DEVICES
  // ==========================================================

  Widget _buildEmptyDevices() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius:
            BorderRadius.circular(12),
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.35),
      ),
      child: const Column(
        children: [
          Icon(
            Icons.devices_other_outlined,
            size: 42,
            color: Colors.grey,
          ),
          SizedBox(height: 10),
          Text(
            'No registered devices found',
            style: TextStyle(
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 5),
          Text(
            'Pull down to refresh the license information.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // DEVICE TILE
  // ==========================================================

  Widget _buildDeviceTile(
    LicenseDevice device,
  ) {
    final active =
        device.status.toLowerCase() ==
            'active';

    final color = _statusColor(
      device.status,
    );

    final deviceName =
        device.deviceName.trim().isNotEmpty
            ? device.deviceName.trim()
            : _platformName(
                device.platform,
              );

    return Container(
      margin:
          const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius:
            BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey.shade200,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: Theme.of(context)
                  .colorScheme
                  .primary
                  .withValues(alpha: 0.08),
              borderRadius:
                  BorderRadius.circular(12),
            ),
            child: Icon(
              _platformIcon(
                device.platform,
              ),
              color: Theme.of(context)
                  .colorScheme
                  .primary,
              size: 24,
            ),
          ),

          const SizedBox(width: 13),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  deviceName,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight:
                        FontWeight.w700,
                  ),
                ),

                const SizedBox(height: 3),

                Text(
                  _platformName(
                    device.platform,
                  ),
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),

                if (device.lastVerifiedAt !=
                    null) ...[
                  const SizedBox(height: 3),
                  Text(
                    'Last verified: '
                    '${_formatDateTime(
                      device.lastVerifiedAt,
                    )}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(width: 8),

          Container(
            padding:
                const EdgeInsets.symmetric(
              horizontal: 9,
              vertical: 5,
            ),
            decoration: BoxDecoration(
              borderRadius:
                  BorderRadius.circular(20),
              color: color.withValues(
                alpha: 0.10,
              ),
            ),
            child: Row(
              mainAxisSize:
                  MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration:
                      BoxDecoration(
                    shape: BoxShape.circle,
                    color: color,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  active
                      ? 'Active'
                      : 'Inactive',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight:
                        FontWeight.w700,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // DATE TIME
  // ==========================================================

  String _formatDateTime(
    DateTime? date,
  ) {
    if (date == null) return '-';

    final local = date.toLocal();

    final hour =
        local.hour.toString().padLeft(2, '0');

    final minute =
        local.minute.toString().padLeft(2, '0');

    return '${_formatDate(local)} '
        '$hour:$minute';
  }

  // ==========================================================
  // SUPPORT
  // ==========================================================

  Widget _buildSupportCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius:
            BorderRadius.circular(12),
        color: Theme.of(context)
            .colorScheme
            .primary
            .withValues(alpha: 0.06),
        border: Border.all(
          color: Theme.of(context)
              .colorScheme
              .primary
              .withValues(alpha: 0.12),
        ),
      ),
      child: const Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.support_agent_rounded,
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  'Need help with your license?',
                  style: TextStyle(
                    fontWeight:
                        FontWeight.w700,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  'Device activation and license '
                  'management are controlled by '
                  'NexEra IT BD.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // LICENSE INFO ROW
  // ==========================================================

  Widget _buildLicenseInfoRow(
    IconData icon,
    String title,
    String value,
  ) {
    return Padding(
      padding:
          const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: Colors.grey.shade600,
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 82,
            child: Text(
              title,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight:
                    FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}