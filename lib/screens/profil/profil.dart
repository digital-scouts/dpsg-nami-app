import 'package:flutter/material.dart';
import 'package:nami/screens/utilities/fuehrungszeugnis.widget.dart';
import 'package:nami/utilities/nami/nami_rechte.dart';

class Profil extends StatefulWidget {
  const Profil({super.key});

  @override
  State<Profil> createState() => _ProfilState();
}

class _ProfilState extends State<Profil> {
  _buildFeatureIcon(bool active, IconData icon, String tooltip) {
    return Tooltip(
      message: tooltip,
      child: Icon(
        icon,
        color: active ? Colors.green : Colors.grey,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final features = getAllowedFeatures();

    return Scaffold(
      appBar: AppBar(
        title: const Center(child: Text('Profil')),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text("Berechtigungen",
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Card(
            margin: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  title: const Text(
                    'Mitglieder',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildFeatureIcon(
                          features.contains(AllowedFeatures.appStart),
                          Icons.visibility,
                          'Mitglieder anzeigen'),
                      _buildFeatureIcon(
                          features.contains(AllowedFeatures.memberEdit),
                          Icons.edit,
                          'Mitglieder bearbeiten'),
                      _buildFeatureIcon(
                          features.contains(AllowedFeatures.memberCreate),
                          Icons.person_add_alt_1,
                          'Mitglieder hinzufügen'),
                      _buildFeatureIcon(
                          features.contains(AllowedFeatures.memberImport),
                          Icons.group_add,
                          'Mitglieder übernehmen'),
                      _buildFeatureIcon(
                          features.contains(AllowedFeatures.membershipEnd),
                          Icons.delete,
                          'Mitgliedschaft beenden'),
                    ],
                  ),
                ),
                ListTile(
                  title: const Text(
                    'Tätigkeiten',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildFeatureIcon(
                          features.contains(AllowedFeatures.appStart),
                          Icons.visibility,
                          'Tätigkeiten anzeigen'),
                      _buildFeatureIcon(
                          features.contains(AllowedFeatures.taetigkeitEdit),
                          Icons.edit,
                          'Tätigkeiten bearbeiten'),
                      _buildFeatureIcon(
                          features.contains(AllowedFeatures.taetigkeitCreate),
                          Icons.add_box,
                          'Tätigkeiten hinzufügen'),
                      _buildFeatureIcon(
                          features.contains(AllowedFeatures.taetigkeitDelete),
                          Icons.delete,
                          'Tätigkeiten löschen'),
                    ],
                  ),
                ),
                ListTile(
                  title: const Text(
                    'Ausbildung',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildFeatureIcon(
                          features.contains(AllowedFeatures.ausbildungRead),
                          Icons.visibility,
                          'Ausbidlungen anzeigen'),
                      _buildFeatureIcon(
                          features.contains(AllowedFeatures.ausbildungEdit),
                          Icons.edit,
                          'Ausbildungen bearbeiten'),
                      _buildFeatureIcon(
                          features.contains(AllowedFeatures.ausbildungCreate),
                          Icons.add_box,
                          'Ausbildungen hinzufügen'),
                      _buildFeatureIcon(
                          features.contains(AllowedFeatures.ausbildungDelete),
                          Icons.delete,
                          'Ausbildungen löschen'),
                    ],
                  ),
                ),
                ListTile(
                  title: const Text(
                    'Stufenwechsel',
                  ),
                  subtitle:
                      const Text('Bearbeiten und Erstellen von Tätigkeiten'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Tooltip(
                          message:
                              features.contains(AllowedFeatures.stufenwechsel)
                                  ? 'Stufenwechsel erlaubt'
                                  : 'Stufenwechsel nicht erlaubt',
                          child:
                              features.contains(AllowedFeatures.stufenwechsel)
                                  ? const Icon(Icons.check, color: Colors.green)
                                  : const Icon(Icons.close, color: Colors.red)),
                    ],
                  ),
                ),
                ListTile(
                  title: const Text(
                    'Führungszeugnis',
                  ),
                  subtitle: const Text('Laden von SGB VIII-Bescheinigungen'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Tooltip(
                          message: features
                                  .contains(AllowedFeatures.stufenwechsel)
                              ? 'Führungszeugnis kann angezeigt werden'
                              : 'Führungszeugnis kann nicht angezeigt werden',
                          child: features
                                  .contains(AllowedFeatures.fuehrungszeugnis)
                              ? const Icon(Icons.check, color: Colors.green)
                              : const Icon(Icons.close, color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (getAllowedFeatures().contains(AllowedFeatures.fuehrungszeugnis))
            const FuehrungszeugnisWidgets(),
        ],
      ),
    );
  }
}
