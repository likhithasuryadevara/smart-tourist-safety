import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../widgets/danger_banner.dart';
import '../widgets/emergency_panel.dart';
import '../widgets/live_safety_map.dart';
import '../widgets/quick_actions.dart';
import '../widgets/stats_section.dart';
import '../widgets/tourist_top_bar.dart';
import '../widgets/welcome_card.dart';
import 'sos_countdown_screen.dart';
import 'sos_history_screen.dart';
import 'notifications_screen.dart';


class TouristDashboard extends StatefulWidget {
  const TouristDashboard({super.key});

  @override
  State<TouristDashboard> createState() => _TouristDashboardState();
}

class _TouristDashboardState extends State<TouristDashboard> {
  static const Color bg = Color(0xFFF8FAFC);

  String _name = '';

  Future<void> _handleSos() async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const SosCountdownScreen(),
      ),
    );

    if (!mounted) return;

    if (result == true) {
      _showMessage('SOS sent successfully.');
    }
  }

  @override
  void initState() {
    super.initState();
    _loadTouristName();
  }

  Future<void> _loadTouristName() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!mounted) return;

      if (doc.exists) {
        final data = doc.data();

        setState(() {
          _name = data?['name']?.toString() ?? '';
        });
      }
    } catch (e) {
      debugPrint('Error loading tourist name: $e');
    }
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();

    if (!mounted) return;

    Navigator.of(context).pushNamedAndRemoveUntil(
      '/login',
      (route) => false,
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF17233A),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    final email = user?.email ?? 'tourist@example.com';

    final name = _name.isNotEmpty
        ? _name
        : email.split('@').first;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final desktop = constraints.maxWidth >= 900;

            return Column(
              children: [
                TouristTopBar(
                  name: name,
                  email: email,
                  onLogout: _logout,
                  onProfile: () {
                    Navigator.of(context).pushNamed('/tourist-profile');
                  },
                ),

                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(
                      horizontal: desktop ? 24 : 12,
                      vertical: 14,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: 1450,
                        ),
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            DangerBanner(
                              onTap: () {
                                _showMessage(
                                  'Safe Zone navigation will be connected next.',
                                );
                              },
                            ),

                            const SizedBox(height: 14),

                            WelcomeCard(
                              name: name,
                            ),
                            
                            const SizedBox(height: 14),
                            StatsSection(
                              desktop: desktop,
                            ),

                            const SizedBox(height: 14),

                            QuickActions(
                              desktop: desktop,
                              onAction: (title) {
                                if (title == 'SOS Emergency') {
                                  _handleSos();
                                } else {
                                  _showMessage(
                                    '$title will be connected next.',
                                  );
                                }
                              },
                            ),

                            const SizedBox(height: 14),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (context) => const NotificationsScreen(),
                                    ),
                                  );
                                },
                                icon: const Icon(
                                  Icons.notifications,
                                  color: Colors.teal,
                                ),
                                label: const Text(
                                  'Notifications',
                                  style: TextStyle(
                                    color: Colors.teal,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 12),

                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (context) => const SosHistoryScreen(),
                                    ),
                                  );
                                },
                                icon: const Icon(
                                  Icons.history,
                                  color: Colors.red,
                                ),
                                
                                
                                label: const Text(
                                  'SOS History',
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 14),

                            if (desktop)
                              Row(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    flex: 7,
                                    child: LiveSafetyMap(
                                      onFullscreen: () {
                                        _showMessage(
                                          'Full-screen map will be connected next.',
                                        );
                                      },
                                    ),
                                  ),

                                  const SizedBox(width: 14),

                                  Expanded(
                                    flex: 3,
                                    child: EmergencyPanel(
                                      onAction: (title) {
                                        if (title == 'SOS Emergency') {
                                          _handleSos();
                                        } else {
                                          _showMessage(
                                            '$title will be connected next.',
                                          );
                                        }
                                      },
                                    ),
                                  ),
                                ],
                              )
                            else
                              Column(
                                children: [
                                  LiveSafetyMap(
                                    onFullscreen: () {
                                      _showMessage(
                                        'Full-screen map will be connected next.',
                                      );
                                    },
                                  ),

                                  const SizedBox(height: 14),

                                  EmergencyPanel(
                                    onAction: (title) {
                                      if (title == 'SOS Emergency') {
                                        _handleSos();
                                      } else {
                                        _showMessage(
                                          '$title will be connected next.',
                                        );
                                      }
                                    },
                                  ),
                                ],
                              ),

                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          }, 
        ),
        
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _handleSos,
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
        child: const Icon(
          Icons.sos,
          size: 32,
        ),
      ),
    );
  }
}