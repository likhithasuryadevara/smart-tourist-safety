import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../utils/app_error_message.dart';
import '../utils/geographic_validation.dart' as geo;

class SafeZone {
  final String? id;
  final String? name;
  final String? description;
  final String? type;
  final String? status;
  final double latitude;
  final double longitude;
  final double radius;

  SafeZone({
    this.id,
    this.name,
    this.description,
    this.type,
    this.status,
    required this.latitude,
    required this.longitude,
    required this.radius,
  });

  factory SafeZone.fromData(Map<String, dynamic> data, {String? id}) {
    return SafeZone(
      id: id,
      name: _optionalString(data['name']),
      description: _optionalString(data['description']),
      type: _optionalString(data['type']),
      status: _optionalString(data['status']),
      latitude: _requiredNumber(data['latitude'], 'latitude', -90, 90),
      longitude: _requiredNumber(data['longitude'], 'longitude', -180, 180),
      radius: _requiredRadius(data['radius']),
    );
  }
}

class DangerZone {
  final String id;
  final String? name;
  final String? description;
  final String? dangerLevel;
  final String? warningMessage;
  final String? status;
  final double latitude;
  final double longitude;
  final double radius;

  DangerZone({
    required this.id,
    this.name,
    this.description,
    this.dangerLevel,
    this.warningMessage,
    this.status,
    required this.latitude,
    required this.longitude,
    required this.radius,
  });

  factory DangerZone.fromData(String id, Map<String, dynamic> data) {
    return DangerZone(
      id: id,
      name: _optionalString(data['name']),
      description: _optionalString(data['description']),
      dangerLevel: _optionalString(data['dangerLevel']),
      warningMessage: _optionalString(data['warningMessage']),
      status: _optionalString(data['status']),
      latitude: _requiredNumber(data['latitude'], 'latitude', -90, 90),
      longitude: _requiredNumber(data['longitude'], 'longitude', -180, 180),
      radius: _requiredRadius(data['radius']),
    );
  }
}

double _requiredNumber(
  Object? value,
  String field,
  double minimum,
  double maximum,
) {
  final parsed = geo.finiteNumber(value);
  if (parsed == null || parsed < minimum || parsed > maximum) {
    throw FormatException(
      'Zone field "$field" must be a finite number from $minimum to $maximum.',
    );
  }
  return parsed;
}

double _requiredRadius(Object? value) {
  final parsed = geo.finiteNumber(value);
  if (parsed == null || !geo.isValidRadius(parsed)) {
    throw const FormatException(
      'Zone field "radius" must be a finite, non-negative number.',
    );
  }
  return parsed;
}

String? _optionalString(Object? value) {
  if (value is! String) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

class SafeZoneService {
  final FirebaseFirestore? _customFirestore;
  final FirebaseAuth? _customAuth;

  SafeZoneService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _customFirestore = firestore,
      _customAuth = auth;

  FirebaseFirestore get _firestore =>
      _customFirestore ?? FirebaseFirestore.instance;

  FirebaseAuth? get _auth {
    if (_customAuth != null) return _customAuth;
    try {
      return FirebaseAuth.instance;
    } catch (_) {
      return null;
    }
  }

  static List<SafeZone> parseSafeZoneList(
    Iterable<MapEntry<String, Map<String, dynamic>>> documents,
  ) {
    final invalidDocuments = <String>[];
    final validZones = <SafeZone>[];
    for (final entry in documents) {
      try {
        validZones.add(SafeZone.fromData(entry.value, id: entry.key));
      } on FormatException catch (error) {
        invalidDocuments.add(entry.key);
        debugPrint('Ignoring malformed enabled safe zone ${entry.key}: $error');
      }
    }
    if (documents.isNotEmpty && validZones.isEmpty) {
      throw FormatException(
        'No valid enabled safe-zone documents were found. '
        'Malformed document IDs: ${invalidDocuments.join(', ')}',
      );
    }
    return validZones;
  }

  static List<DangerZone> parseDangerZoneList(
    Iterable<MapEntry<String, Map<String, dynamic>>> documents,
  ) {
    final invalidDocuments = <String>[];
    final validZones = <DangerZone>[];
    for (final entry in documents) {
      try {
        validZones.add(DangerZone.fromData(entry.key, entry.value));
      } on FormatException catch (error) {
        invalidDocuments.add(entry.key);
        debugPrint(
          'Ignoring malformed enabled danger zone ${entry.key}: $error',
        );
      }
    }
    if (documents.isNotEmpty && validZones.isEmpty) {
      throw FormatException(
        'No valid enabled danger-zone documents were found. '
        'Malformed document IDs: ${invalidDocuments.join(', ')}',
      );
    }
    return validZones;
  }

  Future<List<SafeZone>> getActiveSafeZones() async {
    try {
      final snapshot = await _firestore
          .collection('safe_zones')
          .where('status', isEqualTo: 'enabled')
          .get();

      if (snapshot.docs.isEmpty) {
        return const [];
      }

      return parseSafeZoneList(
        snapshot.docs.map((doc) => MapEntry(doc.id, doc.data())),
      );
    } catch (e, stackTrace) {
      AppErrorMessage.log(e, stackTrace, context: 'Loading active safe zones');
      rethrow;
    }
  }

  Future<SafeZone?> getActiveSafeZone() async {
    try {
      final validZones = await getActiveSafeZones();
      if (validZones.isEmpty) return null;
      if (validZones.length == 1) return validZones.single;
      throw FormatException(
        'Expected at most one enabled safe zone, found ${validZones.length}. '
        'Use getActiveSafeZones() to support multiple safe zones.',
      );
    } catch (e, stackTrace) {
      AppErrorMessage.log(e, stackTrace, context: 'Loading active safe zone');
      rethrow;
    }
  }

  Future<List<DangerZone>> getActiveDangerZones() async {
    try {
      final snapshot = await _firestore
          .collection('danger_zones')
          .where('status', isEqualTo: 'enabled')
          .get();

      if (snapshot.docs.isEmpty) {
        return const [];
      }

      return parseDangerZoneList(
        snapshot.docs.map((doc) => MapEntry(doc.id, doc.data())),
      );
    } catch (e, stackTrace) {
      AppErrorMessage.log(
        e,
        stackTrace,
        context: 'Loading active danger zones',
      );
      rethrow;
    }
  }

  bool isInsideDangerZone({
    required double touristLatitude,
    required double touristLongitude,
    required DangerZone dangerZone,
  }) {
    _validateInputs(
      touristLatitude,
      touristLongitude,
      dangerZone.latitude,
      dangerZone.longitude,
      dangerZone.radius,
    );
    final distance = Geolocator.distanceBetween(
      touristLatitude,
      touristLongitude,
      dangerZone.latitude,
      dangerZone.longitude,
    );

    return distance <= dangerZone.radius;
  }

  double calculateDistance({
    required double touristLatitude,
    required double touristLongitude,
    required SafeZone safeZone,
  }) {
    _validateInputs(
      touristLatitude,
      touristLongitude,
      safeZone.latitude,
      safeZone.longitude,
      safeZone.radius,
    );
    return Geolocator.distanceBetween(
      touristLatitude,
      touristLongitude,
      safeZone.latitude,
      safeZone.longitude,
    );
  }

  bool isInsideSafeZone({
    required double touristLatitude,
    required double touristLongitude,
    required SafeZone safeZone,
  }) {
    final distance = calculateDistance(
      touristLatitude: touristLatitude,
      touristLongitude: touristLongitude,
      safeZone: safeZone,
    );

    return distance <= safeZone.radius;
  }

  static bool isValidCoordinate(double latitude, double longitude) =>
      geo.isValidCoordinate(latitude, longitude);

  static bool isValidRadius(double radius) => geo.isValidRadius(radius);

  static void _validateInputs(
    double latitude,
    double longitude,
    double zoneLatitude,
    double zoneLongitude,
    double radius,
  ) {
    if (!isValidCoordinate(latitude, longitude) ||
        !isValidCoordinate(zoneLatitude, zoneLongitude) ||
        !isValidRadius(radius)) {
      throw ArgumentError(
        'Coordinates must be finite and within geographic bounds, '
        'and radius must be finite and non-negative.',
      );
    }
  }

  static Map<String, dynamic> buildGeoFenceAlertPayload({
    required String userId,
    required String userName,
    required String userEmail,
    required String safeZoneId,
    required String safeZoneName,
    required String eventType, // 'ENTER' or 'EXIT'
    required double latitude,
    required double longitude,
    required Object timestamp,
    String status = 'Unread',
    String? zoneType, // 'Safe' or 'Danger'
  }) {
    if (eventType != 'ENTER' && eventType != 'EXIT') {
      throw ArgumentError(
        'Alert eventType must be exactly "ENTER" or "EXIT", got "$eventType".',
      );
    }
    if (status != 'Unread' && status != 'Read') {
      throw ArgumentError(
        'Alert status must be "Unread" or "Read", got "$status".',
      );
    }
    if (!isValidCoordinate(latitude, longitude)) {
      throw ArgumentError(
        'Coordinates must be finite and within geographic bounds.',
      );
    }

    final payload = <String, dynamic>{
      'userId': userId,
      'userName': userName,
      'userEmail': userEmail,
      'safeZoneId': safeZoneId,
      'safeZoneName': safeZoneName,
      'eventType': eventType,
      'latitude': latitude,
      'longitude': longitude,
      'timestamp': timestamp,
      'status': status,
    };

    if (zoneType != null) {
      if (zoneType != 'Safe' && zoneType != 'Danger') {
        throw ArgumentError(
          'Optional zoneType must be "Safe" or "Danger", got "$zoneType".',
        );
      }
      payload['zoneType'] = zoneType;
    }

    return payload;
  }

  String? _cachedUserName;

  Future<String> _resolveUserName(String uid) async {
    if (_cachedUserName != null && _cachedUserName!.isNotEmpty) {
      return _cachedUserName!;
    }
    final authName = _auth?.currentUser?.displayName?.trim();
    if (authName != null && authName.isNotEmpty) {
      _cachedUserName = authName;
      return authName;
    }
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      final data = doc.data();
      final name = (data?['name'] ?? data?['fullName'])?.toString().trim();
      if (name != null && name.isNotEmpty) {
        _cachedUserName = name;
        return name;
      }
    } catch (e) {
      debugPrint('Could not fetch user name from users collection: $e');
    }
    return 'Tourist';
  }

  Future<DocumentReference<Map<String, dynamic>>?> recordGeoFenceAlert({
    required String zoneId,
    required String zoneName,
    required String eventType,
    required double latitude,
    required double longitude,
    String? zoneType,
    String? userName,
    String? userEmail,
  }) async {
    debugPrint(
      '🔄 Recording geo_fence_alert: eventType=$eventType, zoneId=$zoneId, zoneName=$zoneName.',
    );

    try {
      final user = _auth?.currentUser;
      if (user == null) {
        debugPrint(
          '⚠️ geo_fence_alerts creation skipped: no authenticated user.',
        );
        return null;
      }

      final resolvedUserName = userName ?? await _resolveUserName(user.uid);
      final resolvedUserEmail = userEmail ?? user.email ?? '';

      final payload = buildGeoFenceAlertPayload(
        userId: user.uid,
        userName: resolvedUserName,
        userEmail: resolvedUserEmail,
        safeZoneId: zoneId,
        safeZoneName: zoneName,
        eventType: eventType,
        latitude: latitude,
        longitude: longitude,
        timestamp: FieldValue.serverTimestamp(),
        status: 'Unread',
        zoneType: zoneType,
      );

      final docRef = await _firestore
          .collection('geo_fence_alerts')
          .add(payload);
      debugPrint('✅ geo_fence_alerts created: id=${docRef.id}.');
      return docRef;
    } catch (e, stackTrace) {
      debugPrint('❌ geo_fence_alerts creation failed: $e');
      debugPrint('geo_fence_alerts failure stack trace: $stackTrace');
      return null;
    }
  }
}

class ZoneTransition {
  const ZoneTransition({required this.zoneId, required this.entered});

  final String zoneId;
  final bool entered;
}

class ZoneTransitionTracker {
  final Map<String, bool> _insideByZone = {};

  List<ZoneTransition> update(Map<String, bool> currentStates) {
    final transitions = <ZoneTransition>[];
    for (final entry in currentStates.entries) {
      final previous = _insideByZone[entry.key];
      if (previous != null && previous != entry.value) {
        transitions.add(
          ZoneTransition(zoneId: entry.key, entered: entry.value),
        );
      }
    }
    _insideByZone
      ..clear()
      ..addAll(currentStates);
    return transitions;
  }

  void reset() => _insideByZone.clear();
}
