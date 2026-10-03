import 'package:flutter/material.dart';

class SosProgressScreen extends StatelessWidget {
  const SosProgressScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFEF2F2),
      appBar: AppBar(
        title: const Text('SOS Progress'),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 20),

              const Icon(
                Icons.emergency_rounded,
                color: Colors.red,
                size: 80,
              ),

              const SizedBox(height: 20),

              const Text(
                'SOS IN PROGRESS',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),

              const SizedBox(height: 12),

              const Text(
                'Your emergency request is currently active.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 17,
                  color: Colors.black87,
                ),
              ),

              const SizedBox(height: 35),

              _buildProgressStep(
                icon: Icons.check_circle,
                title: 'SOS Request Sent',
                subtitle: 'Emergency request has been created.',
                completed: true,
              ),

              _buildLine(),

              _buildProgressStep(
                icon: Icons.location_on,
                title: 'Location Shared',
                subtitle: 'Your current location has been shared.',
                completed: true,
              ),

              _buildLine(),

              _buildProgressStep(
                icon: Icons.emergency,
                title: 'SOS Active',
                subtitle: 'Emergency request is active.',
                completed: true,
              ),

              _buildLine(),

              _buildProgressStep(
                icon: Icons.hourglass_top,
                title: 'Waiting for Response',
                subtitle: 'Waiting for emergency assistance.',
                completed: false,
              ),

              const SizedBox(height: 35),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.red.shade200,
                  ),
                ),
                child: const Column(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.red,
                      size: 30,
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Please remain in a safe location and keep your phone available.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 25),

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
                      width: 2,
                    ),
                    padding: const EdgeInsets.symmetric(
                      vertical: 16,
                    ),
                  ),
                  child: const Text(
                    'BACK TO ACTIVE SOS',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressStep({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool completed,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          color: completed ? Colors.red : Colors.grey,
          size: 32,
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: completed ? Colors.black87 : Colors.grey,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.black54,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLine() {
    return Container(
      margin: const EdgeInsets.only(
        left: 15,
        top: 5,
        bottom: 5,
      ),
      width: 2,
      height: 35,
      color: Colors.red.shade200,
    );
  }
}