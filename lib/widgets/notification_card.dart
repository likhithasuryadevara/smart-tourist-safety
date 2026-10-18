import 'package:flutter/material.dart';

import '../models/notification_item.dart';

/// A single Tourist notification, including the unread indicator.
///
/// The teal dot is only shown while the notification is unread. Tapping an
/// unread notification reports it through [onOpen]; read notifications are not
/// tappable, matching the previous behaviour of the Notifications screen.
class NotificationCard extends StatelessWidget {
  const NotificationCard({
    super.key,
    required this.notification,
    required this.onOpen,
  });

  final NotificationItem notification;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final isRead = notification.isRead;

    return InkWell(
      onTap: isRead ? null : onOpen,
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        color: isRead ? Colors.white : const Color(0xFFE6FFFA),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                notificationIcon(notification.type),
                color: Colors.teal,
                size: 28,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notification.title,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: isRead ? FontWeight.w600 : FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      notification.message,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      notification.dateText,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              if (!isRead)
                Container(
                  width: 9,
                  height: 9,
                  decoration: const BoxDecoration(
                    color: Colors.teal,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

IconData notificationIcon(String type) {
  switch (type.toLowerCase()) {
    case 'safe_zone':
      return Icons.shield_outlined;

    case 'danger_zone':
      return Icons.warning_amber_rounded;

    case 'zone_exit':
      return Icons.location_off_outlined;

    case 'sos':
      return Icons.sos;

    case 'sos_acknowledged':
      return Icons.check_circle_outline;

    case 'sos_resolved':
      return Icons.verified_outlined;

    case 'admin':
      return Icons.admin_panel_settings_outlined;

    default:
      return Icons.notifications_outlined;
  }
}
