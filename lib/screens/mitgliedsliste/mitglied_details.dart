import 'package:flutter/material.dart';
import 'package:nami/utilities/hive/mitglied.dart';

class MitgliedDetail extends StatefulWidget {
  final Mitglied mitglied;
  const MitgliedDetail({required this.mitglied, Key? key}) : super(key: key);

  @override
  _MitgliedDetailState createState() => _MitgliedDetailState();
}

class _MitgliedDetailState extends State<MitgliedDetail> {
  @override
  Widget build(BuildContext context) {
    return Text(widget.mitglied.vorname);
  }
}
