import 'package:flutter/material.dart';
import 'package:nami/utilities/nami/nami_rechte.dart';

class Profil extends StatefulWidget {
  const Profil({Key? key}) : super(key: key);

  @override
  State<Profil> createState() => _ProfilState();
}

class _ProfilState extends State<Profil> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Center(child: Text('Profil')),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text("Deine Rechte:", style: Theme.of(context).textTheme.titleMedium),
          Card(
            margin: EdgeInsets.zero,
            child: Column(
              children: [
                for (final feature in getAllowedFeatures())
                  ListTile(
                    title: Text(
                      feature.toReadableString(),
                    ),
                  )
              ],
            ),
          )
        ],
      ),
    );
  }
}
