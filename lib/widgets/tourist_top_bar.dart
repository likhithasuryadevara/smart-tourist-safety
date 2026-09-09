import 'package:flutter/material.dart';

class TouristTopBar extends StatelessWidget {
  final String email;
  final VoidCallback onLogout;

  const TouristTopBar({
    super.key,
    required this.email,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 75,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: const BoxDecoration(
        color: Color(0xFF111C31),
        border: Border(
          bottom: BorderSide(
            color: Color(0xFF1E2B44),
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: const Color(0xFF0F766E),
              borderRadius: BorderRadius.circular(9),
            ),
            child: const Icon(
              Icons.shield_rounded,
              color: Colors.white,
              size: 19,
            ),
          ),

          const SizedBox(width: 9),

          const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Smart Tourist Safety',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Tourist Safety Dashboard',
                style: TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 10,
                ),
              ),
            ],
          ),

          const Spacer(),

          if (MediaQuery.of(context).size.width > 600)
            Text(
              email,
              style: const TextStyle(
                color: Color(0xFFCBD5E1),
                fontSize: 11,
              ),
            ),

          const SizedBox(width: 12),
          IconButton(
            tooltip: 'Logout',
            onPressed: onLogout,
            icon: const Icon(
              Icons.logout_rounded,
              color: Color(0xFFCBD5E1),
              size: 20,
            ),
          ),
        ],
      ),
    );
  }
}