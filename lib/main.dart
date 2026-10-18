import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'config/build_config.dart';
import 'firebase_options.dart';
import 'admin_dashboard.dart';
import 'screens/login_screen.dart';
import 'screens/tourist_dashboard.dart';
import 'screens/tourist_profile.dart';

Future<void> main() async {
  debugPrint('STARTUP: main entered');
  WidgetsFlutterBinding.ensureInitialized();

  debugPrint('STARTUP: Firebase initialization starting');
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint('STARTUP: Firebase initialization completed');

  // Force sign out on startup to require explicit login each launch
  await FirebaseAuth.instance.signOut();
  debugPrint('STARTUP: Signed out any existing session - Login required');

  debugPrint('STARTUP: calling runApp');
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Smart Tourist Safety',

      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),

      home: const AuthGate(),

      routes: {
        '/login': (context) => const LoginScreen(),
        '/tourist-profile': (context) => const TouristProfile(),
      },
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  StreamSubscription<User?>? _authSubscription;
  bool _isCheckingAuth = true;
  User? _initialUser;

  @override
  void initState() {
    super.initState();
    _initialUser = FirebaseAuth.instance.currentUser;
    debugPrint(
      'STARTUP: AuthGate.initState - currentUser is ${_initialUser == null ? 'null' : 'signed-in'}',
    );
    _listenToAuthChanges();
  }

  void _listenToAuthChanges() {
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen(
      (User? user) {
        debugPrint(
          'STARTUP: authStateChanges event - user is ${user == null ? 'null' : 'signed-in'}',
        );
        if (!mounted) return;
        // Let the StreamBuilder in build() handle the routing
        // This subscription mainly ensures we react to auth changes
        setState(() {}); // Trigger rebuild to pick up new auth state
      },
      onError: (Object error) {
        debugPrint('Auth state listener error: $error');
      },
    );
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      initialData: _initialUser,
      builder: (context, snapshot) {
        debugPrint(
          'STARTUP: StreamBuilder - connectionState=${snapshot.connectionState}, _isCheckingAuth=$_isCheckingAuth, user=${snapshot.data == null ? 'null' : 'signed-in'}',
        );
        // Exit checking state once the auth stream has emitted (active or done)
        if (snapshot.connectionState != ConnectionState.waiting) {
          _isCheckingAuth = false;
        }
        if (snapshot.connectionState == ConnectionState.waiting ||
            _isCheckingAuth) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = snapshot.data;

        if (user == null) {
          return const LoginScreen();
        }

        // User is signed in - check their profile to determine destination
        return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          future: FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get(),
          builder: (context, userDocSnapshot) {
            debugPrint(
              'STARTUP: Firestore FutureBuilder - connectionState=${userDocSnapshot.connectionState}, hasError=${userDocSnapshot.hasError}${userDocSnapshot.hasError ? ', error=${userDocSnapshot.error}' : ''}',
            );
            if (userDocSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            if (userDocSnapshot.hasError) {
              debugPrint('AUTHGATE: Firestore error - ${userDocSnapshot.error}');
              // Sign out on error and show login
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  FirebaseAuth.instance.signOut();
                }
              });
              return const LoginScreen();
            }

            final userDoc = userDocSnapshot.data;

            if (userDoc == null || !userDoc.exists) {
              debugPrint('AUTHGATE: No user profile - redirecting to login');
              // No profile - sign out and show login
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  FirebaseAuth.instance.signOut();
                }
              });
              return const LoginScreen();
            }

            final data = userDoc.data();
            if (data == null) {
              debugPrint('AUTHGATE: Empty user profile data - redirecting to login');
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  FirebaseAuth.instance.signOut();
                }
              });
              return const LoginScreen();
            }

            final role = data['role'] ?? 'tourist';
            final approvalStatus = data['approvalStatus'] ?? 'pending';
            final accountStatus = data['accountStatus'] ?? 'active';

            debugPrint(
              'AUTHGATE: Profile data - role=$role, approvalStatus=$approvalStatus, accountStatus=$accountStatus, emailVerified=${user.emailVerified}',
            );

            // DIAGNOSTIC: Log exact redirect conditions
            debugPrint(
              'AUTHGATE: Redirect check - emailVerified=${user.emailVerified}, accountStatus=$accountStatus, role=$role',
            );

            // Suspended account
            if (accountStatus == 'suspended') {
              debugPrint('AUTHGATE: Redirect reason - Suspended account');
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  FirebaseAuth.instance.signOut();
                }
              });
              return const LoginScreen();
            }

            // Admin
            if (role == 'admin') {
              debugPrint('AUTHGATE: Admin role - routing to AdminDashboard');
              return const AdminDashboard();
            }

            // Tourist - require email verified and active account (no approvalStatus check as Admin approval not implemented)
            if (role == 'tourist') {
              if (kRequireEmailVerification && !user.emailVerified) {
                debugPrint('AUTHGATE: Redirect reason - Email not verified');
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    FirebaseAuth.instance.signOut();
                  }
                });
                return const LoginScreen();
              }

              debugPrint('AUTHGATE: Tourist role - routing to TouristDashboard');
              return const TouristDashboard();
            }

            // Unknown role
            debugPrint('AUTHGATE: Redirect reason - Unknown role: $role');
            return const LoginScreen();
          },
        );
      },
    );
  }
}
