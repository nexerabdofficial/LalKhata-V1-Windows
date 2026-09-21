import 'package:flutter/material.dart';

import 'account_money_flow_screen.dart';

class MoneyFlowHubScreen extends StatelessWidget {
  const MoneyFlowHubScreen({super.key});

  void _open(BuildContext context, {required bool received}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AccountMoneyFlowScreen(received: received),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff5f7fb),
      appBar: AppBar(title: const Text('Money Flow')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                Expanded(
                  child: _MoneyFlowOption(
                    title: 'Money Received',
                    subtitle: 'View all incoming money',
                    icon: Icons.south_west_rounded,
                    color: const Color(0xff16a34a),
                    onTap: () => _open(context, received: true),
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: _MoneyFlowOption(
                    title: 'Money Given',
                    subtitle: 'View all outgoing money',
                    icon: Icons.north_east_rounded,
                    color: const Color(0xffdc2626),
                    onTap: () => _open(context, received: false),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MoneyFlowOption extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _MoneyFlowOption({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          height: 180,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: color.withOpacity(.10)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(.05),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: color.withOpacity(.10),
                  borderRadius: BorderRadius.circular(17),
                ),
                child: Icon(icon, color: color, size: 29),
              ),
              const SizedBox(height: 15),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
