import 'package:flutter/material.dart';

class EmergencyPanel extends StatelessWidget {
  final Function(String) onAction;

  const EmergencyPanel({
    super.key,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
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
          const Row(
            children: [
              Icon(
                Icons.emergency_rounded,
                color: Color(0xFFE11D48),
                size: 22,
              ),
              SizedBox(width: 8),
              Text(
                'Emergency Assistance',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          const Text(
            'Get immediate help during an emergency.',
            style: TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 10,
            ),
          ),

          const SizedBox(height: 16),

          _EmergencyButton(
            icon: Icons.sos_rounded,
            title: 'SEND SOS',
            color: const Color(0xFFE11D48),
            onTap: () => onAction('SOS Emergency'),
          ),

          const SizedBox(height: 10),

          _EmergencyButton(
            icon: Icons.local_police_rounded,
            title: 'CALL POLICE',
            color: const Color(0xFF2563EB),
            onTap: () => onAction('Police'),
          ),

          const SizedBox(height: 10),

          _EmergencyButton(
            icon: Icons.local_hospital_rounded,
            title: 'FIND HOSPITAL',
            color: const Color(0xFFEF4444),
            onTap: () => onAction('Hospital'),
          ),

          const SizedBox(height: 16),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF17233A),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  color: Color(0xFF14B8A6),
                  size: 18,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Your live location can help emergency services locate you.',
                    style: TextStyle(
                      color: Color(0xFFCBD5E1),
                      fontSize: 9,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmergencyButton extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  final VoidCallback onTap;

  const _EmergencyButton({
    required this.icon,
    required this.title,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFF17233A),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: color.withOpacity(0.5),
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: color,
              size: 20,
            ),
            const SizedBox(width: 10),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
            const Spacer(),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              color: Color(0xFF94A3B8),
              size: 13,
            ),
          ],
        ),
      ),
    );
  }
}