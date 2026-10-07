import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/notification_service.dart';
import '../services/voice_sos_service.dart';
import '../widgets/danger_banner.dart';
import '../widgets/emergency_panel.dart';
import '../widgets/live_safety_map.dart';
import '../widgets/quick_actions.dart';
import '../widgets/stats_section.dart';
import '../widgets/tourist_top_bar.dart';
import '../widgets/tourist_safety_status.dart';
import '../widgets/tourist_device_status_section.dart';
import '../widgets/voice_sos_confirmation_dialog.dart';
import '../widgets/welcome_card.dart';
import 'sos_countdown_screen.dart';
import 'sos_history_screen.dart';
import 'notifications_screen.dart';
import 'tourist_safety_history_screen.dart';

class TouristDashboard extends StatefulWidget {
  const TouristDashboard({super.key});

  @override
  State<TouristDashboard> createState() => _TouristDashboardState();
}

class _TouristDashboardState extends State<TouristDashboard>
    with WidgetsBindingObserver {
  static const Color bg = Color(0xFFF8FAFC);

  static final VoiceSosService _voiceSosService = VoiceSosService();
  final NotificationService _notificationService = NotificationService();
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
  _sosStatusSubscription;
  Timer? _voiceRestartTimer;

  String _name = '';
  String _voiceSosMessage = 'Starting automatic Voice SOS monitoring...';
  bool _voiceSosListening = false;
  bool _voiceSosStarting = false;
  bool _voiceConfirmationShowing = false;
  bool _voiceResultReceivedInSession = false;
  bool _voiceRecognitionErrorInSession = false;
  bool _appIsResumed = true;

  Future<void> _handleSos() async {
    final result = await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => const SosCountdownScreen()));

    if (!mounted) return;

    if (result == true) {
      _showMessage('SOS sent successfully.');
    }
  }

  Future<void> _startVoiceSosMonitoring() async {
    if (!mounted ||
        !_appIsResumed ||
        _voiceSosStarting ||
        _voiceSosListening ||
        _voiceConfirmationShowing) {
      return;
    }

    _voiceRestartTimer?.cancel();
    setState(() {
      _voiceSosStarting = true;
      _voiceSosMessage = 'Voice SOS: Initializing...';
    });

    debugPrint('Voice SOS: automatic monitoring start requested');
    await _voiceSosService.startListening(
      onListeningChanged: (listening) {
        if (!mounted) return;
        setState(() {
          _voiceSosListening = listening;
          if (listening) {
            _voiceResultReceivedInSession = false;
            _voiceRecognitionErrorInSession = false;
            _voiceSosMessage = 'Voice SOS: Listening...';
          } else {
            _voiceSosMessage =
                'Voice SOS: Recognition session stopped; waiting for status.';
          }
        });
      },
      onResult: (transcript, isTrigger) {
        if (!mounted) return;
        _voiceResultReceivedInSession = true;
        setState(() {
          _voiceSosMessage = 'Voice SOS: Heard: $transcript';
        });
      },
      onDiagnostic: (status) {
        if (!mounted) return;
        setState(() {
          _voiceSosMessage = status;
        });
      },
      onError: (message) {
        if (!mounted) return;
        _voiceRecognitionErrorInSession = true;
        setState(() {
          _voiceSosListening = false;
          _voiceSosMessage = 'Voice SOS: $message';
        });
        if (_voiceSosService.shouldRetryAutomatically(message) &&
            _voiceSosService.isSessionSettled) {
          _scheduleVoiceSosMonitoring(delay: const Duration(seconds: 4));
        }
      },
      onTrigger: (_) {
        if (mounted) unawaited(_handleVoiceSosTrigger());
      },
      onSessionEnded: () {
        if (!mounted) return;
        setState(() {
          _voiceSosListening = false;
          _voiceSosMessage = _voiceRecognitionErrorInSession
              ? 'Voice SOS: Recognition error; session stopped.'
              : _voiceResultReceivedInSession
              ? 'Voice SOS: Waiting for speech...'
              : 'Voice SOS: No speech result received';
        });
        _scheduleVoiceSosMonitoring();
      },
    );

    if (!mounted) return;
    setState(() {
      _voiceSosStarting = false;
    });
  }

  void _scheduleVoiceSosMonitoring({
    Duration delay = const Duration(seconds: 4),
  }) {
    _voiceRestartTimer?.cancel();
    debugPrint(
      'Voice SOS: automatic restart attempt scheduled in '
      '${delay.inSeconds} second(s)',
    );
    _voiceRestartTimer = Timer(delay, () {
      if (!mounted || !_appIsResumed) return;
      debugPrint('Voice SOS: automatic restart attempt started');
      unawaited(_startVoiceSosMonitoring());
    });
  }

  Future<void> _handleVoiceSosTrigger() async {
    if (_voiceConfirmationShowing || !mounted) return;
    _voiceConfirmationShowing = true;
    var resumeMonitoring = true;
    _voiceRestartTimer?.cancel();

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _showMessage('Please sign in again to send an SOS.');
        return;
      }

      final existingSos = await FirebaseFirestore.instance
          .collection('sos')
          .where('touristId', isEqualTo: user.uid)
          .get();

      if (!mounted) return;
      if (VoiceSosService.hasActiveSos(
        existingSos.docs.map((document) => document.data()),
      )) {
        _showMessage('An SOS is already active.');
        return;
      }

      final confirmed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => const VoiceSosConfirmationDialog(),
      );

      if (!mounted) return;
      if (confirmed == true) {
        setState(() {
          _voiceSosMessage = 'Starting the existing SOS flow...';
        });
        resumeMonitoring = false;
        await _handleSos();
      } else {
        setState(() {
          _voiceSosMessage = 'Voice SOS cancelled. Monitoring will resume.';
        });
      }
    } catch (error, stackTrace) {
      debugPrint(
        'Unable to verify active SOS before Voice SOS: $error\n$stackTrace',
      );
      if (mounted) {
        _showMessage('Unable to verify your SOS status. No new SOS was sent.');
      }
    } finally {
      _voiceConfirmationShowing = false;
      if (mounted && resumeMonitoring) {
        _voiceRestartTimer?.cancel();
        setState(() {
          _voiceSosListening = false;
          _voiceSosMessage =
              'Voice SOS: Confirmation cancelled; waiting for recognition to stop...';
        });

        final sessionStopped =
            await _voiceSosService.waitForSessionToStop();
        if (mounted && _appIsResumed) {
          if (sessionStopped) {
            setState(() {
              _voiceSosMessage =
                  'Voice SOS: Restarting monitoring after confirmation...';
            });
            await _startVoiceSosMonitoring();
          } else {
            setState(() {
              _voiceSosMessage =
                  'Voice SOS: Recognition session still stopping; retrying safely.';
            });
            _scheduleVoiceSosMonitoring(delay: const Duration(seconds: 4));
          }
        }
      }
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadTouristName();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _sosStatusSubscription = _notificationService.listenForSosStatusChanges(
        user.uid,
      );
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_startVoiceSosMonitoring());
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appIsResumed = state == AppLifecycleState.resumed;
    if (_appIsResumed) {
      _voiceRestartTimer?.cancel();
      _scheduleVoiceSosMonitoring(delay: const Duration(seconds: 4));
      return;
    }

    _voiceRestartTimer?.cancel();
    _voiceRestartTimer = null;
    unawaited(_voiceSosService.cancelListening());
    if (mounted) {
      setState(() {
        _voiceSosListening = false;
        _voiceSosMessage = 'Voice SOS: Paused while app is inactive.';
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sosStatusSubscription?.cancel();
    _voiceRestartTimer?.cancel();
    unawaited(_voiceSosService.detachScreen());
    super.dispose();
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

    Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
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

    final name = _name.isNotEmpty ? _name : email.split('@').first;

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
                        constraints: const BoxConstraints(maxWidth: 1450),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            DangerBanner(
                              onTap: () {
                                _showMessage(
                                  'Safe Zone navigation will be connected next.',
                                );
                              },
                            ),

                            const SizedBox(height: 14),

                            const TouristSafetyStatus(),

                            const SizedBox(height: 14),

                            const TouristDeviceStatusSection(),

                            const SizedBox(height: 14),

                            WelcomeCard(name: name),
                            const SizedBox(height: 14),
                            StatsSection(desktop: desktop),

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
                                      builder: (context) =>
                                          const NotificationsScreen(),
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
                                      builder: (context) =>
                                          const TouristSafetyHistoryScreen(),
                                    ),
                                  );
                                },
                                icon: const Icon(
                                  Icons.history,
                                  color: Colors.teal,
                                ),
                                label: const Text(
                                  'Safety History',
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
                                      builder: (context) =>
                                          const SosHistoryScreen(),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.sos, color: Colors.red),
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
                                crossAxisAlignment: CrossAxisAlignment.start,
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
                                      voiceListening: _voiceSosListening,
                                      voiceStatus: _voiceSosMessage,
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
                                    voiceListening: _voiceSosListening,
                                    voiceStatus: _voiceSosMessage,
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
        child: const Icon(Icons.sos, size: 32),
      ),
    );
  }
}
