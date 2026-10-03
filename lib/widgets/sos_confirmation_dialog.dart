import 'package:flutter/material.dart';

Future<bool?> showSosConfirmationDialog(BuildContext context) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      return AlertDialog(
        title: const Row(
          children: [
            Icon(
              Icons.warning_rounded,
              color: Colors.red,
            ),
            SizedBox(width: 8),
            Text('Confirm SOS'),
          ],
        ),
        content: const Text(
          'Are you sure you want to send an SOS emergency alert? '
          'Your current location may be shared with emergency responders.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(false);
            },
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop(true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('SEND SOS'),
          ),
        ],
      );
    },
  );
}