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

    final width = MediaQuery.of(context).size.width;
    final columns = desktop
        ? 3
        : width >= 520
        ? 3
        : 2;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: actions.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        mainAxisExtent: 126,
      ),
      itemBuilder: (context, index) => _ActionCard(
        data: actions[index],
        onTap: () => onAction(actions[index].title),
      ),
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
      borderRadius: BorderRadius.circular(14),
      child: Ink(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE4EBEA)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x080F766E),
              blurRadius: 10,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: data.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(data.icon, color: data.color, size: 21),
              ),
              const Spacer(),
              Text(
                data.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF263943),
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                data.subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF73818A),
                  fontSize: 11,
                ),
              ),
            ],
          ),
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