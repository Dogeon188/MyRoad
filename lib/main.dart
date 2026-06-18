import 'package:flutter/material.dart';

void main() {
  runApp(const MyRoadApp());
}

class MyRoadApp extends StatelessWidget {
  const MyRoadApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MyRoad!!!!!',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const Scaffold(
        body: Center(child: Text('MyRoad!!!!!')),
      ),
    );
  }
}
