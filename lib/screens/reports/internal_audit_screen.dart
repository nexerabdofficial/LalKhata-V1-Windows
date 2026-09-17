import 'package:flutter/material.dart';

import '../../services/internal_audit_service.dart';

class InternalAuditScreen extends StatefulWidget {
  const InternalAuditScreen({super.key});

  @override
  State<InternalAuditScreen> createState() => _InternalAuditScreenState();
}

class _InternalAuditScreenState extends State<InternalAuditScreen> {
  final InternalAuditService _auditService = InternalAuditService();

  List<AuditFinding> _findings = [];
  bool _running = false;
  DateTime? _lastRun;

  int get _passCount =>
      _findings.where((f) => f.status == AuditStatus.pass).length;

  int get _warningCount =>
      _findings.where((f) => f.status == AuditStatus.warning).length;

  int get _errorCount =>
      _findings.where((f) => f.status == AuditStatus.error).length;

  Future<void> _runAudit() async {
    setState(() => _running = true);

    try {
      final findings = await _auditService.runFullAudit();

      if (!mounted) return;

      setState(() {
        _findings = findings;
        _lastRun = DateTime.now();
        _running = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() => _running = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Audit failed: $e'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  Color _statusColor(AuditStatus status) {
    switch (status) {
      case AuditStatus.pass:
        return Colors.green;
      case AuditStatus.warning:
        return Colors.orange;
      case AuditStatus.error:
        return Colors.red;
    }
  }

  IconData _statusIcon(AuditStatus status) {
    switch (status) {
      case AuditStatus.pass:
        return Icons.check_circle_rounded;
      case AuditStatus.warning:
        return Icons.warning_amber_rounded;
      case AuditStatus.error:
        return Icons.error_rounded;
    }
  }

  String _statusLabel(AuditStatus status) {
    switch (status) {
      case AuditStatus.pass:
        return 'PASS';
      case AuditStatus.warning:
        return 'WARNING';
      case AuditStatus.error:
        return 'ERROR';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Internal Audit')),
      body: RefreshIndicator(
        onRefresh: _runAudit,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _buildHeaderCard(),
            const SizedBox(height: 18),
            if (_findings.isNotEmpty) ...[
              _buildSummary(),
              const SizedBox(height: 22),
              _buildFindingsHeader(),
              const SizedBox(height: 10),
              ..._findings.map(_buildFindingCard),
            ] else
              _buildEmptyState(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF7F1D1D), Color(0xFF991B1B), Color(0xFFB91C1C)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 600;

          final title = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.fact_check_rounded,
                color: Colors.white,
                size: 34,
              ),
              const SizedBox(height: 12),
              const Text(
                'Database & Business Integrity',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _lastRun == null
                    ? 'Run a read-only audit to check your business data.'
                    : 'Last audit: ${_formatDateTime(_lastRun!)}',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 13,
                ),
              ),
            ],
          );

          final button = FilledButton.icon(
            onPressed: _running ? null : _runAudit,
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF991B1B),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            ),
            icon: _running
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.play_arrow_rounded),
            label: Text(_running ? 'Running...' : 'Run Full Audit'),
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [title, const SizedBox(height: 18), button],
            );
          }

          return Row(
            children: [
              Expanded(child: title),
              button,
            ],
          );
        },
      ),
    );
  }

  Widget _buildSummary() {
    return Row(
      children: [
        Expanded(
          child: _summaryCard(
            'PASS',
            _passCount,
            Colors.green,
            Icons.check_circle_rounded,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _summaryCard(
            'WARNING',
            _warningCount,
            Colors.orange,
            Icons.warning_amber_rounded,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _summaryCard(
            'ERROR',
            _errorCount,
            Colors.red,
            Icons.error_rounded,
          ),
        ),
      ],
    );
  }

  Widget _summaryCard(String title, int count, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 25),
          const SizedBox(height: 7),
          Text(
            '$count',
            style: TextStyle(
              color: color,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFindingsHeader() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        'Audit Findings',
        style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
      ),
    );
  }

  Widget _buildFindingCard(AuditFinding finding) {
    final color = _statusColor(finding.status);
    final hasDetails = finding.details.isNotEmpty;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: color.withValues(alpha: 0.18)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 15, 16, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(_statusIcon(finding.status), color: color, size: 27),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              finding.title,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              _statusLabel(finding.status),
                              style: TextStyle(
                                color: color,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        finding.message,
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 13,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        '${finding.category}  •  ${finding.code}',
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          if (hasDetails) ...[
            Divider(height: 1, color: Colors.grey.withValues(alpha: 0.15)),
            Theme(
              data: Theme.of(
                context,
              ).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: const EdgeInsets.symmetric(horizontal: 16),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                leading: Icon(
                  Icons.manage_search_rounded,
                  color: color,
                  size: 21,
                ),
                title: Text(
                  'View Details (${finding.details.length})',
                  style: TextStyle(
                    color: color,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.045),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: finding.details
                          .map(
                            (detail) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    margin: const EdgeInsets.only(top: 6),
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      color: color,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      detail,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        height: 1.45,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      margin: const EdgeInsets.only(top: 35),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Icon(
            Icons.fact_check_outlined,
            size: 58,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 12),
          const Text(
            'No audit has been run yet',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            'Tap “Run Full Audit” to inspect your business data.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime value) {
    final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
    final minute = value.minute.toString().padLeft(2, '0');
    final second = value.second.toString().padLeft(2, '0');
    final period = value.hour >= 12 ? 'PM' : 'AM';

    return '${value.day.toString().padLeft(2, '0')}/'
        '${value.month.toString().padLeft(2, '0')}/'
        '${value.year} $hour:$minute:$second $period';
  }
}
