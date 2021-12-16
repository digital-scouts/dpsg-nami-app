import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:nami/utilities/constants.dart';
import 'package:nami/utilities/hive/mitglied.dart';
import 'package:nami/utilities/hive/taetigkeit.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:maps_launcher/maps_launcher.dart';

class MitgliedDetail extends StatefulWidget {
  final Mitglied mitglied;
  const MitgliedDetail({required this.mitglied, Key? key}) : super(key: key);

  @override
  _MitgliedDetailState createState() => _MitgliedDetailState();
}

class _MitgliedDetailState extends State<MitgliedDetail> {
  bool showMoreTaetigkeiten = false;

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
            if (await canLaunch(url)) {
              await launch(url);
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
        widget.mitglied.email!.isNotEmpty) {
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
      ]);
    } else {
      return Container();
    }
  }

  Widget _buildPhoneList() {
    if (widget.mitglied.telefon1!.isNotEmpty ||
        widget.mitglied.telefon2!.isNotEmpty ||
        widget.mitglied.telefon3!.isNotEmpty) {
      return _buildBox(<Widget>[
        if (widget.mitglied.telefon1!.isNotEmpty)
          const Text("Telefon 1",
              style: TextStyle(color: Colors.white, fontSize: 20)),
        if (widget.mitglied.telefon1!.isNotEmpty)
          _buildLinkText('tel', widget.mitglied.telefon1!),
        if (widget.mitglied.telefon2!.isNotEmpty)
          const Text("Telefon 2",
              style: TextStyle(color: Colors.white, fontSize: 20)),
        if (widget.mitglied.telefon2!.isNotEmpty)
          _buildLinkText('tel', widget.mitglied.telefon2!),
        if (widget.mitglied.telefon3!.isNotEmpty)
          const Text("Telefon 3",
              style: TextStyle(color: Colors.white, fontSize: 20)),
        if (widget.mitglied.telefon3!.isNotEmpty)
          _buildLinkText('tel', widget.mitglied.telefon3!),
      ]);
    } else {
      return Container();
    }
  }

  Widget _buildAdress() {
    return _buildBox(<Widget>[
      const Text("Anschrift",
          style: TextStyle(color: Colors.white, fontSize: 20)),
      _buildMapText(
          '${widget.mitglied.strasse}, ${widget.mitglied.plz} ${widget.mitglied.ort}'),
    ]);
  }

  Widget _buildTaetigkeiten() {
    List<Taetigkeit> aktiveTaetigkeiten = [];
    List<Taetigkeit> alteTaetigkeiten = [];
    for (Taetigkeit taetigkeit in widget.mitglied.taetigkeiten) {
      taetigkeit.taetigkeit =
          taetigkeit.taetigkeit.replaceFirst('€ ', '').split('(')[0];
      if (taetigkeit.isActive()) {
        aktiveTaetigkeiten.add(taetigkeit);
      } else {
        alteTaetigkeiten.add(taetigkeit);
      }
    }
    return _buildBox(<Widget>[
      const Text("Aktive Tätigkeiten", style: TextStyle(color: Colors.white)),
      for (Taetigkeit item in aktiveTaetigkeiten)
        Text(
            '${item.taetigkeit} - ${item.untergliederung} (Seit: ${item.aktivVon.month}/${item.aktivVon.year})',
            style: const TextStyle(color: Colors.white)),
      const SizedBox(height: 10),
      if (!showMoreTaetigkeiten)
        GestureDetector(
          onTap: () {
            setState(() => showMoreTaetigkeiten = true);
          },
          child: const Text("Alte Tätigkeiten anzeigen"),
        ),
      if (showMoreTaetigkeiten)
        const Text("Alte Tätigkeiten", style: TextStyle(color: Colors.white)),
      if (showMoreTaetigkeiten)
        for (Taetigkeit item in alteTaetigkeiten)
          Text(
              '${item.taetigkeit} - ${item.untergliederung} (${item.aktivVon.month}/${item.aktivVon.year}-${item.aktivBis!.month}/${item.aktivBis!.year})',
              style: const TextStyle(color: Colors.white)),
      if (showMoreTaetigkeiten)
        GestureDetector(
          onTap: () {
            setState(() => showMoreTaetigkeiten = false);
          },
          child: const Text("Weniger anzeigen"),
        ),
    ]);
  }

  Widget _buildHeader() {
    String phone = widget.mitglied.telefon1 ??
        widget.mitglied.telefon2 ??
        widget.mitglied.telefon3 ??
        "";
    List<String> emails = List.empty(growable: true);
    if (widget.mitglied.email!.isNotEmpty) {
      emails.add(widget.mitglied.email!);
    }
    if (widget.mitglied.emailVertretungsberechtigter!.isNotEmpty) {
      emails.add(widget.mitglied.emailVertretungsberechtigter!);
    }

    if (phone.isNotEmpty || emails.isNotEmpty) {
      return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        if (emails.isNotEmpty)
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Ink(
              decoration: ShapeDecoration(
                color: Colors.blue,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(5)),
              ),
              child: IconButton(
                iconSize: 35,
                icon: const Icon(Icons.mail),
                tooltip: 'E-Mail',
                onPressed: () async {
                  final Uri params = Uri(
                    scheme: 'mailto',
                    path: emails.join(','),
                  );

                  var url = params.toString();
                  // dies Funktioniert, wenn die notwendige app installiert ist
                  if (await canLaunch(url)) {
                    await launch(url);
                  }
                },
              ),
            ),
          ),
        if (phone.isNotEmpty)
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Ink(
              decoration: ShapeDecoration(
                color: Colors.blue,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(5)),
              ),
              child: IconButton(
                iconSize: 35,
                icon: const Icon(Icons.phone),
                tooltip: 'Anrufen',
                onPressed: () async {
                  final Uri params = Uri(
                    scheme: 'tel',
                    path: phone,
                  );

                  var url = params.toString();
                  // dies Funktioniert, wenn die notwendige app installiert ist
                  if (await canLaunch(url)) {
                    await launch(url);
                  }
                },
              ),
            ),
          ),
      ]);
    } else {
      return Container();
    }
  }

  Widget _buildBox(List<Widget> children) {
    return SizedBox(
      child: Card(
        color: Colors.black87,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor:
            StufenExtension.getValueFromString(widget.mitglied.stufe).color(),
        title: Text("${widget.mitglied.vorname} ${widget.mitglied.nachname}"),
      ),
      body: Column(children: <Widget>[
        _buildHeader(),
        _buildMailList(),
        _buildPhoneList(),
        _buildAdress(),
        _buildTaetigkeiten(),
      ]),
    );
  }
}
