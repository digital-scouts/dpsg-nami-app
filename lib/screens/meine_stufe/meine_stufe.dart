import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:nami/screens/mitgliedsliste/mitglied_details.dart';
import 'package:nami/utilities/hive/mitglied.dart';
import 'package:nami/utilities/hive/settings.dart';

class MeineStufe extends StatefulWidget {
  const MeineStufe({Key? key}) : super(key: key);

  @override
  State<MeineStufe> createState() => _MeineStufeState();
}

class _MeineStufeState extends State<MeineStufe> {
  Widget _buildNoElements() {
    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.only(top: 100.0),
        child: RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            style: DefaultTextStyle.of(context).style,
            children: const [
              TextSpan(
                  text:
                      'Keine Mitglieder hinzugefügt. \nFüge Mitglieder in den Details \nüber '),
              WidgetSpan(
                child: Icon(Icons.star, size: 20),
              ),
              TextSpan(text: ' hinzu.'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMitgiedElement(Mitglied mitglied) {
    return Card(
      child: Column(
        children: <Widget>[
          Text('${mitglied.vorname} ${mitglied.nachname}'),
          Text(DateFormat('dd. MMMM yyyy').format(mitglied.geburtsDatum))
        ],
      ),
    );
  }

  Widget _buildMitgliederList(List<Mitglied> mitglieder) {
    return GridView.builder(
        padding: const EdgeInsets.all(10.0),
        itemCount: mitglieder.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: (MediaQuery.of(context).size.width > 600) ? 3 : 2,
          childAspectRatio: 3 / 2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
        ),
        itemBuilder: (ctx, i) => InkWell(
              onTap: () => Navigator.of(context)
                  .push(
                    MaterialPageRoute(
                        builder: (context) =>
                            MitgliedDetail(mitglied: mitglieder[i])),
                  )
                  .then((value) => setState(() {})),
              child: _buildMitgiedElement(mitglieder[i]),
            ));
  }

  @override
  Widget build(BuildContext context) {
    List<int> favouriteIds = getFavouriteList();
    List<Mitglied> mitglieder = Hive.box<Mitglied>('members')
        .values
        .where((element) => favouriteIds.contains(element.mitgliedsNummer))
        .toList()
        .cast<Mitglied>();

    return Scaffold(
      appBar: AppBar(
        title: const Center(child: Text('Meine Stufe')),
      ),
      body: mitglieder.isEmpty
          ? _buildNoElements()
          : _buildMitgliederList(mitglieder),
    );
  }
}
