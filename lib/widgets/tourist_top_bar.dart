import 'package:flutter/material.dart';

class TouristTopBar extends StatelessWidget {
  final String name;
  final String email;
  final VoidCallback onLogout;
  final VoidCallback onProfile;
  const TouristTopBar({
    super.key,
    required this.name,
    required this.email,
    required this.onLogout,
    required this.onProfile,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final isMobile = width < 760;
        final isCompact = width < 360;
        return Container(
          constraints: const BoxConstraints(minHeight: 68),
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 16 : 28,
            vertical: 8,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(
              bottom: BorderSide(color: Color(0xFFE7ECEF), width: 1),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFE6F4F1),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.shield_rounded,
                  color: Color(0xFF0F766E),
                  size: 22,
                ),
              ),

              SizedBox(width: isCompact ? 9 : 12),

              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isCompact ? 'Tourist Safety' : 'Smart Tourist Safety',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF172B35),
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                    ),
                    if (!isCompact)
                      const Padding(
                        padding: EdgeInsets.only(top: 2),
                        child: Text(
                          'Tourist Dashboard',
                          style: TextStyle(
                            color: Color(0xFF73818A),
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              if (isMobile) ...[
                const SizedBox(width: 8),
                Tooltip(
                  message: 'Profile',
                  child: IconButton(
                    onPressed: onProfile,
                    visualDensity: VisualDensity.compact,
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFFF1F7F6),
                      foregroundColor: const Color(0xFF0F766E),
                      minimumSize: const Size(42, 42),
                    ),
                    icon: const Icon(Icons.person_outline_rounded, size: 21),
                  ),
                ),
              ] else ...[
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: onProfile,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          const CircleAvatar(
                            radius: 17,
                            backgroundColor: Color(0xFFE6F4F1),
                            child: Icon(
                              Icons.person_outline_rounded,
                              size: 19,
                              color: Color(0xFF0F766E),
                            ),
                          ),
                          const SizedBox(width: 9),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 180),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Color(0xFF263943),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  email,
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
                        ],
                      ),
                    ),
                  ),
                ),
              ],

              const SizedBox(width: 6),
              Tooltip(
                message: 'Log out',
                child: IconButton(
                  onPressed: onLogout,
                  visualDensity: VisualDensity.compact,
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFFFFF3F1),
                    foregroundColor: const Color(0xFFB5473C),
                    minimumSize: const Size(42, 42),
                  ),
                  icon: const Icon(Icons.logout_rounded, size: 19),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
