import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/tourist_settings_model.dart';
import '../services/tourist_settings_service.dart';
import '../utils/app_error_message.dart';
import '../widgets/app_state_widgets.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late Stream<QuerySnapshot> _notifications;
  final Set<String> _updatingReadStatus = {};

  @override
  void initState() {
    super.initState();
    _createNotificationsStream();
  }

  void _createNotificationsStream() {
    final user = FirebaseAuth.instance.currentUser;
    _notifications = user == null
        ? const Stream.empty()
        : FirebaseFirestore.instance
              .collection('notifications')
              .where('touristId', isEqualTo: user.uid)
              .snapshots();
  }

  Future<void> _retry() async {
    setState(_createNotificationsStream);
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(body: Center(child: Text('Please sign in again.')));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<TouristSettingsModel>(
        stream: TouristSettingsService.shared.changes,
        initialData: TouristSettingsService.shared.settings,
        builder: (context, settingsSnapshot) {
          final settings =
              settingsSnapshot.data ?? const TouristSettingsModel();
          return StreamBuilder<QuerySnapshot>(
            stream: _notifications,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const AppLoadingState(
                  message: 'Loading notifications...',
                );
              }

              if (snapshot.hasError) {
                return AppErrorState(
                  message: AppErrorMessage.from(
                    snapshot.error!,
                    fallback: 'Unable to load notifications. Please try again.',
                  ),
                  onRetry: _retry,
                );
              }

              final docs = (snapshot.data?.docs ?? []).where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return shouldSurfaceNotification(
                  data['type']?.toString() ?? 'general',
                  settings,
                );
              }).toList();

              if (docs.isEmpty) {
                return const AppEmptyState(
                  message: 'No Notifications\nYour safety notifications will appear here.',
                  icon: Icons.notifications_none,
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final data = docs[index].data() as Map<String, dynamic>;

                  final title = data['title']?.toString() ?? 'Notification';

                  final message = data['message']?.toString() ?? '';

                  final type = data['type']?.toString() ?? 'general';

                  final isRead = data['isRead'] == true;

                  final createdAt = data['createdAt'];
                  final timestamp = createdAt is Timestamp ? createdAt : null;

                  final dateText = timestamp != null
                      ? _formatDate(timestamp.toDate())
                      : 'Date unavailable';

                  return InkWell(
                    onTap: isRead || _updatingReadStatus.contains(docs[index].id)
                        ? null
                        : () => _markRead(docs[index].id),
                    child: Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      color: isRead ? Colors.white : const Color(0xFFE6FFFA),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              _notificationIcon(type),
                              color: Colors.teal,
                              size: 28,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    title,
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: isRead
                                          ? FontWeight.w600
                                          : FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    message,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    dateText,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (_updatingReadStatus.contains(docs[index].id))
                              const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            else if (!isRead)
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
                },
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _markRead(String notificationId) async {
    if (_updatingReadStatus.contains(notificationId)) return;
    setState(() => _updatingReadStatus.add(notificationId));
    try {
      await FirebaseFirestore.instance
          .collection('notifications')
          .doc(notificationId)
          .update({'isRead': true});
    } catch (error, stackTrace) {
      AppErrorMessage.log(
        error,
        stackTrace,
        context: 'Marking notification as read',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppErrorMessage.from(
                error,
                fallback: 'Unable to update this notification. Please try again.',
              ),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _updatingReadStatus.remove(notificationId));
    }
  }

  static String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');

    final month = date.month.toString().padLeft(2, '0');

    final year = date.year.toString();

    final hour = date.hour.toString().padLeft(2, '0');

    final minute = date.minute.toString().padLeft(2, '0');

    return '$day/$month/$year $hour:$minute';
  }

  static IconData _notificationIcon(String type) {
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
}
