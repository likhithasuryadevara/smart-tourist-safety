import 'package:flutter/material.dart';

class DangerBanner extends StatelessWidget {
  final VoidCallback onTap;

  const DangerBanner({
    super.key,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF7F5),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFF3D6D1)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFFCE8E5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.warning_amber_rounded,
                color: Color(0xFFB5473C),
                size: 23,
              ),
            ),

            const SizedBox(width: 12),

            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Safety Alert',
                    style: TextStyle(
                      color: Color(0xFF8F352D),
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'Stay aware of your surroundings and remain within designated safe zones.',
                    style: TextStyle(
                      color: Color(0xFF765E5A),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8),

            const Icon(
              Icons.arrow_forward_ios_rounded,
              color: Color(0xFFB5473C),
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}