import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'screens/tourist_management.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _selectedIndex = 0;

  final List<String> _titles = [
    'Dashboard',
    'Tourist Management',
    'Live Tourist Monitoring',
    'Interactive Map',
    'Safe Zone Management',
    'SOS Monitoring',
    'Complaint Management',
    'Evidence Vault',
    'Alerts & Notifications',
    'Analytics',
    'Settings',
  ];

  final List<IconData> _icons = [
    Icons.dashboard,
    Icons.people,
    Icons.radio,
    Icons.map,
    Icons.shield,
    Icons.warning,
    Icons.description,
    Icons.lock,
    Icons.notifications,
    Icons.bar_chart,
    Icons.settings,
  ];

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();

    if (!mounted) return;

    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 1,
        title: Text(_titles[_selectedIndex]),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {
              setState(() {
                _selectedIndex = 8;
              });
            },
          ),
          PopupMenuButton<String>(
            icon: const CircleAvatar(
              child: Icon(Icons.person),
            ),
            onSelected: (value) {
              if (value == 'logout') {
                _logout();
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'profile',
                child: Text('Admin Profile'),
              ),
              PopupMenuItem(
                value: 'logout',
                child: Text('Secure Logout'),
              ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      drawer: Drawer(
        child: SafeArea(
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                child: const Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      child: Icon(Icons.shield),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'SMART TOURIST',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Safety Command Center',
                            style: TextStyle(
                              color: Colors.blue,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(),
              Expanded(
                child: ListView.builder(
                  itemCount: _titles.length,
                  itemBuilder: (context, index) {
                    return ListTile(
                      leading: Icon(_icons[index]),
                      title: Text(_titles[index]),
                      selected: _selectedIndex == index,
                      selectedTileColor: Colors.blue.shade50,
                      selectedColor: Colors.blue,
                      onTap: () {
                        setState(() {
                          _selectedIndex = index;
                        });
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
              const Divider(),
              const Padding(
                padding: EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      Icons.circle,
                      size: 10,
                      color: Colors.green,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Secure Connection',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.green,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      body: _buildContent(),
    );
  }

  Widget _buildContent() {
    switch (_selectedIndex) {
      case 0:
        return _dashboard();
      case 1:
       return const TouristManagement();
      case 2:
        return _liveTouristMonitoring();
      case 3:
        return _placeholder('Interactive Map');
      case 4:
        return _placeholder('Safe Zone Management');
      case 5:
        return _placeholder('SOS Monitoring');
      case 6:
        return _placeholder('Complaint Management');
      case 7:
        return _placeholder('Evidence Vault');
      case 8:
        return _placeholder('Alerts & Notifications');
      case 9:
        return _placeholder('Analytics');
      case 10:
        return _placeholder('Settings');
      default:
        return _dashboard();
    }
  }

  Widget _dashboard() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Command Center',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Smart Tourist Safety & Emergency Response System',
            style: TextStyle(
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 24),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.5,
            children: [
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .where('role', isEqualTo: 'tourist')
                    .snapshots(),
                builder: (context, snapshot) {
                  final count = snapshot.hasData ? snapshot.data!.docs.length : 0;

                  return _statCard(
                    'Total Tourists',
                    count.toString(),
                    Icons.people,
                  );
                },
              ),
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('sos')
                    .where('status', isEqualTo: 'active')
                    .snapshots(),
                builder: (context, snapshot) {
                  final count = snapshot.hasData ? snapshot.data!.docs.length : 0;

                  return _statCard(
                    'Active SOS',
                    count.toString(),
                    Icons.warning,
                  );
                },
              ),
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('complaints')
                    .where('status', isEqualTo: 'pending')
                    .snapshots(),
                builder: (context, snapshot) {
                  final count = snapshot.hasData ? snapshot.data!.docs.length : 0;

                  return _statCard(
                    'Pending Complaints',
                    count.toString(),
                    Icons.description,
                  );
                },
              ),
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('safe_zones')
                    .snapshots(),
                builder: (context, snapshot) {
                  final count = snapshot.hasData ? snapshot.data!.docs.length : 0;

                  return _statCard(
                    'Safe Zones',
                    count.toString(),
                    Icons.shield,
                  );
                },
              ),
              
            ],
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'System Status',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _statusRow('Firebase Authentication', true),
                  _statusRow('Cloud Firestore', true),
                  _statusRow('Admin Access', true),
                  _statusRow('Secure Connection', true),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statCard(
    String title,
    String value,
    IconData icon,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            CircleAvatar(
              radius: 25,
              backgroundColor: Colors.blue.shade50,
              child: Icon(
                icon,
                color: Colors.blue,
              ),
            ),
            const SizedBox(width: 14),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusRow(String title, bool active) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Icon(
            Icons.check_circle,
            color: active ? Colors.green : Colors.red,
            size: 18,
          ),
          const SizedBox(width: 10),
          Text(title),
          const Spacer(),
          Text(
            active ? 'Active' : 'Offline',
            style: TextStyle(
              color: active ? Colors.green : Colors.red,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
  Widget _liveTouristMonitoring() {
    final MapController mapController = MapController();
  return StreamBuilder<QuerySnapshot>(
    stream: FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'tourist')
        .snapshots(),
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Center(
          child: CircularProgressIndicator(),
        );
      }

      if (snapshot.hasError) {
        return Center(
          child: Text('Error: ${snapshot.error}'),
        );
      }

      final tourists = snapshot.data?.docs ?? [];

      final touristsWithLocation = tourists.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return data['latitude'] != null &&
            data['longitude'] != null;
      }).toList();

      if (touristsWithLocation.isEmpty) {
        return const Center(
          child: Text('No tourist location available.'),
        );
      }

      final firstTourist =
          touristsWithLocation.first.data() as Map<String, dynamic>;

      final latitude =
          (firstTourist['latitude'] as num).toDouble();

      final longitude =
          (firstTourist['longitude'] as num).toDouble();

      final touristName =
          firstTourist['name']?.toString() ?? 'Tourist';
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          mapController.move(
            LatLng(latitude, longitude),
            15,
          );
        }
      });
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(
                  Icons.location_on,
                  color: Colors.blue,
                ),
                const SizedBox(width: 8),
                Text(
                  'Live Location: $touristName',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: FlutterMap(
               mapController: mapController,
              options: MapOptions(
                initialCenter: LatLng(
                  latitude,
                  longitude,
                ),
                initialZoom: 15,
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName:
                      'com.example.smart_tourist_safety',
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: LatLng(
                        latitude,
                        longitude,
                      ),
                      width: 80,
                      height: 80,
                      child: Column(
                        children: [
                          const Icon(
                            Icons.location_on,
                            color: Colors.red,
                            size: 45,
                          ),
                          Text(
                            touristName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              backgroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      );
    },
  );
}
  Widget _placeholder(String title) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.construction,
            size: 60,
            color: Colors.blue,
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'This section will be connected to Firebase next.',
          ),
        ],
      ),
    );
  }
}