import 'dart:async';

import 'package:flutter/material.dart';

class VoiceSosConfirmationDialog extends StatefulWidget {
  const VoiceSosConfirmationDialog({super.key});

  @override
  State<VoiceSosConfirmationDialog> createState() =>
      _VoiceSosConfirmationDialogState();
}

class _VoiceSosConfirmationDialogState
    extends State<VoiceSosConfirmationDialog> {
  static const int _countdownStart = 10;

  late int _secondsRemaining;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _secondsRemaining = _countdownStart;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_secondsRemaining <= 1) {
        timer.cancel();
        Navigator.of(context).pop(true);
        return;
      }

      setState(() {
        _secondsRemaining--;
      });
    });
  }

  void _finish(bool sendSos) {
    _timer?.cancel();
    Navigator.of(context).pop(sendSos);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: AlertDialog(
        backgroundColor: const Color(0xFF111C31),
        icon: const Icon(
          Icons.warning_rounded,
          color: Color(0xFFE11D48),
          size: 38,
        ),
        title: const Text(
          'Voice SOS Detected',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Emergency assistance will be requested automatically.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFFCBD5E1)),
            ),
            const SizedBox(height: 16),
            const Text(
              'Sending SOS in',
              style: TextStyle(color: Color(0xFFCBD5E1)),
            ),
            const SizedBox(height: 12),
            Container(
              width: 76,
              height: 76,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFFE11D48),
                  width: 3,
                ),
              ),
              child: Text(
                '$_secondsRemaining',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'seconds',
              style: TextStyle(color: Color(0xFFCBD5E1)),
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actions: [
          TextButton(
            onPressed: () => _finish(false),
            child: const Text('CANCEL'),
          ),
          FilledButton(
            onPressed: () => _finish(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('SEND SOS NOW'),
          ),
        ],
      ),
    );
  }
}
