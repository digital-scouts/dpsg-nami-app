import 'package:flutter/material.dart';

class MitgliederPage extends StatelessWidget {
  const MitgliederPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mitglieder'),
        automaticallyImplyLeading: false,
      ),
      body: const Center(
        child: Text(
          'Mitglieder',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
