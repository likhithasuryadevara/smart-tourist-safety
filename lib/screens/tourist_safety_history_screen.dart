import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/tourist_history_model.dart';
import '../services/tourist_history_service.dart';
import 'sos_details_screen.dart';

class TouristSafetyHistoryScreen extends StatefulWidget {
  final TouristHistoryFilter initialFilter;

  const TouristSafetyHistoryScreen({
    super.key,
    this.initialFilter = TouristHistoryFilter.all,
  });

  @override
  State<TouristSafetyHistoryScreen> createState() =>
      _TouristSafetyHistoryScreenState();
}

class _TouristSafetyHistoryScreenState
    extends State<TouristSafetyHistoryScreen> {
  final TouristHistoryService _historyService = TouristHistoryService();

  String? _touristId;
  Stream<QuerySnapshot<Map<String, dynamic>>>? _sosStream;
  Stream<QuerySnapshot<Map<String, dynamic>>>? _notificationStream;
  late TouristHistoryFilter _selectedFilter;

  @override
  void initState() {
    super.initState();
    _selectedFilter = widget.initialFilter;
    _startStreams();
  }

  void _startStreams() {
    _touristId = FirebaseAuth.instance.currentUser?.uid;
    final touristId = _touristId;
    if (touristId == null) return;

    _sosStream = _historyService.watchSosHistory(touristId);
    _notificationStream = _historyService.watchNotificationHistory(touristId);
  }

  void _retry() {
    setState(_startStreams);
  }

  @override
  Widget build(BuildContext context) {
    if (_touristId == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Safety History'),
          backgroundColor: Colors.teal,
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: Text('Please sign in again to view your history.'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Safety History'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _sosStream,
        builder: (context, sosSnapshot) {
          if (sosSnapshot.hasError) return _errorState();
          if (!sosSnapshot.hasData) return _loadingState();

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _notificationStream,
            builder: (context, notificationSnapshot) {
              if (notificationSnapshot.hasError) return _errorState();
              if (!notificationSnapshot.hasData) return _loadingState();

              final history = _historyService.combineHistory(
                sosDocuments: sosSnapshot.data!.docs,
                notificationDocuments: notificationSnapshot.data!.docs,
              );
              final filteredHistory = history
                  .where((event) => event.matches(_selectedFilter))
                  .toList();

              return Column(
                children: [
                  _buildFilters(),
                  Expanded(
                    child: filteredHistory.isEmpty
                        ? _emptyState(history.isEmpty)
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                            itemCount: filteredHistory.length,
                            itemBuilder: (context, index) =>
                                _historyCard(filteredHistory[index]),
                          ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildFilters() {
    return SizedBox(
      height: 62,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        children: TouristHistoryFilter.values.map((filter) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: ChoiceChip(
              label: Text(_filterLabel(filter)),
              selected: _selectedFilter == filter,
              selectedColor: Colors.teal.shade100,
              onSelected: (_) {
                setState(() {
                  _selectedFilter = filter;
                });
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _historyCard(TouristHistoryEvent event) {
    final location = event.latitude != null && event.longitude != null
        ? '${event.latitude!.toStringAsFixed(6)}, '
              '${event.longitude!.toStringAsFixed(6)}'
        : 'Location unavailable';
    final timestamp = event.occurredAt?.toLocal();
    final dateText = timestamp == null
        ? 'Date unavailable'
        : '${timestamp.day.toString().padLeft(2, '0')}/'
              '${timestamp.month.toString().padLeft(2, '0')}/'
              '${timestamp.year}';
    final timeText = timestamp == null
        ? 'Time unavailable'
        : '${timestamp.hour.toString().padLeft(2, '0')}:'
              '${timestamp.minute.toString().padLeft(2, '0')}';

    final card = Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(
                      _eventIcon(event.type),
                      color: _eventColor(event.type),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        event.title,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: _statusBadge(event.status),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text('Event type: ${event.typeLabel}'),
            const SizedBox(height: 6),
            Text('Date: $dateText'),
            const SizedBox(height: 6),
            Text('Time: $timeText'),
            const SizedBox(height: 8),
            const Text(
              'Location',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            Text(location),
            if (event.description != null &&
                event.type != TouristHistoryType.sos) ...[
              const SizedBox(height: 8),
              Text(event.description!),
            ],
          ],
        ),
      ),
    );

    if (event.sosData == null) return card;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => SosDetailsScreen(sosData: event.sosData!),
          ),
        );
      },
      child: card,
    );
  }

  Widget _statusBadge(String status) {
    final normalized = status.toLowerCase();
    final color = switch (normalized) {
      'active' => Colors.red,
      'acknowledged' => Colors.orange,
      'resolved' || 'entered' => Colors.green,
      'exited' => Colors.blue,
      _ => Colors.grey,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _loadingState() {
    return const Center(child: CircularProgressIndicator());
  }

  Widget _errorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 54, color: Colors.grey),
            const SizedBox(height: 12),
            const Text(
              'Unable to load safety history. Check your connection and try again.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _retry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyState(bool noHistoryAtAll) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.history, size: 70, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              noHistoryAtAll
                  ? 'No Safety History'
                  : 'No ${_filterLabel(_selectedFilter)} History',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Your safety events will appear here.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  static String _filterLabel(TouristHistoryFilter filter) {
    switch (filter) {
      case TouristHistoryFilter.all:
        return 'All';
      case TouristHistoryFilter.sos:
        return 'SOS';
      case TouristHistoryFilter.safeZone:
        return 'Safe Zone';
      case TouristHistoryFilter.dangerZone:
        return 'Danger Zone';
      case TouristHistoryFilter.geofence:
        return 'Geofence';
      case TouristHistoryFilter.emergency:
        return 'Emergency';
    }
  }

  static IconData _eventIcon(TouristHistoryType type) {
    switch (type) {
      case TouristHistoryType.sos:
        return Icons.sos;
      case TouristHistoryType.safeZone:
        return Icons.shield_outlined;
      case TouristHistoryType.dangerZone:
        return Icons.warning_amber_rounded;
    }
  }

  static Color _eventColor(TouristHistoryType type) {
    switch (type) {
      case TouristHistoryType.sos:
        return Colors.red;
      case TouristHistoryType.safeZone:
        return Colors.teal;
      case TouristHistoryType.dangerZone:
        return Colors.deepOrange;
    }
  }
}
