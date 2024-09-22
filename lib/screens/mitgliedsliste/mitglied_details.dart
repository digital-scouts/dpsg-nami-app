import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:nami/screens/widgets/map.widget.dart';
import 'package:nami/screens/widgets/mitgliedStufenPieChart.widget.dart';
import 'package:nami/utilities/helper_functions.dart';
import 'package:nami/utilities/hive/settings.dart';
import 'package:nami/utilities/hive/settings_stufenwechsel.dart';
import 'package:nami/utilities/logger.dart';
import 'package:nami/utilities/nami/nami_edit_taetigkeiten.dart';
import 'package:nami/utilities/nami/nami_rechte.dart';
import 'package:nami/utilities/stufe.dart';
import 'package:nami/utilities/hive/mitglied.dart';
import 'package:nami/utilities/hive/taetigkeit.dart';
import 'package:maps_launcher/maps_launcher.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:intl/intl.dart';
import 'package:nami/utilities/types.dart';
import 'package:wiredash/wiredash.dart';

// ignore: must_be_immutable
class MitgliedDetail extends StatefulWidget {
  Mitglied mitglied;
  MitgliedDetail({required this.mitglied, super.key});

  @override
  MitgliedDetailState createState() => MitgliedDetailState();
}

class MitgliedDetailState extends State<MitgliedDetail>
    with SingleTickerProviderStateMixin {
  bool showMoreTaetigkeiten = false;
  bool loadingStufenwechsel = false;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController =
        TabController(length: showAusbildungen ? 3 : 2, vsync: this);
  }

  bool get showAusbildungen => widget.mitglied.ausbildungen.isNotEmpty;

  Widget _buildBox(Widget child) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 5.0),
      child: child,
    );
  }

  Widget _buildMitgliedschaftPieChartForTopRow() {
    // filter taetigkeiten to only include Stufen Taetigkeiten
    // count years per stufe by subtracting aktivVon from aktivBis or now
    Map<String, int> tageProStufe = {};
    List<String> stufen = Stufe.values.map((stufe) => stufe.display).toList();
    int tageAlsMitglied = 0;
    int tageAlsLeiter = 0;
    for (var taetigkeit in widget.mitglied.taetigkeiten) {
      if (taetigkeit.untergliederung != null &&
          stufen.contains(taetigkeit.untergliederung) &&
          (taetigkeit.taetigkeit.contains('Leiter') ||
              taetigkeit.taetigkeit.contains('Mitglied'))) {
        String stufe = taetigkeit.taetigkeit.contains('Leiter')
            ? 'LeiterIn - ${taetigkeit.untergliederung}'
            : 'Mitglied - ${taetigkeit.untergliederung}';
        int sum = tageProStufe[stufe] ?? 0;

        // TODO upgrade: show Mietglieds und Leitungszeit pro Stufe wenn Leitungszeit Mitgliedszeit übersteit
        int activeDays = (taetigkeit.isActive()
            ? DateTime.now().difference(taetigkeit.aktivVon).inDays
            : taetigkeit.isFutureTaetigkeit()
                ? 0
                : taetigkeit.aktivBis!.difference(taetigkeit.aktivVon).inDays);
        tageProStufe[stufe] = sum + activeDays;
        if (taetigkeit.taetigkeit.contains('Leiter')) {
          tageAlsLeiter += activeDays;
        } else {
          tageAlsMitglied += activeDays;
        }
      }
    }

    tageProStufe.removeWhere((key, value) => value < 1);

    String dauerText = '';
    int pfadfinderTage =
        DateTime.now().difference(widget.mitglied.eintrittsdatum).inDays;
    if (pfadfinderTage >= 365) {
      int jahre = (pfadfinderTage / 365).floor();
      dauerText = jahre > 1 ? '$jahre Pfadfinderjahre' : 'Ein Pfadfinderjahr';
    } else if (pfadfinderTage >= 30) {
      int monate = (pfadfinderTage / 30).floor();
      dauerText =
          'Seit ${monate > 1 ? '$monate Monaten' : 'einem Monat'} Pfadfinder';
    } else {
      dauerText = 'Seit $pfadfinderTage Tagen dabei.';
    }

    return Expanded(
        child: SizedBox(
      child: Column(
        children: [
          if (tageProStufe.length > 1)
            MitgliedStufenPieChart(
                memberPerGroup: tageProStufe,
                showLeiterGrafik: tageAlsLeiter >= tageAlsMitglied),
          const SizedBox(height: 5),
          Text(dauerText),
          const SizedBox(height: 5),
        ],
      ),
    ));
  }

  Widget _buildStufenwechselInfoForTopRow() {
    DateTime currentDate = DateTime.now();
    Stufe? nextStufe = widget.mitglied.nextStufe;
    DateTime? minStufenWechselDatum =
        widget.mitglied.getMinStufenWechselDatum();
    DateTime? maxStufenWechselDatum =
        widget.mitglied.getMaxStufenWechselDatum();
    bool isMinStufenWechselJahrInPast = minStufenWechselDatum != null &&
        minStufenWechselDatum.isBefore(currentDate);
    Taetigkeit taetigkeit;
    try {
      taetigkeit = widget.mitglied.taetigkeiten.firstWhere(
          (element) => element.untergliederung == widget.mitglied.stufe);
    } catch (e) {
      return Container();
    }

    int currentStufeYears = currentDate.year - taetigkeit.aktivVon.year;
    int currentStufeMonths = currentDate.month - taetigkeit.aktivVon.month;

    if (currentDate.day < taetigkeit.aktivVon.day) {
      currentStufeMonths--;
    }

    if (currentStufeMonths < 0) {
      currentStufeYears--;
      currentStufeMonths += 12;
    }

    return Expanded(
        child: SizedBox(
            child: Column(
      children: [
        Text(
            'In der Stufe seit ${currentStufeYears > 1 ? '$currentStufeYears Jahren' : 'einem Jahr'}${currentStufeMonths != 0 ? ' und $currentStufeMonths Monaten' : ''}.'),
        nextStufe?.display == 'Leiter' && maxStufenWechselDatum != null
            ? Text('Stufenzeit endet ${maxStufenWechselDatum.year}')
            : (maxStufenWechselDatum != null && minStufenWechselDatum != null
                ? Text(
                    'Stufenwechsel ${isMinStufenWechselJahrInPast ? 'spätestens' : 'frühestens'} ${isMinStufenWechselJahrInPast ? maxStufenWechselDatum.year : minStufenWechselDatum.year}')
                : const Text('')),
      ],
    )));
  }

  Widget _buildStatistikTopRow() {
    return Container(
        color: Stufe.getStufeByString(widget.mitglied.stufe).farbe,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildMitgliedschaftPieChartForTopRow(),
            _buildStufenwechselInfoForTopRow()
          ],
        ));
  }

  Widget _buildLinkText(String scheme, String path) {
    return RichText(
      textAlign: TextAlign.left,
      text: TextSpan(
        text: path,
        style: Theme.of(context)
            .textTheme
            .titleMedium!
            .copyWith(color: Colors.blue),
        recognizer: TapGestureRecognizer()
          ..onTap = () async {
            final Uri params = Uri(
              scheme: scheme,
              path: path,
            );

            var url = params.toString();
            // dies Funktioniert, wenn die notwendige app installiert ist
            if (await canLaunchUrlString(url)) {
              await launchUrlString(url);
            }
          },
      ),
    );
  }

  Widget _buildMapText(String address) {
    return RichText(
      textAlign: TextAlign.left,
      text: TextSpan(
        text: address,
        style: Theme.of(context)
            .textTheme
            .titleMedium!
            .copyWith(color: Colors.blue),
        recognizer: TapGestureRecognizer()
          ..onTap = () {
            MapsLauncher.launchQuery(address);
          },
      ),
    );
  }

  Widget _buildAddress() {
    String memberAddress =
        '${widget.mitglied.strasse}, ${widget.mitglied.plz} ${widget.mitglied.ort}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Anschrift",
          style: Theme.of(context).textTheme.titleMedium,
        ),
        _buildBox(
          Column(
            children: [
              ListTile(
                leading: const Icon(Icons.home),
                title: _buildMapText(memberAddress),
              ),
              MapWidget(members: [widget.mitglied]),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGeneralInfos() {
    final mitglied = widget.mitglied;
    final int age = mitglied.getAlterAm();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Allgemeine Informationen",
          style: Theme.of(context).textTheme.titleMedium,
        ),
        _buildBox(
          Column(
            children: [
              ListTile(
                leading: const Icon(Icons.event),
                subtitle: const Text('Alter'),
                title: Text(
                    "$age (${widget.mitglied.geburtsDatum.prettyPrint()})"),
              ),
              if (mitglied.email.isNotNullOrEmpty)
                ListTile(
                  leading: const Icon(Icons.email),
                  subtitle: const Text('E-Mail'),
                  title: _buildLinkText("mailto", mitglied.email!),
                ),
              if (mitglied.emailVertretungsberechtigter.isNotNullOrEmpty)
                ListTile(
                  leading: const Icon(Icons.email),
                  subtitle: const Text('E-Mail Vertretungsberechtigter'),
                  title: _buildLinkText(
                    "mailto",
                    mitglied.emailVertretungsberechtigter!,
                  ),
                ),
              if (mitglied.telefon1.isNotNullOrEmpty)
                ListTile(
                  leading: const Icon(Icons.call),
                  subtitle: const Text('Festnetznummer'),
                  title: _buildLinkText("tel", mitglied.telefon1!),
                ),
              if (mitglied.telefon2.isNotNullOrEmpty)
                ListTile(
                  leading: const Icon(Icons.call),
                  subtitle: const Text('Mobilfunknummer'),
                  title: _buildLinkText("tel", mitglied.telefon2!),
                ),
              if (mitglied.telefon3.isNotNullOrEmpty)
                ListTile(
                  leading: const Icon(Icons.call),
                  subtitle: const Text('Geschäftlich'),
                  title: _buildLinkText("tel", mitglied.telefon3!),
                ),
              ListTile(
                leading: const Icon(Icons.tag),
                subtitle: const Text('NaMi Mitgliedsnummer'),
                title: Text(mitglied.mitgliedsNummer.toString()),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTaetigkeitImage(Taetigkeit taetigkeit) {
    String imagePath = 'assets/images/lilie_schwarz.png';
    if (taetigkeit.taetigkeit.trim() == 'Mitglied') {
      imagePath =
          Stufe.getStufeByString(taetigkeit.untergliederung!).imagePath!;
    } else if (taetigkeit.taetigkeit.contains('LeiterIn')) {
      return Image.asset(
        imagePath,
        width: 80.0,
        height: 80.0,
        color: Stufe.getStufeByString(taetigkeit.untergliederung!).farbe,
        colorBlendMode: BlendMode.srcIn,
        cacheWidth: 80,
      );
    }

    return Image.asset(
      imagePath,
      width: 80.0,
      height: 80.0,
      cacheHeight: 80,
    );
  }

  Widget _buildTaetigkeitenItem(Taetigkeit taetigkeit) {
    return _buildBox(
      ListTile(
        leading: _buildTaetigkeitImage(taetigkeit),
        title: Text(
          '${taetigkeit.taetigkeit} ${taetigkeit.untergliederung!.isNotEmpty ? '- ${taetigkeit.untergliederung}' : ''} ',
        ),
        subtitle: Text(
          '${DateFormat('MMMM').format(taetigkeit.aktivVon)} ${taetigkeit.aktivVon.year} ${taetigkeit.aktivBis != null ? '- ${DateFormat('MMMM').format(taetigkeit.aktivBis!)} ${taetigkeit.aktivBis!.year}' : ''} ${getGruppierungName() != taetigkeit.gruppierung ? '\nGruppierung: ${taetigkeit.gruppierung}' : ''}',
        ),
      ),
    );
  }

  handleStufenwechsel(int memberId, Taetigkeit currentTaetigkeit, Stufe stufe,
      DateTime aktivVon) async {
    Wiredash.trackEvent('Stufenwechsel starting',
        data: {'type': 'memberdetails'});
    if (await showConfirmationDialog(
        context,
        aktivVon,
        stufe,
        '${widget.mitglied.vorname} ${widget.mitglied.nachname}',
        currentTaetigkeit)) {
      setState(() => loadingStufenwechsel = true);
      Mitglied? mitglied;
      try {
        mitglied = await stufenwechsel(
            widget.mitglied.id!, currentTaetigkeit, stufe, aktivVon);
      } catch (e, st) {
        sensLog.e('failed to stufenwechsel', error: e, stackTrace: st);
      }

      setState(() {
        loadingStufenwechsel = false;
        widget.mitglied = mitglied ?? widget.mitglied;
      });
    }
  }

  Widget _buildStufenwechselItem(
      Taetigkeit fakeStufenwechselTaetigkeit, Taetigkeit currentTaetigkeit) {
    Stufe stufe =
        Stufe.getStufeByString(fakeStufenwechselTaetigkeit.untergliederung!);
    return _buildBox(
      ListTile(
        leading: loadingStufenwechsel
            ? const CircularProgressIndicator()
            : _buildTaetigkeitImage(fakeStufenwechselTaetigkeit),
        title: Text(
          '${fakeStufenwechselTaetigkeit.untergliederung}',
        ),
        subtitle: Text(
            "Ab: ${DateFormat('dd. MMMM yyyy').format(fakeStufenwechselTaetigkeit.aktivVon)}"),
        trailing: TextButton(
          onPressed: loadingStufenwechsel
              ? null
              : () => handleStufenwechsel(
                  widget.mitglied.id!,
                  currentTaetigkeit,
                  stufe,
                  fakeStufenwechselTaetigkeit.aktivVon),
          child: const Text("Wechseln"),
        ),
      ),
    );
  }

  Future<bool> showConfirmationDialog(
      BuildContext context,
      DateTime stufenwechselDate,
      Stufe stufeAfterWechsel,
      String mitgliedName,
      Taetigkeit currentTaetigkeit) async {
    Completer<bool> completer = Completer<bool>();

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Stufenwechsel'),
          content: Text(
              'Soll $mitgliedName am ${DateFormat('dd. MMMM yyyy').format(stufenwechselDate)} wirklich zu den ${stufeAfterWechsel.display} wechseln?\n\nDie aktuelle Tätigkeit (${currentTaetigkeit.untergliederung}) wird beendet.'),
          actions: <Widget>[
            TextButton(
              child: const Text('Abbrechen'),
              onPressed: () {
                completer.complete(false);
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Änderung vornehmen'),
              onPressed: () {
                completer.complete(true);
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );

    return completer.future;
  }

  Taetigkeit? getCurrenttaetigkeit(List<Taetigkeit> aktiveTaetigkeiten) {
    List<Taetigkeit> taetigkeiten = aktiveTaetigkeiten
        .where((taetigkeit) => taetigkeit.taetigkeit.trim() == 'Mitglied')
        .toList();
    return taetigkeiten.length == 1 ? taetigkeiten.first : null;
  }

  Taetigkeit? getStufenwechselTaetigkeit() {
    DateTime nextStufenwechselDatum = getNextStufenwechselDatum();
    DateTime? minStufenWechselJahr = widget.mitglied.getMinStufenWechselDatum();
    bool isMinStufenWechselJahrInPast = minStufenWechselJahr != null &&
        minStufenWechselJahr.isBefore(nextStufenwechselDatum);
    Stufe? nextStufe = widget.mitglied.nextStufe;

    // check if stufenwechsel is possible
    if (!isMinStufenWechselJahrInPast ||
        nextStufe == null ||
        !nextStufe.isStufeYouCanChangeTo ||
        !getNamiChangesEnabled() ||
        !getAllowedFeatures().contains(AllowedFeatures.stufenwechsel)) {
      return null;
    }

    Taetigkeit? stufenwechselTaetigkeit = Taetigkeit();
    stufenwechselTaetigkeit.aktivVon = nextStufenwechselDatum;
    stufenwechselTaetigkeit.taetigkeit = 'Mitglied';
    stufenwechselTaetigkeit.untergliederung =
        widget.mitglied.nextStufe?.display;
    return stufenwechselTaetigkeit;
  }

  @override
  Widget build(BuildContext context) {
    List<Taetigkeit> aktiveTaetigkeiten =
        widget.mitglied.getActiveTaetigkeiten();
    aktiveTaetigkeiten.sort((a, b) => b.aktivVon.compareTo(a.aktivVon));
    List<Taetigkeit> vergangeneTaetigkeiten =
        widget.mitglied.getAlteTaetigkeiten();
    vergangeneTaetigkeiten.sort((a, b) => b.aktivVon.compareTo(a.aktivVon));
    bool isFavorite =
        getFavouriteList().contains(widget.mitglied.mitgliedsNummer);
    Taetigkeit? fakeStufenwechselTaetigkeit = getStufenwechselTaetigkeit();
    Taetigkeit? currentTaetigkeit = getCurrenttaetigkeit(aktiveTaetigkeiten);
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () =>
            openWiredash(context, 'Feedback Button Mitglied Details'),
        child: const Icon(Icons.feedback),
      ),
      appBar: AppBar(
        shadowColor: Colors.transparent,
        backgroundColor: Stufe.getStufeByString(widget.mitglied.stufe).farbe,
        title: Text("${widget.mitglied.vorname} ${widget.mitglied.nachname}"),
        actions: [
          IconButton(
              onPressed: () => {
                    Wiredash.trackEvent('Member Details toggle favourite',
                        data: {'type': isFavorite ? 'remove' : 'add'}),
                    isFavorite
                        ? removeFavouriteList(widget.mitglied.mitgliedsNummer)
                        : addFavouriteList(widget.mitglied.mitgliedsNummer),
                    setState(() {
                      isFavorite = !isFavorite;
                    })
                  },
              icon: isFavorite
                  ? const Icon(Icons.bookmark)
                  : const Icon(Icons.bookmark_border))
        ],
      ),
      body: Column(
        children: <Widget>[
          _buildStatistikTopRow(),
          TabBar(
            controller: _tabController,
            tabs: [
              const Tab(text: 'Basisdaten'),
              const Tab(text: 'Tätigkeiten'),
              if (showAusbildungen) const Tab(text: 'Ausbildungen')
            ],
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: TabBarView(
                controller: _tabController,
                children: [
                  ListView(
                    children: <Widget>[
                      _buildGeneralInfos(),
                      _buildAddress(),
                    ],
                  ),
                  ListView(
                    children: [
                      if (fakeStufenwechselTaetigkeit != null &&
                          currentTaetigkeit != null) ...[
                        Text(
                          'Zukünftige Tätigkeit',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        _buildStufenwechselItem(
                            fakeStufenwechselTaetigkeit, currentTaetigkeit),
                        const SizedBox(height: 10),
                      ],
                      if (aktiveTaetigkeiten.isNotEmpty)
                        Text(
                          'Aktive Tätigkeiten',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      for (final taetigkeit in aktiveTaetigkeiten)
                        _buildTaetigkeitenItem(taetigkeit),
                      const SizedBox(height: 10),
                      if (vergangeneTaetigkeiten.isNotEmpty)
                        Text(
                          'Abgeschlossene Tätigkeiten',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      for (final taetigkeit in vergangeneTaetigkeiten)
                        _buildTaetigkeitenItem(taetigkeit),
                    ],
                  ),
                  if (showAusbildungen)
                    ListView(
                      children: [
                        for (final ausbildung in widget.mitglied.ausbildungen)
                          _buildBox(
                            ListTile(
                              leading: const Icon(Icons.school),
                              title: Text(
                                  ausbildung.baustein.contains('Sonstiges')
                                      ? ausbildung.name
                                      : ausbildung.baustein),
                              isThreeLine: true,
                              subtitle: Text(
                                  '${ausbildung.baustein.contains('Sonstiges') ? '' : '${ausbildung.name}\n'}${DateFormat('dd. MMMM yyyy').format(ausbildung.datum)}${ausbildung.veranstalter.isEmpty ? '' : ' - ${ausbildung.veranstalter}'}'),
                            ),
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
