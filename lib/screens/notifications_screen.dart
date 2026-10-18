import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:rxdart/rxdart.dart';

import '../models/notification_item.dart';
import '../models/tourist_settings_model.dart';
import '../services/notification_read_state_service.dart';
import '../services/tourist_settings_service.dart';
import '../utils/app_error_message.dart';
import '../widgets/app_state_widgets.dart';
import '../widgets/notification_card.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final NotificationReadStateService _readState =
      NotificationReadStateService.shared;

  late Stream<List<NotificationItem>> _notifications;

  @override
  void initState() {
    super.initState();
    _createNotificationsStream();
  }

  bool _isRead(NotificationItem notification) => _readState.isRead(
    notification.id,
    persistedIsRead: notification.isRead,
  );

  void _createNotificationsStream() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _notifications = Stream.value(const []);
      return;
    }

    final sosStream = FirebaseFirestore.instance
        .collection('sos_alerts')
        .where('userId', isEqualTo: user.uid)
        .snapshots();

    final geoFenceStream = FirebaseFirestore.instance
        .collection('geo_fence_alerts')
        .where('userId', isEqualTo: user.uid)
        .snapshots();

    _notifications = Rx.combineLatest2(sosStream, geoFenceStream, (
      QuerySnapshot<Map<String, dynamic>> sosSnapshot,
      QuerySnapshot<Map<String, dynamic>> geoFenceSnapshot,
    ) {
      final notifications = <NotificationItem>[];

      for (final doc in sosSnapshot.docs) {
        final data = doc.data();
        final status = data['status']?.toString().toLowerCase() ?? '';
        final timestamp = data['timestamp'] ?? data['createdAt'];

        if (status == 'active') {
          notifications.add(
            NotificationItem(
              id: 'sos:${doc.id}',
              type: 'sos',
              title: 'SOS Confirmation',
              message: 'Your SOS request has been created.',
              createdAt: timestamp is Timestamp ? timestamp : null,
              isRead: false,
            ),
          );
        } else if (status == 'acknowledged') {
          notifications.add(
            NotificationItem(
              id: 'sos_ack:${doc.id}',
              type: 'sos_acknowledged',
              title: 'SOS Acknowledged',
              message:
                  'Your SOS has been acknowledged. Help is being coordinated.',
              createdAt: timestamp is Timestamp ? timestamp : null,
              isRead: false,
            ),
          );
        } else if (status == 'resolved') {
          notifications.add(
            NotificationItem(
              id: 'sos_resolved:${doc.id}',
              type: 'sos_resolved',
              title: 'SOS Resolved',
              message: 'Your SOS incident has been resolved.',
              createdAt: timestamp is Timestamp ? timestamp : null,
              isRead: false,
            ),
          );
        }
      }

      for (final doc in geoFenceSnapshot.docs) {
        final data = doc.data();
        final eventType = data['eventType']?.toString() ?? '';
        final zoneType = data['zoneType']?.toString() ?? '';
        final zoneName = data['safeZoneName']?.toString() ?? 'Unknown zone';
        final timestamp = data['timestamp'];
        final status = data['status']?.toString() ?? 'Unread';

        String type;
        String title;
        String message;

        if (eventType == 'ENTER') {
          if (zoneType == 'Safe') {
            type = 'safe_zone';
            title = 'Safe Zone Entered';
            message = 'You have entered $zoneName.';
          } else if (zoneType == 'Danger') {
            type = 'danger_zone';
            title = 'Danger Zone Alert';
            message = 'You have entered $zoneName. Please exercise caution.';
          } else {
            type = 'safe_zone';
            title = 'Zone Entered';
            message = 'You have entered $zoneName.';
          }
        } else if (eventType == 'EXIT') {
          if (zoneType == 'Safe') {
            type = 'zone_exit';
            title = 'Safe Zone Exited';
            message = 'You have left $zoneName.';
          } else if (zoneType == 'Danger') {
            type = 'danger_zone';
            title = 'Danger Zone Exited';
            message = 'You have left $zoneName.';
          } else {
            type = 'zone_exit';
            title = 'Zone Exited';
            message = 'You have left $zoneName.';
          }
        } else {
          continue;
        }

        notifications.add(
          NotificationItem(
            id: 'geo:${doc.id}',
            type: type,
            title: title,
            message: message,
            createdAt: timestamp is Timestamp ? timestamp : null,
            isRead: status == 'Read',
          ),
        );
      }

      notifications.sort((a, b) {
        final aTime = a.createdAt;
        final bTime = b.createdAt;
        if (aTime == null) return bTime == null ? 0 : 1;
        if (bTime == null) return -1;
        return bTime.compareTo(aTime);
      });

      return notifications;
    });
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
          return StreamBuilder<List<NotificationItem>>(
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

              final notifications = (snapshot.data ?? []).where((n) {
                return shouldSurfaceNotification(n.type, settings);
              }).toList();

              if (notifications.isEmpty) {
                return const AppEmptyState(
                  message: 'No Notifications\nYour safety notifications will appear here.',
                  icon: Icons.notifications_none,
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: notifications.length,
                itemBuilder: (context, index) {
                  final n = notifications[index];

                  return NotificationCard(
                    notification: n.withReadState(isRead: _isRead(n)),
                    onOpen: () => _markRead(n),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _markRead(NotificationItem n) async {
    // Hide the unread indicator as soon as the notification is opened.
    _readState.markRead(n.id);
    if (!mounted) return;
    setState(() {});

    // `geo_fence_alerts` is the only existing collection with a read state, so
    // only those notifications are persisted. `sos_alerts` documents have no
    // read field in the existing schema, so their read state stays in the
    // current session instead of inventing a new field.
    if (!n.id.startsWith('geo:')) return;

    final docId = n.id.substring(4);
    try {
      await FirebaseFirestore.instance
          .collection('geo_fence_alerts')
          .doc(docId)
          .update({'status': 'Read'});
    } catch (error, stackTrace) {
      // Keep the visible state consistent with the persisted state.
      _readState.revertRead(n.id);
      AppErrorMessage.log(
        error,
        stackTrace,
        context: 'Marking geofence alert as read',
      );
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppErrorMessage.from(
                error,
                fallback:
                    'Unable to update this notification. Please try again.',
              ),
            ),
          ),
        );
      }
    }
  }
}
