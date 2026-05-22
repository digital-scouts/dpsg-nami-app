import 'package:flutter/material.dart';

class SettingsStufenwechselPage extends StatelessWidget {
  const SettingsStufenwechselPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Stufenwechsel')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Stufenwechsel (Dummy)',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Diese Seite bildet den vorgesehenen Stufenwechsel-Bereich visuell ab. Eine fachliche Anbindung ist in dieser Phase noch nicht aktiv.',
                  ),
                  const SizedBox(height: 12),
                  const _CandidateRow(
                    name: 'Emma Mueller',
                    stage: 'Woelflinge -> Jungpfadfinder',
                  ),
                  const Divider(height: 20),
                  const _CandidateRow(
                    name: 'Max Neumann',
                    stage: 'Pfadfinder -> Rover',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: null,
              icon: const Icon(Icons.swap_horiz),
              label: const Text('Stufenwechsel folgt in Phase 2'),
            ),
          ),
        ],
      ),
    );
  }
}

class _CandidateRow extends StatelessWidget {
  const _CandidateRow({required this.name, required this.stage});

  final String name;
  final String stage;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.person_outline),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: Theme.of(context).textTheme.titleSmall),
              Text(stage, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ],
    );
  }
}
