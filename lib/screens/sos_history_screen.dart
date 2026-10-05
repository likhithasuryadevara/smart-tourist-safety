import 'package:flutter/material.dart';

import '../models/tourist_history_model.dart';
import 'tourist_safety_history_screen.dart';

class SosHistoryScreen extends StatelessWidget {
  const SosHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const TouristSafetyHistoryScreen(
      initialFilter: TouristHistoryFilter.sos,
    );
  }
}
