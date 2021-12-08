import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:nami/utilities/constants.dart';
import 'package:nami/utilities/hive/mitglied.dart';
import 'package:url_launcher/url_launcher.dart';

class MitgliedDetail extends StatefulWidget {
  final Mitglied mitglied;
  const MitgliedDetail({required this.mitglied, Key? key}) : super(key: key);

  @override
  _MitgliedDetailState createState() => _MitgliedDetailState();
}

class _MitgliedDetailState extends State<MitgliedDetail> {
  Widget _buildMailLink(String mail) {
    return RichText(
      textAlign: TextAlign.left,
      text: TextSpan(
        text: mail,
        style: const TextStyle(color: Colors.blue, fontSize: 20),
        recognizer: TapGestureRecognizer()
          ..onTap = () async {
            final Uri params = Uri(
              scheme: 'mailto',
              path: mail,
            );

            var url = params.toString();
            // dies Funktioniert, wenn eine E-Mail app installiert ist
            if (await canLaunch(url)) {
              await launch(url);
            }
          },
      ),
    );
  }

  Widget _buildMailPhone(String tel) {
    return RichText(
      textAlign: TextAlign.left,
      text: TextSpan(
        text: tel,
        style: const TextStyle(color: Colors.blue, fontSize: 20),
        recognizer: TapGestureRecognizer()
          ..onTap = () async {
            final Uri params = Uri(
              scheme: 'tel',
              path: tel,
            );

            var url = params.toString();
            // dies Funktioniert, wenn eine E-Mail app installiert ist
            if (await canLaunch(url)) {
              await launch(url);
            }
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
          _buildMailLink(widget.mitglied.email!),
        if (widget.mitglied.emailVertretungsberechtigter!.isNotEmpty)
          const Text("E-Mail Vertretungsberechtigte:r",
              style: TextStyle(color: Colors.white, fontSize: 20)),
        if (widget.mitglied.emailVertretungsberechtigter!.isNotEmpty)
          _buildMailLink(widget.mitglied.emailVertretungsberechtigter!),
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
          _buildMailPhone(widget.mitglied.telefon1!),
        if (widget.mitglied.telefon2!.isNotEmpty)
          const Text("Telefon 2",
              style: TextStyle(color: Colors.white, fontSize: 20)),
        if (widget.mitglied.telefon2!.isNotEmpty)
          _buildMailPhone(widget.mitglied.telefon2!),
        if (widget.mitglied.telefon3!.isNotEmpty)
          const Text("Telefon 3",
              style: TextStyle(color: Colors.white, fontSize: 20)),
        if (widget.mitglied.telefon3!.isNotEmpty)
          _buildMailPhone(widget.mitglied.telefon3!),
      ]);
    } else {
      return Container();
    }
  }

  Widget _buildAdress() {
    return Container();
  }

  Widget _buildTaetigkeiten() {
    return Container();
  }

  Widget _buildHeader() {
    return Container();
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
