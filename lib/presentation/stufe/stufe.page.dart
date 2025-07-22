import 'package:flutter/material.dart';

class StufePage extends StatelessWidget {
  const StufePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Stufe'),
        automaticallyImplyLeading: false,
      ),
      body: const Center(
        child: Text(
          'Stufe',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
