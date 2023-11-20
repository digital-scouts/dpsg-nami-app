import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:nami/screens/widgets/map.widget.dart';
import 'package:nami/screens/widgets/mitgliedStufenPieChart.widget.dart';
import 'package:nami/utilities/hive/settings.dart';
import 'package:nami/utilities/nami/nami_edit_taetigkeiten.dart';
import 'package:nami/utilities/stufe.dart';
import 'package:nami/utilities/hive/mitglied.dart';
import 'package:nami/utilities/hive/taetigkeit.dart';
import 'package:maps_launcher/maps_launcher.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:intl/intl.dart';

// ignore: must_be_immutable
class MitgliedDetail extends StatefulWidget {
  Mitglied mitglied;
  MitgliedDetail({required this.mitglied, Key? key}) : super(key: key);

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
    _tabController = TabController(length: 2, vsync: this);
  }

  Widget _buildBox(List<Widget> children) {
    return SizedBox(
      child: Card(
        color: Theme.of(context).colorScheme.surface,
        elevation: 2.0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
        child: IntrinsicHeight(
          child: Padding(
            padding: const EdgeInsets.all(5.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMitgliedschaftPieChartForTopRow() {
    // filter taetigkeiten to only include Stufen Taetigkeiten
    // count years per stufe by subtracting aktivVon from aktivBis or now
    Map<String, int> tageProStufe = {};
    List<String> stufen =
        Stufe.stufen.map((stufe) => stufe.name.value).toList();
    for (var taetigkeit in widget.mitglied.taetigkeiten) {
      if (taetigkeit.untergliederung != null &&
          stufen.contains(taetigkeit.untergliederung) &&
          (taetigkeit.taetigkeit.contains('Leiter') ||
              taetigkeit.taetigkeit.contains('Mitglied'))) {
        int sum = tageProStufe[taetigkeit.untergliederung!] ?? 0;
        String stufe = taetigkeit.taetigkeit.contains('Leiter')
            ? 'LeiterIn'
            : taetigkeit.untergliederung!;
        // todo upgrade: show Mietglieds und Leitungszeit pro Stufe wenn Leitungszeit Mitgliedszeit übersteit
        tageProStufe[stufe] = sum +
            (taetigkeit.isActive()
                ? DateTime.now().difference(taetigkeit.aktivVon).inDays ~/ 12
                : taetigkeit.isFutureTaetigkeit()
                    ? 0
                    : taetigkeit.aktivBis!
                            .difference(taetigkeit.aktivVon)
                            .inDays ~/
                        12);
      }
    }

    tageProStufe.removeWhere((key, value) => value == 0);

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
          MitgliedStufenPieChart(memberPerGroup: tageProStufe),
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
    int? minStufenWechselJahr = widget.mitglied.getMinStufenWechselJahr();
    int? maxStufenWechselJahr = widget.mitglied.getMaxStufenWechselJahr();
    bool isMinStufenWechselJahrInPast =
        minStufenWechselJahr != null && minStufenWechselJahr < currentDate.year;
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
        nextStufe?.name.value == 'Leiter' && maxStufenWechselJahr != null
            ? Text('Stufenzeit endet $maxStufenWechselJahr')
            : (maxStufenWechselJahr != null && minStufenWechselJahr != null
                ? Text(
                    'Stufenwechsel ${isMinStufenWechselJahrInPast ? 'spätestens' : 'frühestens'} ${isMinStufenWechselJahrInPast ? maxStufenWechselJahr : minStufenWechselJahr}')
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
        style: const TextStyle(color: Colors.blue, fontSize: 20),
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
        style: const TextStyle(color: Colors.blue, fontSize: 20),
        recognizer: TapGestureRecognizer()
          ..onTap = () {
            MapsLauncher.launchQuery(address);
          },
      ),
    );
  }

  Widget _buildMailList() {
    if (widget.mitglied.emailVertretungsberechtigter!.isNotEmpty ||
        widget.mitglied.email!.isNotEmpty ||
        widget.mitglied.telefon1!.isNotEmpty ||
        widget.mitglied.telefon2!.isNotEmpty ||
        widget.mitglied.telefon3!.isNotEmpty) {
      return _buildBox(<Widget>[
        if (widget.mitglied.email!.isNotEmpty)
          const Text("E-Mail",
              style: TextStyle(color: Colors.white, fontSize: 20)),
        if (widget.mitglied.email!.isNotEmpty)
          _buildLinkText('mailto', widget.mitglied.email!),
        if (widget.mitglied.emailVertretungsberechtigter!.isNotEmpty)
          const Text("E-Mail Vertretungsberechtigte:r",
              style: TextStyle(color: Colors.white, fontSize: 20)),
        if (widget.mitglied.emailVertretungsberechtigter!.isNotEmpty)
          _buildLinkText(
              'mailto', widget.mitglied.emailVertretungsberechtigter!),
        if (widget.mitglied.telefon1!.isNotEmpty)
          const Text("Telefon",
              style: TextStyle(color: Colors.white, fontSize: 20)),
        if (widget.mitglied.telefon1!.isNotEmpty)
          _buildLinkText('tel', widget.mitglied.telefon1!),
        if (widget.mitglied.telefon2!.isNotEmpty)
          const Text("Telefon",
              style: TextStyle(color: Colors.white, fontSize: 20)),
        if (widget.mitglied.telefon2!.isNotEmpty)
          _buildLinkText('tel', widget.mitglied.telefon2!),
        if (widget.mitglied.telefon3!.isNotEmpty)
          const Text("Telefon",
              style: TextStyle(color: Colors.white, fontSize: 20)),
        if (widget.mitglied.telefon3!.isNotEmpty)
          _buildLinkText('tel', widget.mitglied.telefon3!),
      ]);
    } else {
      return Container();
    }
  }

  Widget _buildAddress() {
    LatLng homeLocation = const LatLng(53.608620, 9.897620);
    String memberAddress =
        '${widget.mitglied.strasse}, ${widget.mitglied.plz} ${widget.mitglied.ort}';

    return _buildBox(<Widget>[
      const Text("Anschrift",
          style: TextStyle(color: Colors.white, fontSize: 20)),
      _buildMapText(memberAddress),
      MapWidget(
        homeLocation: homeLocation,
        memberAddress: memberAddress,
      ),
    ]);
  }

  Widget _buildGeburtsdatum() {
    final int age = widget.mitglied.getAlterAm();
    return _buildBox(<Widget>[
      Text(
          'Alter: $age (${widget.mitglied.geburtsDatum.day < 10 ? '0' : ''}${widget.mitglied.geburtsDatum.day}.${widget.mitglied.geburtsDatum.month < 10 ? '0' : ''}${widget.mitglied.geburtsDatum.month}.${widget.mitglied.geburtsDatum.year})',
          style: const TextStyle(color: Colors.white, fontSize: 18)),
    ]);
  }

  Widget _buildTaetigkeitImage(Taetigkeit taetigkeit) {
    String imagerPath = 'assets/images/lilie.png';
    if (taetigkeit.taetigkeit.trim() == 'Mitglied') {
      imagerPath =
          'assets/images/${Stufe.getStufeByString(taetigkeit.untergliederung!).imageName}';
    } else if (taetigkeit.taetigkeit.contains('LeiterIn')) {
      return Image.asset(
        imagerPath,
        width: 80.0,
        height: 80.0,
        fit: BoxFit.cover,
        color: Stufe.getStufeByString(taetigkeit.untergliederung!).farbe,
        colorBlendMode: BlendMode.srcIn,
      );
    }

    return Image.asset(
      imagerPath,
      width: 80.0,
      height: 80.0,
      fit: BoxFit.cover,
    );
  }

  Widget _buildTaetigkeitenItem(Taetigkeit taetigkeit) {
    return SizedBox(
      height: 100,
      width: 400,
      child: Card(
        color: Theme.of(context).colorScheme.surface,
        elevation: 2.0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
        child: IntrinsicHeight(
          child: Padding(
            padding: const EdgeInsets.all(5.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTaetigkeitImage(taetigkeit),
                const SizedBox(width: 10.0),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${taetigkeit.taetigkeit} - ${taetigkeit.untergliederung}',
                        style: const TextStyle(
                          fontSize: 18.0,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 5.0),
                      Text(
                        '${DateFormat('MMMM').format(taetigkeit.aktivVon)} ${taetigkeit.aktivVon.year}${taetigkeit.aktivBis != null ? ' - ${DateFormat('MMMM').format(taetigkeit.aktivBis!)} ${taetigkeit.aktivBis!.year}' : ''}',
                        style: const TextStyle(fontSize: 16.0),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  handleStufenwechsel(int memberId, Taetigkeit currentTaetigkeit, Stufe stufe,
      DateTime aktivVon) async {
    if (await showConfirmationDialog(
        context,
        aktivVon,
        stufe,
        '${widget.mitglied.vorname} ${widget.mitglied.nachname}',
        currentTaetigkeit)) {
      setState(() => loadingStufenwechsel = true);
      try {
        await stufenwechsel(
            widget.mitglied.id, currentTaetigkeit, stufe, aktivVon);
      } catch (e) {
        debugPrint('failed to stufenwechsel');
      }
      widget.mitglied = Hive.box<Mitglied>('members')
          .values
          .firstWhere((element) => element.id == widget.mitglied.id);
      setState(() => loadingStufenwechsel = false);
    }
  }

  Widget _buildStufenwechselItem(
      Taetigkeit fakeStufenwechselTaetigkeit, Taetigkeit currentTaetigkeit) {
    Stufe stufe =
        Stufe.getStufeByString(fakeStufenwechselTaetigkeit.untergliederung!);

    return GestureDetector(
      onTap: loadingStufenwechsel
          ? null
          : () => handleStufenwechsel(widget.mitglied.id, currentTaetigkeit,
              stufe, fakeStufenwechselTaetigkeit.aktivVon),
      child: SizedBox(
        height: 100,
        width: 400,
        child: Card(
          color: loadingStufenwechsel
              ? Theme.of(context).colorScheme.surface
              : Theme.of(context).colorScheme.background,
          elevation: 2.0,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
          child: IntrinsicHeight(
            child: Padding(
              padding: const EdgeInsets.all(5.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  loadingStufenwechsel
                      ? const Padding(
                          padding: EdgeInsets.all(10),
                          child: SizedBox(
                            width: 60.0,
                            height: 60.0,
                            child: CircularProgressIndicator(),
                          ))
                      : _buildTaetigkeitImage(fakeStufenwechselTaetigkeit),
                  const SizedBox(width: 10.0),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${fakeStufenwechselTaetigkeit.untergliederung}',
                          style: const TextStyle(
                            fontSize: 18.0,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Text('(nach Stufenwechsel)'),
                        const SizedBox(height: 5.0),
                        Text(
                          DateFormat('dd. MMMM yyyy')
                              .format(fakeStufenwechselTaetigkeit.aktivVon),
                          style: const TextStyle(fontSize: 16.0),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
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
              'Soll $mitgliedName am ${DateFormat('dd. MMMM yyyy').format(stufenwechselDate)} wirklich zu den ${stufeAfterWechsel.name.value} wechseln?\n\nDie aktuelle Tätigkeit (${currentTaetigkeit.untergliederung}) wird beendet.'),
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
    DateTime currentDate = DateTime.now();
    int? minStufenWechselJahr = widget.mitglied.getMinStufenWechselJahr();
    bool isMinStufenWechselJahrInPast = minStufenWechselJahr != null &&
        minStufenWechselJahr <= currentDate.year;
    Stufe? nextStufe = widget.mitglied.nextStufe;

    // check if stufenwechsel is possible

    if (!isMinStufenWechselJahrInPast ||
        nextStufe == null ||
        !nextStufe.isStufeYouCanChangeTo) {
      return null;
    }

    Taetigkeit? stufenwechselTaetigkeit = Taetigkeit();
    stufenwechselTaetigkeit.aktivVon = getNextStufenwechselDatum();
    stufenwechselTaetigkeit.taetigkeit = 'Mitglied';
    stufenwechselTaetigkeit.untergliederung =
        widget.mitglied.nextStufe?.name.value;
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

    Taetigkeit? fakeStufenwechselTaetigkeit = getStufenwechselTaetigkeit();
    Taetigkeit? currentTaetigkeit = getCurrenttaetigkeit(aktiveTaetigkeiten);
    return Scaffold(
        appBar: AppBar(
          shadowColor: Colors.transparent,
          backgroundColor: Stufe.getStufeByString(widget.mitglied.stufe).farbe,
          title: Text("${widget.mitglied.vorname} ${widget.mitglied.nachname}"),
        ),
        body: Column(
          children: <Widget>[
            _buildStatistikTopRow(),
            TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'Kontaktdaten'),
                Tab(text: 'Tätigkeiten'),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  ListView(
                    children: <Widget>[
                      _buildGeburtsdatum(),
                      _buildMailList(),
                      _buildAddress(),
                    ],
                  ),
                  ListView(
                    children: [
                      if (fakeStufenwechselTaetigkeit != null &&
                          currentTaetigkeit != null)
                        _buildStufenwechselItem(
                            fakeStufenwechselTaetigkeit, currentTaetigkeit),
                      SizedBox(
                          height: aktiveTaetigkeiten.length * 110,
                          child: ListView.builder(
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: aktiveTaetigkeiten.length,
                              itemBuilder: (context, index) =>
                                  _buildTaetigkeitenItem(
                                      aktiveTaetigkeiten[index]))),
                      const SizedBox(
                        height: 20,
                      ),
                      if (vergangeneTaetigkeiten.isNotEmpty)
                        const Text(
                          'Abgeschlossene Tätigkeiten',
                          style: TextStyle(fontSize: 18.0),
                        ),
                      if (vergangeneTaetigkeiten.isNotEmpty)
                        SizedBox(
                            height: vergangeneTaetigkeiten.length * 110,
                            child: ListView.builder(
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: vergangeneTaetigkeiten.length,
                                itemBuilder: (context, index) =>
                                    _buildTaetigkeitenItem(
                                        vergangeneTaetigkeiten[index]))),
                    ],
                  )
                ],
              ),
            ),
          ],
        ));
  }
}
