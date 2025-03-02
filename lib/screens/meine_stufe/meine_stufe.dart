import 'package:flutter/material.dart';
import 'package:hive_ce/hive.dart';
import 'package:intl/intl.dart';
import 'package:nami/screens/mitgliedsliste/mitglied_details.dart';
import 'package:nami/screens/widgets/map.widget.dart';
import 'package:nami/screens/widgets/status_information_banner.dart';
import 'package:nami/screens/widgets/stufenwechsel_timeline.widget.dart';
import 'package:nami/utilities/hive/mitglied.dart';
import 'package:nami/utilities/hive/settings.dart';
import 'package:nami/utilities/hive/settings_stufenwechsel.dart';
import 'package:nami/utilities/hive/taetigkeit.dart';
import 'package:wiredash/wiredash.dart';

class MeineStufe extends StatefulWidget {
  const MeineStufe({super.key});

  @override
  State<MeineStufe> createState() => _MeineStufeState();
}

class _MeineStufeState extends State<MeineStufe> {
  late List<Mitglied> mitglieder;
  late Map<int, Color> elementColors = {};
  final List<Color> colors = [
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
                child: Icon(Icons.bookmark_border, size: 20),
              ),
              TextSpan(text: ' hinzu.'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMitgliedElement(Mitglied mitglied, Color color) {
    final DateTime currentDate = DateTime.now();
    Taetigkeit emptyTaetigkeit = Taetigkeit();

    final Taetigkeit taetigkeit = mitglied.taetigkeiten.firstWhere(
      (element) => element.untergliederung == mitglied.currentStufe.display,
      orElse: () {
        emptyTaetigkeit.aktivVon = emptyTaetigkeit.aktivBis = currentDate;
        return emptyTaetigkeit;
      },
    );
    final int currentStufeYears = currentDate.year - taetigkeit.aktivVon.year;
    final int currentStufeMonths =
        currentDate.month - taetigkeit.aktivVon.month;

    final double currentStufeYearsDecimal =
        currentStufeYears + currentStufeMonths / 12.0;

    return Card(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(5), bottomLeft: Radius.circular(5)),
          border: Border(left: BorderSide(color: color, width: 5.0)),
        ),
        child: Stack(
          children: [
            Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${mitglied.vorname} ${mitglied.nachname}',
                        overflow: TextOverflow.ellipsis),
                    Row(
                      children: [
                        const Icon(Icons.cake, size: 12),
                        const SizedBox(width: 5),
                        Text(DateFormat('dd. MMM yyyy')
                            .format(mitglied.geburtsDatum)),
                      ],
                    ),
                    mitglied.isMitgliedLeiter() || taetigkeit == emptyTaetigkeit
                        ? Container()
                        : Text(
                            '${currentStufeYearsDecimal % 1 == 0 ? currentStufeYearsDecimal.toInt() : currentStufeYearsDecimal.toStringAsFixed(1)} Jahre ${mitglied.currentStufe.shortDisplaySingular}')
                  ],
                )),
            Positioned(
              bottom: -2,
              left: 0,
              right: 0,
              child:
                  mitglied.isMitgliedLeiter() || taetigkeit == emptyTaetigkeit
                      ? Container()
                      : TimelineWidget(
                          mitglied: mitglied,
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
        childAspectRatio: 6 / 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemBuilder: (ctx, i) => InkWell(
        onTap: () {
          Wiredash.trackEvent('Show Member Details',
              data: {'type': 'meineStufe'});
          Navigator.of(context)
              .push(
                MaterialPageRoute(
                    builder: (context) =>
                        MitgliedDetail(mitglied: mitglieder[i])),
              )
              .then((value) => {
                    if (mitglieder.length != getFavouriteList().length)
                      setState(() => loadMitglieder())
                  });
        },
        child: _buildMitgliedElement(
            mitglieder[i], elementColors[mitglieder[i].mitgliedsNummer]!),
      ),
    );
  }

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
          mitglieder.isEmpty
              ? Container()
              : MapWidget(members: mitglieder, elementColors: elementColors),
          const StatusInformationBanner(),
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
