import 'package:flutter/material.dart';

import '../../domain/member/member_address_utils.dart';
import '../../domain/member/mitglied.dart';
import '../../services/statistics_location_service.dart';

typedef StandortAufloesung =
    Future<StatisticsResolvedLocations> Function({
      required List<Mitglied> members,
      required String? stammAddress,
    });

/// Löst die Adressen der Mitglieder und des Stammesheims auf und baut daraus
/// eine Ansicht. Die Auflösung läuft nur neu, wenn sich Adressen ändern.
class StatistikStandortAufloesung extends StatefulWidget {
  const StatistikStandortAufloesung({
    super.key,
    required this.members,
    required this.stammAddress,
    required this.builder,
    this.aufloesung,
  });

  final List<Mitglied> members;
  final String? stammAddress;

  /// `null` = echte Auflösung über [StatisticsLocationService].
  final StandortAufloesung? aufloesung;

  /// [daten] ist `null`, solange noch aufgelöst wird.
  final Widget Function(
    BuildContext context,
    StatisticsResolvedLocations? daten,
  )
  builder;

  static bool hatEingaben(List<Mitglied> members, String? stammAddress) =>
      members.any((m) => m.primaryAddress != null) ||
      (stammAddress ?? '').trim().isNotEmpty;

  @override
  State<StatistikStandortAufloesung> createState() =>
      _StatistikStandortAufloesungState();
}

class _StatistikStandortAufloesungState
    extends State<StatistikStandortAufloesung> {
  StatisticsLocationService? _service;
  late Future<StatisticsResolvedLocations> _future;
  late String _signatur;

  @override
  void initState() {
    super.initState();
    _signatur = _signaturFuer(widget);
    _future = _aufloesen();
  }

  @override
  void didUpdateWidget(covariant StatistikStandortAufloesung oldWidget) {
    super.didUpdateWidget(oldWidget);
    final signatur = _signaturFuer(widget);
    if (signatur == _signatur) return;
    _signatur = signatur;
    _future = _aufloesen();
  }

  Future<StatisticsResolvedLocations> _aufloesen() {
    final eigene = widget.aufloesung;
    if (eigene != null) {
      return eigene(members: widget.members, stammAddress: widget.stammAddress);
    }
    final service = _service ??= StatisticsLocationService();
    return service.resolveLocations(
      members: widget.members,
      stammAddress: widget.stammAddress,
    );
  }

  static String _signaturFuer(StatistikStandortAufloesung widget) {
    final keys = <String>[
      for (final member in widget.members)
        if (member.primaryAddress != null)
          MemberAddressUtils.fingerprint(member.primaryAddress!),
    ]..sort();
    return '${keys.join('|')}#${(widget.stammAddress ?? '').trim()}';
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<StatisticsResolvedLocations>(
      future: _future,
      builder: (context, snapshot) => widget.builder(
        context,
        snapshot.connectionState == ConnectionState.done
            ? snapshot.data ??
                  const StatisticsResolvedLocations(
                    memberPoints: [],
                    stammPoint: null,
                  )
            : null,
      ),
    );
  }
}
