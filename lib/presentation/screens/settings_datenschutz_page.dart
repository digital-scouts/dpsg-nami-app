import 'package:flutter/material.dart';

class SettingsDatenschutzPage extends StatelessWidget {
  const SettingsDatenschutzPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Datenschutz')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          _LegalCard(
            title: 'Datenschutzerklaerung',
            body:
                'Lorem ipsum dolor sit amet, consectetur adipiscing elit. Integer feugiat, arcu vel suscipit tempus, neque nibh egestas erat, vitae tristique risus orci quis arcu.',
          ),
          SizedBox(height: 10),
          _LegalCard(
            title: 'Erhobene Daten',
            body:
                'At vero eos et accusamus et iusto odio dignissimos ducimus qui blanditiis praesentium voluptatum deleniti atque corrupti quos dolores et quas molestias excepturi sint occaecati cupiditate non provident.',
          ),
          SizedBox(height: 10),
          _LegalCard(
            title: 'Datenspeicherung und Loeschung',
            body:
                'Similique sunt in culpa qui officia deserunt mollitia animi, id est laborum et dolorum fuga. Et harum quidem rerum facilis est et expedita distinctio.',
          ),
          SizedBox(height: 10),
          _LegalCard(
            title: 'Ihre Rechte',
            body:
                'Nemo enim ipsam voluptatem quia voluptas sit aspernatur aut odit aut fugit. Neque porro quisquam est, qui dolorem ipsum quia dolor sit amet, consectetur, adipisci velit.',
          ),
        ],
      ),
    );
  }
}

class _LegalCard extends StatelessWidget {
  const _LegalCard({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(body),
          ],
        ),
      ),
    );
  }
}
