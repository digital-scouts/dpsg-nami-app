import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:nami/hive/mitglied.dart';

class MitgliedsListe extends StatefulWidget {
  const MitgliedsListe({Key? key}) : super(key: key);

  @override
  _MitgliedsListeState createState() => _MitgliedsListeState();
}

class _MitgliedsListeState extends State<MitgliedsListe> {
  @override
  Widget build(BuildContext context) {
    var box = Hive.box<Mitglied>('members');
    List<Mitglied> mitglieder = box.values.toList().cast<Mitglied>();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Mitglieder"),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: mitglieder.length,
        itemBuilder: (context, index) {
          return GestureDetector(
            onTap: () => print(
                'clicked on ${mitglieder[index].mitgliedsNummer.toString()}'),
            child: Card(
              child: ListTile(
                title: Text(
                    '${mitglieder[index].vorname} ${mitglieder[index].nachname}'),
                subtitle: Text(mitglieder[index].mitgliedsNummer.toString()),
              ),
            ),
          );
        },
      ),
    );
  }
}
