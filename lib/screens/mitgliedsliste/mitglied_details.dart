import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:intl/intl.dart';
import 'package:maps_launcher/maps_launcher.dart';
import 'package:nami/screens/mitgliedsliste/mitglied_bearbeiten.dart';
import 'package:nami/screens/mitgliedsliste/taetigkeit_anlegen.dart';
import 'package:nami/screens/widgets/map.widget.dart';
import 'package:nami/screens/widgets/mitgliedStufenPieChart.widget.dart';
import 'package:nami/utilities/app.state.dart';
import 'package:nami/utilities/helper_functions.dart';
import 'package:nami/utilities/hive/mitglied.dart';
import 'package:nami/utilities/hive/settings.dart';
import 'package:nami/utilities/hive/settings_stufenwechsel.dart';
import 'package:nami/utilities/hive/taetigkeit.dart';
import 'package:nami/utilities/logger.dart';
import 'package:nami/utilities/nami/nami_member.service.dart';
import 'package:nami/utilities/nami/nami_rechte.dart';
import 'package:nami/utilities/nami/nami_taetigkeiten.service.dart';
import 'package:nami/utilities/stufe.dart';
import 'package:nami/utilities/types.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:wiredash/wiredash.dart';

// ignore: must_be_immutable - Nach dem Stufenwechsel wird das Mitglied neu geladen
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
  bool loadingEditMember = false;
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
    int pfadfinderTage = widget.mitglied.activeDays;
    if (pfadfinderTage >= 365) {
      int jahre = (pfadfinderTage / 365).floor();
      dauerText = jahre > 1
          ? '$jahre aktive Pfadfinderjahre'
          : 'Ein aktives Pfadfinderjahr';
    } else if (pfadfinderTage >= 30) {
      int monate = (pfadfinderTage / 30).floor();
      dauerText =
          'Aktiv seit ${monate > 1 ? '$monate Monaten' : 'einem Monat'} Pfadfinder:in';
    } else {
      dauerText = 'Aktiv seit $pfadfinderTage Tagen Pfadfinder:in';
    }

    return SizedBox(
        width: MediaQuery.of(context).size.width,
        child: Column(
          children: [
            if (tageProStufe.length > 1)
              MitgliedStufenPieChart(
                  memberPerGroup: tageProStufe,
                  showLeiterGrafik: tageAlsLeiter >= tageAlsMitglied),
            if (tageProStufe.length > 1) const SizedBox(height: 5),
            Text(
              dauerText,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 5),
          ],
        ));
  }

  Widget _buildStatistikTopRow() {
    return Container(
        color: widget.mitglied.currentStufe.farbe,
        child: _buildMitgliedschaftPieChartForTopRow());
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
    if (widget.mitglied.plz.isEmpty) {
      return Container();
    }

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

  Widget _buildMitgliedschaft() {
    final Mitglied mitglied = widget.mitglied;
    final Map<String, String> beitragsartOptions = getMetaBeitragsartOptions();
    final Map<String, String> mitgliedstypOptions =
        getMetaMitgliedstypOptions();
    final beitragsart =
        beitragsartOptions[mitglied.beitragsartId.toString()] ?? 'Unbekannt';
    final mitgliedstyp =
        mitgliedstypOptions[mitglied.mglTypeId.toString()] ?? 'Unbekannt';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Mitgliedschaft",
          style: Theme.of(context).textTheme.titleMedium,
        ),
        _buildBox(Column(children: [
          _buildListTile(Icons.tag, 'NaMi Mitgliedsnummer',
              mitglied.mitgliedsNummer.toString(),
              copy: true),
          _buildListTile(Icons.event, 'Eintrittsdatum',
              mitglied.eintrittsdatum.prettyPrint()),
          _buildListTile(Icons.wallet_membership, 'Mitgliedstyp',
              '$beitragsart ($mitgliedstyp)'),
          _buildListTile(Icons.check, 'Status', mitglied.status.toString()),
          // wenn bearbeiten möglich und rechte vorhanden, button mitglieschaft beenden anzeigen
          if (getAllowedFeatures().contains(AllowedFeatures.membershipEnd) &&
              getNamiChangesEnabled() &&
              getLoggedInUserId() != widget.mitglied.id)
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.redAccent),
              title: const Text(
                'Mitgliedschaft beenden',
                style: TextStyle(color: Colors.redAccent),
              ),
              onTap: () {
                terminateMitgliedschaftDialog(context, mitglied);
              },
            ),
        ])),
      ],
    );
  }

  Widget _buildGeneralInfos() {
    final mitglied = widget.mitglied;
    final int age = getAlterAm(date: mitglied.geburtsDatum).floor();
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
              _buildListTile(Icons.cake, 'Geburtstag',
                  "$age (${widget.mitglied.geburtsDatum.prettyPrint()})"),
              if (mitglied.email.isNotNullOrEmpty)
                _buildListTile(Icons.email, 'E-Mail', mitglied.email!,
                    copy: true, isLink: true, linkType: 'mailto'),
              if (mitglied.emailVertretungsberechtigter.isNotNullOrEmpty)
                _buildListTile(
                  Icons.email,
                  'E-Mail Vertretungsberechtigter',
                  mitglied.emailVertretungsberechtigter!,
                  copy: true,
                  isLink: true,
                  linkType: 'mailto',
                ),
              if (mitglied.telefon1.isNotNullOrEmpty)
                _buildListTile(
                  Icons.call,
                  'Festnetznummer',
                  mitglied.telefon1!,
                  copy: true,
                  isLink: true,
                  linkType: 'tel',
                ),
              if (mitglied.telefon2.isNotNullOrEmpty)
                _buildListTile(
                  Icons.call,
                  'Mobilfunknummer',
                  mitglied.telefon2!,
                  copy: true,
                  isLink: true,
                  linkType: 'tel',
                ),
              if (mitglied.telefon3.isNotNullOrEmpty)
                _buildListTile(
                  Icons.call,
                  'Geschäftlich',
                  mitglied.telefon3!,
                  copy: true,
                  isLink: true,
                  linkType: 'tel',
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildListTile(IconData icon, String subtitle, String title,
      {bool copy = false, bool isLink = false, String? linkType}) {
    return ListTile(
      leading: Icon(icon),
      subtitle: Text(subtitle),
      title: isLink ? _buildLinkText(linkType!, title) : Text(title),
      trailing: copy
          ? IconButton(
              icon: const Icon(Icons.copy),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: title));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Kopiert'),
                    duration: Duration(milliseconds: 700),
                  ),
                );
              },
            )
          : null,
    );
  }

  Widget _buildTaetigkeitImage(Taetigkeit taetigkeit) {
    String liliePath = 'assets/images/lilie_schwarz.png';

    if (taetigkeit.taetigkeit.trim() == 'Mitglied') {
      return Image.asset(
        Stufe.getStufeByString(taetigkeit.untergliederung!).imagePath!,
        width: 80.0,
        height: 80.0,
        cacheHeight: 150,
      );
    } else if (taetigkeit.taetigkeit.contains('LeiterIn')) {
      return Image.asset(
        liliePath,
        width: 80.0,
        height: 80.0,
        color: Stufe.getStufeByString(taetigkeit.untergliederung!).farbe,
        colorBlendMode: BlendMode.srcIn,
        cacheWidth: 150,
      );
    }
    bool isDarkTheme = Theme.of(context).brightness == Brightness.dark;

    return Image.asset(
      liliePath,
      width: 80.0,
      height: 80.0,
      cacheHeight: 150,
      color: Color(isDarkTheme ? 0xFF636363 : 0xFF000000),
      colorBlendMode: BlendMode.srcIn,
    );
  }

  void terminateMitgliedschaftDialog(BuildContext context, Mitglied mitglied) {
    final formKey = GlobalKey<FormBuilderState>();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Mitgliedschaft beenden'),
          content: FormBuilder(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!widget.mitglied.datenweiterverwendung)
                  RichText(
                    text: TextSpan(
                      style: Theme.of(context).textTheme.bodyMedium,
                      text:
                          'Dieses Mitglied hat der weiteren Datenverwendung nach Beendigung der Mitgliedschaft nicht zugestimmt. Mit Beendigung der Mitgliedschaft werden sämtliche Daten ',
                      children: <TextSpan>[
                        TextSpan(
                          text: 'in allen Ebenen',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        TextSpan(
                          text:
                              ' unwiderruflich gelöscht. Die Mitgliedschaft kann nicht in der Zukunft beeendet werden.',
                        ),
                      ],
                    ),
                  ),
                if (widget.mitglied.datenweiterverwendung)
                  RichText(
                    text: TextSpan(
                      style: Theme.of(context).textTheme.bodyMedium,
                      text:
                          'Dieses Mitglied hat der weiteren Datenverwendung nach Beendigung der Mitgliedschaft zugestimmt. Alle Daten ',
                      children: <TextSpan>[
                        TextSpan(
                          text: 'in allen Ebenen',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        TextSpan(
                          text:
                              ' bleiben erhalten und das Mitglied wird mit Beendigung der Mitgliedschaft auf "inaktiv" gesetzt.',
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 8.0),
                const Text(
                    'Sollte das Mitglied noch aktive Tätigkeiten in anderen Gruppierungen (Stamm, Bezirk, Diözese) haben, ist eine Mitgliedsübernahme in Betracht zu ziehen und ggf. die Mitgliedschaft nicht zu beenden.'),
                const SizedBox(height: 16.0),
                Text(
                    'Wann soll die Mitgliedschaft von ${mitglied.vorname} ${mitglied.nachname} beendet werden?'),
                FormBuilderDateTimePicker(
                  inputType: InputType.date,
                  initialValue: DateTime.now(),
                  name: 'beendigungDatum',
                  format: DateFormat('dd.MM.yyyy'),
                  lastDate: widget.mitglied.datenweiterverwendung
                      ? null
                      : DateTime.now(),
                  validator: FormBuilderValidators.compose(
                      [FormBuilderValidators.required()]),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Abbrechen'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text(
                'Mitgliedschaft beenden',
                style: TextStyle(color: Colors.red),
              ),
              onPressed: () async {
                if (formKey.currentState
                        ?.saveAndValidate(focusOnInvalid: false) ??
                    false) {
                  terminateMitgliedschaftConfirmed(
                      widget.mitglied.id!,
                      mitglied,
                      formKey.currentState?.fields['beendigungDatum']?.value);
                  Navigator.of(context).pop();
                }
              },
            ),
          ],
        );
      },
    );
  }

  void terminateMitgliedschaftConfirmed(
      int memberId, Mitglied mitglied, DateTime endDate) async {
    Wiredash.trackEvent('Mitgliedschaft beenden');
    sensLog.i('Mitgliedschaft für Mitglied: ${sensId(memberId)}  beenden');

    try {
      await endMembership(memberId, endDate);
    } on SessionExpiredException catch (_) {
      await AppStateHandler().setReloginState();
      return;
    } catch (e) {
      sensLog.e('Mitgliedschaft beenden fehlgeschlagen: $e');
      Wiredash.trackEvent('Mitgliedschaft beenden fehlgeschlagen', data: {
        'error': e.toString(),
      });
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Mitgliedschaft konnte nicht beendet werden: $e'),
        ),
      );
      return;
    }

    // ignore: use_build_context_synchronously
    Navigator.of(context).pop();
  }

  void terminateTaetigkeitDialog(BuildContext context, Taetigkeit taetigkeit) {
    String? gruppierung = getGruppierungName();
    bool taetigkeitIsFromOtherGroup = taetigkeit.gruppierung != gruppierung;
    bool loggedInUserCouldLooseRights =
        getLoggedInUserId() == widget.mitglied.id &&
            taetigkeit.aktivBis == null &&
            (taetigkeit.berechtigteGruppe != null ||
                taetigkeit.berechtigteUntergruppen != null);
    final formKey = GlobalKey<FormBuilderState>();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Tätigkeit beenden'),
          content: FormBuilder(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: RichText(
                    text: TextSpan(
                      children: [
                        const TextSpan(
                          text: 'Tätigkeit: ',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextSpan(
                          text:
                              '${taetigkeit.taetigkeit} ${taetigkeit.untergliederung!.isNotEmpty ? '- ${taetigkeit.untergliederung}' : ''}',
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16.0),
                const Text('Wann soll die Tätigkeit beendet werden?'),
                FormBuilderDateTimePicker(
                  inputType: InputType.date,
                  name: 'beendigungDatum',
                  format: DateFormat('dd.MM.yyyy'),
                  validator: FormBuilderValidators.compose([
                    FormBuilderValidators.required(),
                    (val) {
                      if (val == null) return null;
                      if (val.isBefore(taetigkeit.aktivVon)) {
                        return 'Das Datum muss nach ${taetigkeit.aktivVon.prettyPrint()} liegen.';
                      }
                      return null;
                    },
                  ]),
                ),
                const SizedBox(height: 40.0),
                Align(
                  alignment: Alignment.centerLeft,
                  child: RichText(
                    text: TextSpan(
                      children: [
                        const TextSpan(
                          text: 'Tätigkeit stattdessen ',
                        ),
                        TextSpan(
                          text: 'löschen',
                          style: const TextStyle(color: Colors.red),
                          recognizer: TapGestureRecognizer()
                            ..onTap = () {
                              Navigator.of(context).pop();
                              openDeleteTaetigkeitDialog(context, taetigkeit);
                            },
                        ),
                      ],
                    ),
                  ),
                ),
                // taetigkeit is from logged in user and has berechtigungen
                if (loggedInUserCouldLooseRights)
                  Padding(
                    padding: const EdgeInsets.only(top: 16.0),
                    child: Container(
                      color: Colors.orange.withValues(alpha: 0.1),
                      padding: const EdgeInsets.all(8.0),
                      child: const Text(
                        'Dir könnten beim beenden der Tätigkeit Rechte verloren gehen. Bitte prüfe, ob du die Tätigkeit wirklich beenden möchtest.',
                        style: TextStyle(
                            color: Colors.orange, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                if (taetigkeitIsFromOtherGroup)
                  Padding(
                    padding: const EdgeInsets.only(top: 16.0),
                    child: Container(
                      color: Colors.orange.withValues(alpha: 0.1),
                      padding: const EdgeInsets.all(8.0),
                      child: const Text(
                        'Die Tätigkeit ist einer anderen Gruppierung zugehörig, beenden ist vermutlich nicht möglich.',
                        style: TextStyle(
                            color: Colors.orange, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Abbrechen'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Speichern'),
              onPressed: () async {
                if (formKey.currentState
                        ?.saveAndValidate(focusOnInvalid: false) ??
                    false) {
                  completeTaetigkeitConfirmed(widget.mitglied.id!, taetigkeit,
                      formKey.currentState?.fields['beendigungDatum']?.value);
                  Navigator.of(context).pop();
                }
              },
            ),
          ],
        );
      },
    );
  }

  void openCreateTaetigkeitDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return TaetigkeitAnlegen(mitgliedId: widget.mitglied.id!);
      },
    ).then((result) async {
      if (!result) return;
      // Mitglied aktualisieren, wenn der Dialog geschlossen wird
      Mitglied newMitglied = await updateOneMember(widget.mitglied.id!);
      setState(() {
        widget.mitglied = newMitglied;
      });
    });
  }

  Future<void> completeTaetigkeitConfirmed(
      int memberId, Taetigkeit taetigkeit, DateTime endDate) async {
    Wiredash.trackEvent('Taetigkeit beenden');
    sensLog.i(
        'Tätigkeit für Mitglied: ${sensId(memberId)} | Tätigkeit: ${taetigkeit.id} beenden');
    await completeTaetigkeit(memberId, taetigkeit, endDate);
    Mitglied newMitglied = await updateOneMember(memberId);
    setState(() => widget.mitglied = newMitglied);

    // ignore: use_build_context_synchronously
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Tätigkeit beendet'),
        duration: Duration(milliseconds: 700),
      ),
    );
  }

  Future<void> deleteTaetigkeitConfirmed(
      int memberId, Taetigkeit taetigkeit) async {
    Wiredash.trackEvent('Taetigkeit loeschen');
    sensLog.i(
        'Tätigkeit für Mitglied: ${sensId(memberId)} | Tätigkeit: ${taetigkeit.id} löschen');
    await deleteTaetigkeit(memberId, taetigkeit);
    Mitglied newMitglied = await updateOneMember(memberId);
    setState(() => widget.mitglied = newMitglied);
  }

  void openDeleteTaetigkeitDialog(BuildContext context, Taetigkeit taetigkeit) {
    String? gruppierung = getGruppierungName();
    bool taetigkeitIsFromOtherGroup = taetigkeit.gruppierung != gruppierung;
    bool loggedInUserCouldLooseRights =
        getLoggedInUserId() == widget.mitglied.id &&
            taetigkeit.aktivBis == null &&
            (taetigkeit.berechtigteGruppe != null ||
                taetigkeit.berechtigteUntergruppen != null);
    bool createdMoreThanTwoDaysAgo = taetigkeit.anlagedatum
        .isBefore(DateTime.now().subtract(const Duration(days: 2)));
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Tätigkeit löschen'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: RichText(
                  text: TextSpan(
                    children: [
                      const TextSpan(
                        text: 'Tätigkeit: ',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextSpan(
                        text:
                            '${taetigkeit.taetigkeit} ${taetigkeit.untergliederung!.isNotEmpty ? '- ${taetigkeit.untergliederung}' : ''}',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16.0),
              const Text(
                  'Sind Sie sicher, dass Sie diese Tätigkeit löschen möchten?'),
              const SizedBox(height: 16.0),
              if (loggedInUserCouldLooseRights)
                Padding(
                  padding: const EdgeInsets.only(top: 16.0),
                  child: Container(
                    color: Colors.orange.withValues(alpha: 0.1),
                    padding: const EdgeInsets.all(8.0),
                    child: const Text(
                      'Dir könnten beim Löschen Rechte verloren gehen. Bitte prüfe, ob du die Tätigkeit wirklich löschen möchtest.',
                      style: TextStyle(
                          color: Colors.orange, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              if (taetigkeitIsFromOtherGroup)
                Padding(
                  padding: const EdgeInsets.only(top: 16.0),
                  child: Container(
                    color: Colors.orange.withValues(alpha: 0.1),
                    padding: const EdgeInsets.all(8.0),
                    child: const Text(
                      'Die Tätigkeit ist einer anderen Gruppierung zugehörig, löschen ist vermutlich nicht möglich.',
                      style: TextStyle(
                          color: Colors.orange, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              // older than 2 days
              if (createdMoreThanTwoDaysAgo)
                Padding(
                  padding: const EdgeInsets.only(top: 16.0),
                  child: Container(
                    color: Colors.orange.withValues(alpha: 0.1),
                    padding: const EdgeInsets.all(8.0),
                    child: const Text(
                      'Die Tätigkeit ist vor mehr als zwei Tagen angelegt worden, löschen ist vermutlich nicht möglich.',
                      style: TextStyle(
                          color: Colors.orange, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Abbrechen'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              onPressed: () {
                deleteTaetigkeitConfirmed(widget.mitglied.id!, taetigkeit);
                Navigator.of(context).pop();
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
              child: const Text('Löschen'),
            )
          ],
        );
      },
    );
  }

  Widget _buildTaetigkeitenItem(Taetigkeit taetigkeit) {
    // TODO add tätigkeit permissions
    bool permissionToEdit =
        getAllowedFeatures().contains(AllowedFeatures.memberEdit) &&
            getNamiChangesEnabled();
    return _buildBox(Dismissible(
      key: Key(taetigkeit.id.toString()),
      direction: permissionToEdit
          ? DismissDirection.endToStart
          : DismissDirection.none,
      confirmDismiss: (direction) async {
        if (taetigkeit.endsInFuture()) {
          terminateTaetigkeitDialog(context, taetigkeit);
        } else {
          openDeleteTaetigkeitDialog(context, taetigkeit);
        }
        return false;
      },
      background: Container(
        color: taetigkeit.endsInFuture() ? Colors.orange : Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Icon(
          taetigkeit.endsInFuture() ? Icons.event_busy : Icons.delete,
          color: Colors.white,
        ),
      ),
      child: ListTile(
        leading: _buildTaetigkeitImage(taetigkeit),
        title: Text(
          '${taetigkeit.taetigkeit} ${taetigkeit.untergliederung!.isNotEmpty ? '- ${taetigkeit.untergliederung}' : ''} ',
        ),
        subtitle: Text(
          '${DateFormat('MMMM').format(taetigkeit.aktivVon)} ${taetigkeit.aktivVon.year} ${taetigkeit.aktivBis != null ? '- ${DateFormat('MMMM').format(taetigkeit.aktivBis!)} ${taetigkeit.aktivBis!.year}' : ''} ${getGruppierungName() != taetigkeit.gruppierung ? '\nGruppierung: ${taetigkeit.gruppierung}' : ''} ${taetigkeit.berechtigteGruppe != null && taetigkeit.berechtigteGruppe!.isNotEmpty ? '\nBerechtigung: ${taetigkeit.berechtigteGruppe}' : ''}',
        ),
      ),
    ));
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
            "Stufenwechsel am ${DateFormat('dd. MMMM yyyy').format(fakeStufenwechselTaetigkeit.aktivVon)}"),
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
    bool nextStufeAlreadyAssigned = widget.mitglied.taetigkeiten
        .any((element) => element.untergliederung == nextStufe!.display);

    // check if stufenwechsel is possible
    if (nextStufeAlreadyAssigned ||
        !isMinStufenWechselJahrInPast ||
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

  Future<void> editMemberClicked() async {
    setState(() {
      loadingEditMember = true;
    });

    Wiredash.trackEvent('Member Details edit');

    Mitglied updatedMitglied;
    try {
      updatedMitglied = await updateOneMember(widget.mitglied.id!);
    } on SessionExpiredException catch (_) {
      if (!await AppStateHandler().setReloginState()) {
        // ignore: use_build_context_synchronously
        Navigator.of(context).pop();
        updatedMitglied = await updateOneMember(widget.mitglied.id!);
      } else {
        return;
      }
    }

    setState(() {
      loadingEditMember = false;
    });
    // ignore: use_build_context_synchronously
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    Navigator.push(
      // ignore: use_build_context_synchronously
      context,
      MaterialPageRoute(
        builder: (context) => MitgliedBearbeiten(
          mitglied: updatedMitglied,
        ),
      ),
    ).then((result) async {
      if (result != null) {
        Mitglied newMitglied = await updateOneMember(widget.mitglied.id!);
        setState(() {
          widget.mitglied = newMitglied;
          loadingEditMember = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    List<Taetigkeit> aktiveTaetigkeiten =
        widget.mitglied.getActiveTaetigkeiten();
    aktiveTaetigkeiten.sort((a, b) => b.aktivVon.compareTo(a.aktivVon));
    List<Taetigkeit> vergangeneTaetigkeiten =
        widget.mitglied.getAlteTaetigkeiten();
    vergangeneTaetigkeiten.sort((a, b) => b.aktivVon.compareTo(a.aktivVon));
    List<Taetigkeit> zukuenftigeTaetigkeiten =
        widget.mitglied.getZukuenftigeTaetigkeiten();
    zukuenftigeTaetigkeiten.sort((a, b) => b.aktivVon.compareTo(a.aktivVon));
    bool isFavorite =
        getFavouriteList().contains(widget.mitglied.mitgliedsNummer);
    Taetigkeit? currentTaetigkeit = getCurrenttaetigkeit(aktiveTaetigkeiten);
    Taetigkeit? fakeStufenwechselTaetigkeit =
        currentTaetigkeit == null ? null : getStufenwechselTaetigkeit();

    return Scaffold(
      appBar: AppBar(
        shadowColor: Colors.transparent,
        backgroundColor: widget.mitglied.currentStufe.farbe,
        title: Text("${widget.mitglied.vorname} ${widget.mitglied.nachname}"),
        actions: [
          if (getNamiChangesEnabled() &&
              getAllowedFeatures().contains(AllowedFeatures.memberEdit))
            IconButton(
                onPressed: loadingEditMember ? null : editMemberClicked,
                icon: loadingEditMember
                    ? const CircularProgressIndicator()
                    : const Icon(
                        Icons.edit,
                        color: Colors.black54,
                      )),
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
              icon: Icon(
                isFavorite ? Icons.bookmark : Icons.bookmark_border,
                color: Colors.black54,
              ))
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
            child: TabBarView(
              controller: _tabController,
              children: [
                ListView(
                  padding: const EdgeInsets.all(10.0),
                  children: <Widget>[
                    _buildGeneralInfos(),
                    _buildAddress(),
                    _buildMitgliedschaft(),
                  ],
                ),
                ListView(
                  padding: const EdgeInsets.all(10.0),
                  children: [
                    if (zukuenftigeTaetigkeiten.isNotEmpty ||
                        fakeStufenwechselTaetigkeit != null) ...[
                      Row(
                        children: [
                          Text(
                            'Zukünftige Tätigkeit',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const Spacer(),
                          if (getNamiChangesEnabled() &&
                              getAllowedFeatures()
                                  .contains(AllowedFeatures.taetigkeitCreate))
                            TextButton(
                              onPressed: () => openCreateTaetigkeitDialog(),
                              child: const Text(
                                'Weitere hinzufügen',
                                style: TextStyle(color: Colors.blue),
                              ),
                            ),
                        ],
                      ),
                      for (final taetigkeit in zukuenftigeTaetigkeiten)
                        _buildTaetigkeitenItem(taetigkeit),
                      if (fakeStufenwechselTaetigkeit != null)
                        _buildStufenwechselItem(
                            fakeStufenwechselTaetigkeit, currentTaetigkeit!),
                      const SizedBox(height: 10),
                    ],
                    if (aktiveTaetigkeiten.isNotEmpty)
                      Row(
                        children: [
                          Text(
                            'Aktive Tätigkeiten',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const Spacer(),
                          if (getNamiChangesEnabled() &&
                              getAllowedFeatures()
                                  .contains(AllowedFeatures.taetigkeitCreate))
                            if (fakeStufenwechselTaetigkeit == null &&
                                zukuenftigeTaetigkeiten.isEmpty)
                              TextButton(
                                onPressed: () => openCreateTaetigkeitDialog(),
                                child: const Text(
                                  'Weitere hinzufügen',
                                  style: TextStyle(color: Colors.blue),
                                ),
                              ),
                        ],
                      ),
                    for (final taetigkeit in aktiveTaetigkeiten)
                      _buildTaetigkeitenItem(taetigkeit),
                    const SizedBox(height: 10),
                    if (getNamiChangesEnabled() &&
                        getAllowedFeatures()
                            .contains(AllowedFeatures.taetigkeitCreate))
                      if ((fakeStufenwechselTaetigkeit == null ||
                              currentTaetigkeit == null) &&
                          aktiveTaetigkeiten.isEmpty)
                        Align(
                          alignment: Alignment.center,
                          child: TextButton(
                            onPressed: () => openCreateTaetigkeitDialog(),
                            child: const Text(
                              'Neue Tätigkeit erstellen',
                              style: TextStyle(color: Colors.blue),
                            ),
                          ),
                        ),
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
                    padding: const EdgeInsets.all(10.0),
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
        ],
      ),
    );
  }
}
