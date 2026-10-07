import 'package:flutter/material.dart';

class WelcomeCard extends StatelessWidget {
  final String name;

  const WelcomeCard({
    super.key,
    required this.name,
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
            color: Color(0x0A172B35),
            blurRadius: 12,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: const Color(0xFFE6F4F1),
            child: const Icon(
              Icons.person_outline_rounded,
              color: Color(0xFF0F766E),
              size: 27,
            ),
          ),

          const SizedBox(width: 13),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Welcome back',
                  style: TextStyle(
                    color: Color(0xFF172B35),
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),

                const SizedBox(height: 5),

                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF52636B),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),

                const SizedBox(height: 10),

                const Text(
                  'Your safety status and live location are being monitored.',
                  style: TextStyle(
                    color: Color(0xFF73818A),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          const Tooltip(
            message: 'Safety monitoring enabled',
            child: Icon(
              Icons.verified_user_rounded,
              color: Color(0xFF16805D),
              size: 26,
            ),
          ),
        ],
      ),
    );
  }
}