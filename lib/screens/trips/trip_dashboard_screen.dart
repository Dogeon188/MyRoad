import 'package:flutter/material.dart';

class TripDashboardScreen extends StatelessWidget {
  final String tripId;

  const TripDashboardScreen({super.key, required this.tripId});

  @override
  Widget build(BuildContext context) {
    // ponytail: stub — stages UI comes in plan 2b
    return Scaffold(
      appBar: AppBar(title: const Text('Trip Dashboard')),
      body: const Center(child: Text('Trip stages coming in Plan 2B')),
    );
  }
}
