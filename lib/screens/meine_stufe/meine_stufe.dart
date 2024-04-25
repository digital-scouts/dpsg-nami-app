import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:nami/screens/mitgliedsliste/mitglied_details.dart';
import 'package:nami/screens/widgets/map.widget.dart';
import 'package:nami/screens/widgets/stufenwechsel_timeline.widget.dart';
import 'package:nami/utilities/hive/mitglied.dart';
import 'package:nami/utilities/hive/settings.dart';
import 'package:nami/utilities/stufe.dart';

class MeineStufe extends StatefulWidget {
  const MeineStufe({Key? key}) : super(key: key);

  @override
  State<MeineStufe> createState() => _MeineStufeState();
}

class _MeineStufeState extends State<MeineStufe> {
  late List<Mitglied> mitglieder;
  late Map<int, Color> elementColors = {};

  @override
  void initState() {
    loadMitglieder();
    super.initState();
  }

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

  Widget _buildMitgiedElement(Mitglied mitglied, Color color) {
    return Card(
      child: Container(
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: color, width: 5.0)),
        ),
        child: Stack(
          children: [
            Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${mitglied.vorname} ${mitglied.nachname}'),
                    Text(DateFormat('dd. MMMM yyyy')
                        .format(mitglied.geburtsDatum)),
                  ],
                )),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: mitglied.isMitgliedLeiter()
                  ? Container()
                  : TimelineWidget(
                      mitglied: mitglied,
                      currentStufe: Stufe.getStufeByString(mitglied.stufe),
                      nextStufenwechsel: getNextStufenwechselDatum(),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMitgliederList(
      List<Mitglied> mitglieder, Map<int, Color> elementColors) {
    return GridView.builder(
      padding: const EdgeInsets.all(10.0),
      itemCount: mitglieder.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: (MediaQuery.of(context).size.width > 600) ? 3 : 2,
        childAspectRatio: 5 / 2,
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
            .then((value) => setState(() => loadMitglieder())),
        child: _buildMitgiedElement(
            mitglieder[i], elementColors[mitglieder[i].mitgliedsNummer]!),
      ),
    );
  }

  final List<Color> colors = [
    // Dunkle Farbtöne, nicht mehr als 3 ähnliche Farben
    const Color(0xFF1A237E),
    const Color(0xFF004D40),
    const Color(0xFF880E4F),
    const Color(0xFF1B5E20),
    const Color(0xFF3E2723),
    const Color(0xFF311B92),
    const Color(0xFFBF360C),
    const Color(0xFF3F51B5),
    const Color(0xFF4CAF50),
    const Color(0xFFE91E63),
    const Color(0xFF795548),
    const Color(0xFF9C27B0),
    const Color(0xFFD84315),
  ];

  void loadMitglieder() {
    List<int> favouriteIds = getFavouriteList();
    mitglieder = Hive.box<Mitglied>('members')
        .values
        .where((element) => favouriteIds.contains(element.mitgliedsNummer))
        .toList()
        .cast<Mitglied>();

    int index = 0;
    for (var mitglied in mitglieder) {
      elementColors.putIfAbsent(
          mitglied.mitgliedsNummer, () => colors[index % colors.length]);
      index++;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Center(child: Text('Meine Stufe')),
      ),
      body: Column(
        children: [
          MapWidget(members: mitglieder, elementColors: elementColors),
          const Text(
            'Mitglieder',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          Expanded(
            child: mitglieder.isEmpty
                ? _buildNoElements()
                : _buildMitgliederList(mitglieder, elementColors),
          ),
        ],
      ),
    );
  }
}
