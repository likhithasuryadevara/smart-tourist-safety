import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../services/location_service.dart';
import '../services/notification_service.dart';
import '../utils/app_error_message.dart';
import 'sos_active_screen.dart';
import 'sos_failure_screen.dart';


import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SosCountdownScreen extends StatefulWidget {
  const SosCountdownScreen({super.key});

  @override
  State<SosCountdownScreen> createState() => _SosCountdownScreenState();
}

class _SosCountdownScreenState extends State<SosCountdownScreen> {
  static const int _countdownSeconds = 20;

  late int _secondsRemaining;
  Timer? _timer;

  final LocationService _locationService = LocationService();
  final NotificationService _notificationService = NotificationService();
  bool _isSending = false;

  @override
  void initState() {
    super.initState();

    _secondsRemaining = _countdownSeconds;

    _startCountdown();
  }

  void _startCountdown() {
    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (timer) {
        if (!mounted) return;

        if (_secondsRemaining <= 1) {
          timer.cancel();

          setState(() {
            _secondsRemaining = 0;
          });

          _sendSos();

          return;
        }

        setState(() {
          _secondsRemaining--;
        });
      },
    );
  }

  void _cancelSos() {
    _timer?.cancel();

    Navigator.of(context).pop(false);
  }

  Future<void> _sendSos() async {
    if (_isSending) return;
    if (mounted) setState(() => _isSending = true);
    _timer?.cancel();
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Unable to send SOS. Please sign in again.',
          ),
        ),
      );

      Navigator.of(context).pop(false);
      return;
    }

    final position = await _locationService
          .getCurrentLocation()
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () => null,
          );

      if (!mounted) return;

      Position? sosPosition = position;
      Object? savedLocationError;

      if (sosPosition == null) {
        debugPrint('Fresh GPS unavailable; trying the last saved location.');

        try {
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();

          final userData = userDoc.data();

          final latitude =
              (userData?['latitude'] as num?)?.toDouble();

          final longitude =
              (userData?['longitude'] as num?)?.toDouble();

          if (latitude != null && longitude != null) {
            sosPosition = Position(
              latitude: latitude,
              longitude: longitude,
              timestamp: DateTime.now(),
              accuracy: 0,
              altitude: 0,
              altitudeAccuracy: 0,
              heading: 0,
              headingAccuracy: 0,
              speed: 0,
              speedAccuracy: 0,
              isMocked: false,
            );

          }
        } catch (error, stackTrace) {
          savedLocationError = error;
          AppErrorMessage.log(
            error,
            stackTrace,
            context: 'Reading saved location for SOS fallback',
          );
        }
      }

      if (!mounted) return;
      if (sosPosition == null) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => SosFailureScreen(
              message: savedLocationError == null
                  ? 'Unable to obtain your current location. Please check GPS permission and try again.'
                  : AppErrorMessage.from(
                      savedLocationError,
                      fallback:
                          'Unable to obtain your current location. Please check GPS and internet access, then try again.',
                    ),
            ),
          ),
        );

        return;
      }

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final userData = userDoc.data() ?? {};

      final existingSos = await FirebaseFirestore.instance
          .collection('sos')
          .where('touristId', isEqualTo: user.uid)
          .get();

      final hasActiveSos = existingSos.docs.any(
        (doc) => doc.data()['status'] == 'active',
      );

      if (hasActiveSos) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'You already have an active SOS.',
            ),
          ),
        );

        Navigator.of(context).pop(false);
        return;
      }

      final sosDocument =
          await FirebaseFirestore.instance.collection('sos').add({
        'touristId': user.uid,
        'touristName': userData['name'] ?? 'Unknown',
        'email': user.email ?? '',
        'phone': userData['phone'] ?? '',
        'latitude':sosPosition.latitude,
        'longitude':sosPosition.longitude,
        'status': 'active',
        'createdAt': FieldValue.serverTimestamp(),
      });

      debugPrint(
        'SOS document created: id=${sosDocument.id}, '
        'touristId=${user.uid}.',
      );
      debugPrint(
        'Creating SOS Confirmation notification for '
        'sosId=${sosDocument.id}, touristId=${user.uid}.',
      );
      await _notificationService.createSosConfirmationNotification(
        sosId: sosDocument.id,
        touristId: user.uid,
      );

      debugPrint('SOS created successfully');

      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => const SosActiveScreen(),
        ),
      );

    } catch (error, stackTrace) {
      AppErrorMessage.log(error, stackTrace, context: 'Sending tourist SOS');

      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => SosFailureScreen(
            message: AppErrorMessage.from(
              error,
              fallback: 'We could not send your SOS request. Please try again.',
            ),
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress =
        _secondsRemaining / _countdownSeconds;

    return Scaffold(
      backgroundColor: const Color(0xFFFEF2F2),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.warning_rounded,
                  color: Colors.red,
                  size: 80,
                ),

                const SizedBox(height: 24),

                Text(
                  'SOS ACTIVATED',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),

                const SizedBox(height: 12),

                Text(
                  _isSending
                      ? 'Sending your SOS request...'
                      : 'Emergency SOS will be sent automatically.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 17,
                    color: Colors.black87,
                  ),
                ),

                const SizedBox(height: 30),

                SizedBox(
                  width: 180,
                  height: 180,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 180,
                        height: 180,
                        child: CircularProgressIndicator(
                          value: progress,
                          strokeWidth: 12,
                          backgroundColor: Colors.red.shade100,
                          valueColor:
                              const AlwaysStoppedAnimation<Color>(
                            Colors.red,
                          ),
                        ),
                      ),
                      Text(
                        '$_secondsRemaining',
                        style: const TextStyle(
                          fontSize: 56,
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 30),

                const Text(
                  'Tap CANCEL if this was accidental.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.black54,
                  ),
                ),

                const SizedBox(height: 20),

                Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isSending ? null : _sendSos,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            vertical: 16,
                          ),
                        ),
                        child: _isSending
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'CONFIRM SOS - SEND NOW',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: _isSending ? null : _cancelSos,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(
                            color: Colors.red,
                            width: 2,
                          ),
                          padding: const EdgeInsets.symmetric(
                            vertical: 16,
                          ),
                        ),
                        child: const Text(
                          'CANCEL SOS',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}