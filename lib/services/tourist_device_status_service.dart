import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/tourist_device_status_model.dart';

class TouristDeviceStatusService {
  TouristDeviceStatusService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  Stream<TouristDeviceStatusModel> watchCurrentTouristDeviceStatus() {
    final user = _auth.currentUser;
    if (user == null) {
      return Stream<TouristDeviceStatusModel>.value(
        const TouristDeviceStatusModel(),
      );
    }

    return _firestore
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .map(
          (snapshot) => TouristDeviceStatusModel.fromUserData(
            snapshot.data(),
          ),
        );
  }
}
