import 'package:flutter/material.dart';

class QuickActions extends StatelessWidget {
  final bool desktop;
  final Function(String) onAction;

  const QuickActions({
    super.key,
    required this.desktop,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final actions = [
      _ActionData(
        title: 'SOS Emergency',
        subtitle: 'Send emergency alert',
        icon: Icons.sos_rounded,
        color: const Color(0xFFE11D48),
      ),
      _ActionData(
        title: 'Safe Zone',
        subtitle: 'Check your safety area',
        icon: Icons.shield_rounded,
        color: const Color(0xFF14B8A6),
      ),
      _ActionData(
        title: 'Police',
        subtitle: 'Find nearby police',
        icon: Icons.local_police_rounded,
        color: const Color(0xFF2563EB),
      ),
      _ActionData(
        title: 'Hospital',
        subtitle: 'Find nearby hospital',
        icon: Icons.local_hospital_rounded,
        color: const Color(0xFFEF4444),
      ),
    ];

    if (desktop) {
      return Row(
        children: [
          for (int i = 0; i < actions.length; i++) ...[
            Expanded(
              child: _ActionCard(
                data: actions[i],
                onTap: () => onAction(actions[i].title),
              ),
            ),
            if (i != actions.length - 1)
              const SizedBox(width: 14),
          ],
        ],
      );
    }

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _ActionCard(
                data: actions[0],
                onTap: () => onAction(actions[0].title),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ActionCard(
                data: actions[1],
                onTap: () => onAction(actions[1].title),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _ActionCard(
                data: actions[2],
                onTap: () => onAction(actions[2].title),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ActionCard(
                data: actions[3],
                onTap: () => onAction(actions[3].title),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ActionCard extends StatelessWidget {
  final _ActionData data;
  final VoidCallback onTap;

  const _ActionCard({
    required this.data,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF111C31),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: const Color(0xFF263752),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              data.icon,
              color: data.color,
              size: 26,
            ),
            const SizedBox(height: 12),
            Text(
              data.title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              data.subtitle,
              style: const TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 9,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionData {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;

  _ActionData({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
  });
}