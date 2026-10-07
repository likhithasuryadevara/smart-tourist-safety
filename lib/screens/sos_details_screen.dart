import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class SosDetailsScreen extends StatelessWidget {
  final Map<String, dynamic> sosData;

  const SosDetailsScreen({
    super.key,
    required this.sosData,
  });

  @override
  Widget build(BuildContext context) {
    final status =
        sosData['status']?.toString() ?? 'unknown';

    final latitude =
        sosData['latitude']?.toString() ?? 'N/A';

    final longitude =
        sosData['longitude']?.toString() ?? 'N/A';

    final touristName =
        sosData['touristName']?.toString() ?? 'Unknown';

    final email =
        sosData['email']?.toString() ?? 'N/A';

    final phone =
        sosData['phone']?.toString() ?? 'N/A';

    final createdAt = sosData['createdAt'];
    final timestamp = createdAt is Timestamp ? createdAt : null;

    final dateText = timestamp != null
        ? _formatDate(timestamp.toDate())
        : 'Date unavailable';

    return Scaffold(
      appBar: AppBar(
        title: const Text('SOS Details'),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              width: 110,
              height: 110,
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.sos,
                color: Colors.white,
                size: 60,
              ),
            ),

            const SizedBox(height: 20),

            const Text(
              'SOS EMERGENCY',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),

            const SizedBox(height: 24),

            _detailCard(
              icon: Icons.info_outline,
              title: 'Status',
              value: status.toUpperCase(),
            ),

            _detailCard(
              icon: Icons.calendar_today,
              title: 'Date & Time',
              value: dateText,
            ),

            _detailCard(
              icon: Icons.person,
              title: 'Tourist',
              value: touristName,
            ),

            _detailCard(
              icon: Icons.email,
              title: 'Email',
              value: email,
            ),

            _detailCard(
              icon: Icons.phone,
              title: 'Phone',
              value: phone,
            ),

            _detailCard(
              icon: Icons.location_on,
              title: 'Latitude',
              value: latitude,
            ),

            _detailCard(
              icon: Icons.location_on,
              title: 'Longitude',
              value: longitude,
            ),

            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(
                    color: Colors.red,
                  ),
                  padding: const EdgeInsets.symmetric(
                    vertical: 15,
                  ),
                ),
                child: const Text(
                  'BACK TO SOS HISTORY',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailCard({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.red.shade100,
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: Colors.red,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _formatDate(DateTime date) {
    final day =
        date.day.toString().padLeft(2, '0');

    final month =
        date.month.toString().padLeft(2, '0');

    final year =
        date.year.toString();

    final hour =
        date.hour.toString().padLeft(2, '0');

    final minute =
        date.minute.toString().padLeft(2, '0');

    return '$day/$month/$year $hour:$minute';
  }
}