import 'package:flutter/material.dart';

class NamiAiPaywallPage extends StatelessWidget {
  const NamiAiPaywallPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('NaMi AI Premium')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'NaMi AI ist aktuell nur mit Premium-Mitgliedschaft verfügbar.',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              const Text(
                'Die monatliche Freischaltung wird später über Apple umgesetzt. '
                'Dieser Screen ist aktuell ein Platzhalter für den ersten UI-Einbau.',
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: null,
                  child: const Text('Premium-Freischaltung folgt'),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  child: const Text('Zurück'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
