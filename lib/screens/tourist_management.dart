import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class TouristManagement extends StatefulWidget {
  const TouristManagement({super.key});

  @override
  State<TouristManagement> createState() => _TouristManagementState();
}

class _TouristManagementState extends State<TouristManagement> {
  String searchText = '';

  // APPROVE / ACTIVATE TOURIST
  Future<void> _activateTourist(String userId) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .update({
        'accountStatus': 'active',
        'approvalStatus': 'approved',
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tourist activated successfully'),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
        ),
      );
    }
  }

  // SUSPEND TOURIST
  Future<void> _suspendTourist(String userId) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .update({
        'accountStatus': 'suspended',
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tourist suspended successfully'),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
        ),
      );
    }
  }

  // CONFIRM ACTION
  Future<void> _confirmAction({
    required String title,
    required String message,
    required VoidCallback onConfirm,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context, true);
              },
              child: const Text('Confirm'),
            ),
          ],
        );
      },
    );

    if (result == true) {
      onConfirm();
    }
  }

  @override
  Widget build(BuildContext context) {
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
            child: Text(
              'Error loading tourists:\n${snapshot.error}',
              textAlign: TextAlign.center,
            ),
          );
        }

        final tourists = snapshot.data?.docs ?? [];

        // SEARCH TOURISTS
        final filteredTourists = tourists.where((doc) {
          final data = doc.data() as Map<String, dynamic>;

          final name =
              (data['name'] ?? '').toString().toLowerCase();

          final email =
              (data['email'] ?? '').toString().toLowerCase();

          final phone =
              (data['phone'] ?? '').toString().toLowerCase();

          return name.contains(searchText.toLowerCase()) ||
              email.contains(searchText.toLowerCase()) ||
              phone.contains(searchText.toLowerCase());
        }).toList();

        // STATUS COUNTS
        final activeCount = tourists.where((doc) {
          final data = doc.data() as Map<String, dynamic>;

          return (data['accountStatus'] ?? 'active')
                  .toString()
                  .toLowerCase() ==
              'active';
        }).length;

        final suspendedCount = tourists.where((doc) {
          final data = doc.data() as Map<String, dynamic>;

          return (data['accountStatus'] ?? '')
                  .toString()
                  .toLowerCase() ==
              'suspended';
        }).length;

        final pendingCount = tourists.where((doc) {
          final data = doc.data() as Map<String, dynamic>;

          return (data['approvalStatus'] ?? '')
                  .toString()
                  .toLowerCase() ==
              'pending';
        }).length;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // HEADER
              const Text(
                'Tourist Management',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 6),

              Text(
                'Manage registered tourists',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 15,
                ),
              ),

              const SizedBox(height: 24),

              // STAT CARDS
              LayoutBuilder(
                builder: (context, constraints) {
                  final isSmallScreen = constraints.maxWidth < 900;

                  if (isSmallScreen) {
                    return GridView.count(
                      crossAxisCount: 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      childAspectRatio: 2.8,
                      children: [
                        _statCard(
                          title: 'Total Tourists',
                          value: tourists.length.toString(),
                          icon: Icons.people,
                        ),
                        _statCard(
                          title: 'Active',
                          value: activeCount.toString(),
                          icon: Icons.check_circle,
                        ),
                        _statCard(
                          title: 'Suspended',
                          value: suspendedCount.toString(),
                          icon: Icons.block,
                        ),
                        _statCard(
                          title: 'Pending',
                          value: pendingCount.toString(),
                          icon: Icons.pending,
                        ),
                      ],
                    );
                  }

                  return Row(
                    children: [
                      Expanded(
                        child: _statCard(
                          title: 'Total Tourists',
                          value: tourists.length.toString(),
                          icon: Icons.people,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _statCard(
                          title: 'Active',
                          value: activeCount.toString(),
                          icon: Icons.check_circle,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _statCard(
                          title: 'Suspended',
                          value: suspendedCount.toString(),
                          icon: Icons.block,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _statCard(
                          title: 'Pending',
                          value: pendingCount.toString(),
                          icon: Icons.pending,
                        ),
                      ),
                    ],
                  );
                },
              ),

              const SizedBox(height: 24),

              // SEARCH
              TextField(
                decoration: InputDecoration(
                  hintText: 'Search by name, email or phone...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onChanged: (value) {
                  setState(() {
                    searchText = value;
                  });
                },
              ),

              const SizedBox(height: 24),

              // TOURIST LIST
              if (filteredTourists.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: Text(
                      'No tourists found.',
                      style: TextStyle(fontSize: 18),
                    ),
                  ),
                )
              else
                ...filteredTourists.map((doc) {
                  final data =
                      doc.data() as Map<String, dynamic>;

                  final userId = doc.id;

                  final name =
                      data['name'] ?? 'Unknown Tourist';

                  final email =
                      data['email'] ?? 'No email';

                  final phone =
                      data['phone'] ?? 'N/A';

                  final nationality =
                      data['nationality'] ?? 'N/A';

                  final bloodGroup =
                      data['bloodGroup'] ?? 'N/A';

                  final status =
                    (data['accountStatus'] ?? 'active')
                        .toString()
                        .toLowerCase();

                  final approvalStatus =
                      (data['approvalStatus'] ?? '')
                          .toString()
                          .toLowerCase();

                  return Card(
                    margin:
                        const EdgeInsets.only(bottom: 14),
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(14),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Row(
                        children: [
                          // PROFILE ICON
                          CircleAvatar(
                            radius: 28,
                            child: Text(
                              name
                                      .toString()
                                      .isNotEmpty
                                  ? name
                                      .toString()[0]
                                      .toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),

                          const SizedBox(width: 18),

                          // TOURIST INFO
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name.toString(),
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight:
                                        FontWeight.bold,
                                  ),
                                ),

                                const SizedBox(height: 6),

                                Text(
                                  email.toString(),
                                  style: TextStyle(
                                    color:
                                        Colors.grey.shade700,
                                  ),
                                ),

                                const SizedBox(height: 4),

                                Text(
                                  'Phone: $phone',
                                  style: TextStyle(
                                    color:
                                        Colors.grey.shade700,
                                  ),
                                ),

                                const SizedBox(height: 4),

                                Text(
                                  'Nationality: $nationality',
                                  style: TextStyle(
                                    color:
                                        Colors.grey.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // STATUS + ACTIONS
                          Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.end,
                            children: [
                              // STATUS
                              Container(
                                padding:
                                    const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      status == 'suspended'
                                          ? Colors.red.shade100
                                          : status == 'active'
                                              ? Colors.green.shade100
                                              : Colors.orange.shade100,
                                  borderRadius:
                                      BorderRadius.circular(20),
                                ),
                                child: Text(
                                  status.toUpperCase(),
                                  style: TextStyle(
                                    color:
                                        status == 'suspended'
                                            ? Colors.red.shade800
                                            : status == 'active'
                                                ? Colors.green.shade800
                                                : Colors.orange.shade800,
                                    fontWeight:
                                        FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),

                              const SizedBox(height: 8),

                              Text(
                                'Blood: $bloodGroup',
                                style: const TextStyle(
                                  color: Colors.blue,
                                ),
                              ),

                              const SizedBox(height: 10),

                              // VIEW DETAILS
                              ElevatedButton(
                                onPressed: () {
                                  _showTouristDetails(
                                    context,
                                    data,
                                  );
                                },
                                child:
                                    const Text('View Details'),
                              ),

                              const SizedBox(height: 8),

                              // ADMIN ACTIONS
                              if (approvalStatus == 'pending')
                                ElevatedButton.icon(
                                  onPressed: () {
                                    _confirmAction(
                                      title: 'Approve Tourist?',
                                      message:
                                          'Are you sure you want to approve $name?',
                                      onConfirm: () {
                                        _activateTourist(
                                          userId,
                                        );
                                      },
                                    );
                                  },
                                  icon:
                                      const Icon(Icons.check),
                                  label:
                                      const Text('Approve'),
                                )
                              else if (status == 'active')
                                ElevatedButton.icon(
                                  style:
                                      ElevatedButton.styleFrom(
                                    backgroundColor:
                                        Colors.red,
                                    foregroundColor:
                                        Colors.white,
                                  ),
                                  onPressed: () {
                                    _confirmAction(
                                      title: 'Suspend Tourist?',
                                      message:
                                          'Are you sure you want to suspend $name?',
                                      onConfirm: () {
                                        _suspendTourist(
                                          userId,
                                        );
                                      },
                                    );
                                  },
                                  icon:
                                      const Icon(Icons.block),
                                  label:
                                      const Text('Suspend'),
                                )
                              else if (status == 'suspended')
                                ElevatedButton.icon(
                                  style:
                                      ElevatedButton.styleFrom(
                                    backgroundColor:
                                        Colors.green,
                                    foregroundColor:
                                        Colors.white,
                                  ),
                                  onPressed: () {
                                    _confirmAction(
                                      title: 'Activate Tourist?',
                                      message:
                                          'Are you sure you want to activate $name?',
                                      onConfirm: () {
                                        _activateTourist(
                                          userId,
                                        );
                                      },
                                    );
                                  },
                                  icon:
                                      const Icon(
                                    Icons.check_circle,
                                  ),
                                  label:
                                      const Text('Activate'),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }),
            ],
          ),
        );
      },
    );
  }

  // STAT CARD
  Widget _statCard({
    required String title,
    required String value,
    required IconData icon,
  }) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 25,
              child: Icon(icon),
            ),

            const SizedBox(width: 12),

            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 14,
                    ),
                  ),

                  const SizedBox(height: 5),

                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // TOURIST DETAILS
  void _showTouristDetails(
    BuildContext context,
    Map<String, dynamic> data,
  ) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            data['name'] ?? 'Tourist Details',
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                _detailRow(
                  'Email',
                  data['email'],
                ),
                _detailRow(
                  'Phone',
                  data['phone'],
                ),
                _detailRow(
                  'Nationality',
                  data['nationality'],
                ),
                _detailRow(
                  'Blood Group',
                  data['bloodGroup'],
                ),
                _detailRow(
                  'Status',
                  data['accountStatus'] ?? 'active',
                ),
                _detailRow(
                  'Approval',
                  data['approvalStatus'] ?? 'N/A',
                ),
                _detailRow(
                  'Role',
                  data['role'],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Widget _detailRow(
    String title,
    dynamic value,
  ) {
    return Padding(
      padding:
          const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              '$title:',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value?.toString() ?? 'N/A',
            ),
          ),
        ],
      ),
    );
  }
}