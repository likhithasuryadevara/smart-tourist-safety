import 'package:flutter/material.dart';

class EmergencyPanel extends StatelessWidget {
  final Function(String) onAction;
  final bool voiceListening;
  final String voiceStatus;

  const EmergencyPanel({
    super.key,
    required this.onAction,
    required this.voiceListening,
    required this.voiceStatus,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE4EBEA)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x080F766E),
            blurRadius: 12,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.emergency_rounded, color: Color(0xFFB5473C), size: 22),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Emergency Assistance',
                  style: TextStyle(
                    color: Color(0xFF172B35),
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          const Text(
            'Get immediate help during an emergency.',
            style: TextStyle(color: Color(0xFF73818A), fontSize: 12),
          ),

          const SizedBox(height: 16),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF6F9F8),
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: const Color(0xFFEBF0EF)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  voiceListening ? Icons.mic : Icons.mic_off,
                  color: voiceListening
                      ? const Color(0xFF16805D)
                      : const Color(0xFF7A8A90),
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    voiceStatus,
                    style: const TextStyle(
                      color: Color(0xFF52636B),
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          _EmergencyButton(
            icon: Icons.sos_rounded,
            title: 'SEND SOS',
            color: const Color(0xFFE11D48),
            onTap: () => onAction('SOS Emergency'),
            primary: true,
          ),

          const SizedBox(height: 10),

          _EmergencyButton(
            icon: Icons.local_police_rounded,
            title: 'CALL POLICE',
            color: const Color(0xFF39718C),
            onTap: () => onAction('Police'),
          ),

          const SizedBox(height: 10),

          _EmergencyButton(
            icon: Icons.local_hospital_rounded,
            title: 'FIND HOSPITAL',
            color: const Color(0xFFB5473C),
            onTap: () => onAction('Hospital'),
          ),

          const SizedBox(height: 16),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF6F9F8),
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  color: Color(0xFF0F766E),
                  size: 18,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Your live location can help emergency services locate you.',
                    style: TextStyle(color: Color(0xFF697980), fontSize: 11),
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
  final bool primary;

  const _EmergencyButton({
    required this.icon,
    required this.title,
    required this.color,
    required this.onTap,
    this.primary = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Ink(
        decoration: BoxDecoration(
          color: primary ? color : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: primary ? color : const Color(0xFFE4EBEA)),
          boxShadow: primary
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.16),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 50),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 13),
            child: Row(
              children: [
                Icon(icon, color: primary ? Colors.white : color, size: 21),
                const SizedBox(width: 11),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: primary ? Colors.white : const Color(0xFF263943),
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right_rounded,
                  color: primary
                      ? Colors.white.withValues(alpha: 0.9)
                      : const Color(0xFF8A989D),
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
