import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class NotificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>
  listenForSosStatusChanges(String touristId) {
    final previousStatuses = <String, String>{};

    return _firestore
        .collection('sos_alerts')
        .where('userId', isEqualTo: touristId)
        .snapshots()
        .listen(
          (snapshot) {
            for (final change in snapshot.docChanges) {
              final sos = change.doc.data();
              if (sos == null || sos['userId'] != touristId) continue;
              final status = sos['status']?.toString().toLowerCase() ?? '';
              final previousStatus = previousStatuses[change.doc.id];
              previousStatuses[change.doc.id] = status;

              if (change.type == DocumentChangeType.added ||
                  previousStatus == null) {
                continue;
              }

              if (previousStatus == 'active' && status == 'acknowledged') {
                debugPrint('SOS acknowledged: ${change.doc.id}');
              } else if (status == 'resolved' &&
                  (previousStatus == 'acknowledged' ||
                      previousStatus == 'active')) {
                debugPrint('SOS resolved: ${change.doc.id}');
              }
            }
          },
          onError: (Object error, StackTrace stackTrace) {
            debugPrint('SOS status listener failed: $error');
            debugPrint('SOS status listener stack trace: $stackTrace');
          },
        );
  }
}
