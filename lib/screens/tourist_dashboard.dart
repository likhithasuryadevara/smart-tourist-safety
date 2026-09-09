import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../widgets/danger_banner.dart';
import '../widgets/emergency_panel.dart';
import '../widgets/live_safety_map.dart';
import '../widgets/quick_actions.dart';
import '../widgets/stats_section.dart';
import '../widgets/tourist_top_bar.dart';
import '../widgets/welcome_card.dart';

class TouristDashboard extends StatefulWidget {
  const TouristDashboard({super.key});

  @override
  State<TouristDashboard> createState() => _TouristDashboardState();
}

class _TouristDashboardState extends State<TouristDashboard> {
  static const Color bg = Color(0xFFF8FAFC);

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

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final desktop = constraints.maxWidth >= 900;

            return Column(
              children: [
                TouristTopBar(
                  email: email,
                  onLogout: _logout,
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

                            WelcomeCard(email: email),

                            const SizedBox(height: 14),

                            StatsSection(desktop: desktop),

                            const SizedBox(height: 14),

                            QuickActions(
                              desktop: desktop,
                              onAction: (title) {
                                _showMessage(
                                  '$title will be connected next.',
                                );
                              },
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
                                        _showMessage(
                                          '$title will be connected next.',
                                        );
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
                                      _showMessage(
                                        '$title will be connected next.',
                                      );
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
    );
  }
}