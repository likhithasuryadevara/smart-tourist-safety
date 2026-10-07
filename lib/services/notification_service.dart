import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/tourist_settings_model.dart';
import 'tourist_settings_service.dart';

class NotificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final FirebaseAuth _auth = FirebaseAuth.instance;

  Stream<QuerySnapshot<Map<String, dynamic>>> getNotifications() {
    final user = _auth.currentUser;

    if (user == null) {
      return const Stream.empty();
    }

    return _firestore
        .collection('notifications')
        .where('touristId', isEqualTo: user.uid)
        .snapshots();
  }

  Future<void> markAsRead(String notificationId) async {
    await _firestore.collection('notifications').doc(notificationId).update({
      'isRead': true,
    });
  }

  Future<void> createSosConfirmationNotification({
    required String sosId,
    required String touristId,
  }) async {
    await _createSosConfirmationNotificationOnce(
      sosId: sosId,
      touristId: touristId,
    );
  }

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>
  listenForSosStatusChanges(String touristId) {
    final previousStatuses = <String, String>{};

    return _firestore
        .collection('sos')
        .where('touristId', isEqualTo: touristId)
        .snapshots()
        .listen(
          (snapshot) {
            for (final change in snapshot.docChanges) {
              final sos = change.doc.data();
              if (sos == null || sos['touristId'] != touristId) continue;

              final status = sos['status']?.toString() ?? '';
              final previousStatus = previousStatuses[change.doc.id];
              previousStatuses[change.doc.id] = status;

              if (change.type == DocumentChangeType.added ||
                  previousStatus == null) {
                continue;
              }

              if (previousStatus == 'active' && status == 'acknowledged') {
                unawaited(
                  _createSosNotificationOnce(
                    sosId: change.doc.id,
                    touristId: touristId,
                    type: 'sos_acknowledged',
                    title: 'SOS Acknowledged',
                    message: 'Your SOS has been acknowledged. Help is being coordinated.',
                  ),
                );
              } else if (status == 'resolved' &&
                  (previousStatus == 'acknowledged' ||
                      previousStatus == 'active')) {
                unawaited(
                  _createSosNotificationOnce(
                    sosId: change.doc.id,
                    touristId: touristId,
                    type: 'sos_resolved',
                    title: 'SOS Resolved',
                    message: 'Your SOS incident has been resolved.',
                  ),
                );
              }
            }
          },
          onError: (Object error, StackTrace stackTrace) {
            debugPrint('SOS status listener failed: $error');
            debugPrint('SOS status listener stack trace: $stackTrace');
          },
        );
  }

  Future<void> _createSosConfirmationNotificationOnce({
    required String sosId,
    required String touristId,
  }) async {
    final notificationRef = _firestore
        .collection('notifications')
        .doc('sos_${sosId}_sos');
    final user = _auth.currentUser;

    debugPrint(
      'SOS notification details: '
      'documentId=${notificationRef.id}, touristId=$touristId, type=sos.',
    );

    try {
      if (!await TouristSettingsService.shared.isNotificationEnabled(
        TouristNotificationCategory.sos,
      )) {
        return;
      }
      if (user == null || user.uid != touristId) {
        throw StateError('Authenticated user does not match the SOS tourist.');
      }

      final idToken = await user.getIdToken();
      if (idToken == null) {
        throw StateError('Unable to obtain Firebase Auth ID token.');
      }

      final projectId = _firestore.app.options.projectId;
      final uri = Uri.https(
        'firestore.googleapis.com',
        '/v1/projects/$projectId/databases/(default)/documents:commit',
      );
      final documentName =
          'projects/$projectId/databases/(default)/documents/'
          'notifications/${notificationRef.id}';

      debugPrint(
        'Creating SOS confirmation notification: '
        'documentId=${notificationRef.id}, touristId=$touristId, type=sos.',
      );
      final response = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'writes': [
            {
              'update': {
                'name': documentName,
                'fields': {
                  'touristId': {'stringValue': touristId},
                  'type': {'stringValue': 'sos'},
                  'title': {'stringValue': 'SOS Confirmation'},
                  'message': {
                    'stringValue':
                        'Your SOS has been sent successfully. '
                        'Emergency assistance has been notified.',
                  },
                  'isRead': {'booleanValue': false},
                },
              },
              'updateTransforms': [
                {'fieldPath': 'createdAt', 'setToServerValue': 'REQUEST_TIME'},
              ],
              'currentDocument': {'exists': false},
            },
          ],
        }),
      );

      if (response.statusCode == 409) {
        debugPrint(
          'Expected duplicate SOS confirmation; document already exists: '
          '${notificationRef.id}.',
        );
        return;
      }

      if (response.statusCode != 200) {
        throw http.ClientException(
          'Firestore create failed (${response.statusCode}): '
          '${response.body}',
          uri,
        );
      }

      debugPrint(
        'SOS notification created successfully: '
        'documentId=${notificationRef.id}, type=sos.',
      );
    } catch (error, stackTrace) {
      debugPrint(
        'Failed to create SOS confirmation notification '
        '(documentId=${notificationRef.id}, touristId=$touristId): $error',
      );
      debugPrint('SOS confirmation write stack trace: $stackTrace');
    }
  }

  Future<void> _createSosNotificationOnce({
    required String sosId,
    required String touristId,
    required String type,
    required String title,
    required String message,
  }) async {
    final notificationRef = _firestore
        .collection('notifications')
        .doc('sos_${sosId}_$type');

    debugPrint(
      'SOS notification details: '
      'documentId=${notificationRef.id}, touristId=$touristId, type=$type.',
    );

    try {
      if (!await TouristSettingsService.shared.isNotificationEnabled(
        TouristNotificationCategory.sos,
      )) {
        return;
      }
      final user = _auth.currentUser;
      if (user == null || user.uid != touristId) {
        throw StateError('Authenticated user does not match the SOS tourist.');
      }

      final idToken = await user.getIdToken();
      if (idToken == null) {
        throw StateError('Unable to obtain Firebase Auth ID token.');
      }

      final projectId = _firestore.app.options.projectId;
      final uri = Uri.https(
        'firestore.googleapis.com',
        '/v1/projects/$projectId/databases/(default)/documents:commit',
      );
      final documentName =
          'projects/$projectId/databases/(default)/documents/'
          'notifications/${notificationRef.id}';

      debugPrint(
        'Creating SOS notification: documentId=${notificationRef.id}, '
        'touristId=$touristId, type=$type.',
      );
      final response = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'writes': [
            {
              'update': {
                'name': documentName,
                'fields': {
                  'touristId': {'stringValue': touristId},
                  'type': {'stringValue': type},
                  'title': {'stringValue': title},
                  'message': {'stringValue': message},
                  'isRead': {'booleanValue': false},
                },
              },
              'updateTransforms': [
                {'fieldPath': 'createdAt', 'setToServerValue': 'REQUEST_TIME'},
              ],
              'currentDocument': {'exists': false},
            },
          ],
        }),
      );

      if (_isAlreadyExistsResponse(response)) {
        debugPrint(
          'Expected duplicate SOS notification; document already exists: '
          'documentId=${notificationRef.id}, type=$type.',
        );
        return;
      }

      if (response.statusCode != 200) {
        throw http.ClientException(
          'Firestore create failed (${response.statusCode}): '
          '${response.body}',
          uri,
        );
      }

      debugPrint(
        'SOS notification created successfully: '
        'documentId=${notificationRef.id}, type=$type.',
      );
    } catch (error, stackTrace) {
      debugPrint(
        'Failed to create $type notification for SOS $sosId '
        '(documentId=${notificationRef.id}, touristId=$touristId): $error',
      );
      debugPrint('SOS notification write stack trace: $stackTrace');
    }
  }

  bool _isAlreadyExistsResponse(http.Response response) {
    if (response.statusCode == 409) return true;

    try {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final error = body['error'] as Map<String, dynamic>?;
      final status = error?['status']?.toString();
      final message = error?['message']?.toString().toLowerCase() ?? '';

      return status == 'ALREADY_EXISTS' || message.contains('already exists');
    } on FormatException {
      return false;
    } on TypeError {
      return false;
    }
  }
}
