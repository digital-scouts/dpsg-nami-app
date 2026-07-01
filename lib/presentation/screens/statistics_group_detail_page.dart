import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:nami/data/settings/shared_prefs_address_settings_repository.dart';
import 'package:nami/data/settings/shared_prefs_stufen_settings_repository.dart';
import 'package:nami/domain/stufe/altersgrenzen.dart';
import 'package:nami/presentation/widgets/statistik_agedistribution.dart';
import 'package:provider/provider.dart';

import '../../domain/arbeitskontext/arbeitskontext_read_model.dart';
import '../../domain/member/member_address_utils.dart';
import '../../domain/member/mitglied.dart';
import '../../services/statistics_location_service.dart';
import '../model/arbeitskontext_model.dart';
import '../statistics/statistics_snapshot_builder.dart';
import '../statistics/statistics_ui.dart';

class StatisticsGroupDetailPage extends StatefulWidget {
  const StatisticsGroupDetailPage({
    super.key,
    required this.groupId,
    this.debugReadModel,
  });

  final String groupId;
  final ArbeitskontextReadModel? debugReadModel;

  @override
  State<StatisticsGroupDetailPage> createState() =>
      _StatisticsGroupDetailPageState();
}

class _StatisticsGroupDetailPageState extends State<StatisticsGroupDetailPage> {
  static const StatisticsSnapshotBuilder _snapshotBuilder =
      StatisticsSnapshotBuilder();

  final StatisticsLocationService _locationService =
      StatisticsLocationService();
  final SharedPrefsStufenSettingsRepository _stufenSettingsRepository =
      SharedPrefsStufenSettingsRepository();
  final SharedPrefsAddressSettingsRepository _addressSettingsRepository =
      SharedPrefsAddressSettingsRepository();
  Altersgrenzen _altersgrenzen = StufenDefaults.build();
  String? _stammAddress;
  Future<StatisticsResolvedLocations>? _locationsFuture;
  String? _locationsSignature;

  @override
  void initState() {
    super.initState();
    _loadAltersgrenzen();
    _loadStammAddress();
  }

  Future<void> _loadAltersgrenzen() async {
    final settings = await _stufenSettingsRepository.load();
    if (!mounted) {
      return;
    }
    setState(() {
      _altersgrenzen = settings.grenzen;
    });
  }

  Future<void> _loadStammAddress() async {
    final address = await _addressSettingsRepository.loadAddress();
    if (!mounted) {
      return;
    }
    setState(() {
      _stammAddress = address;
    });
  }

  @override
  Widget build(BuildContext context) {
    final injectedReadModel = widget.debugReadModel;
    final arbeitskontextModel = injectedReadModel == null
        ? context.watch<ArbeitskontextModel>()
        : null;
    final readModel = injectedReadModel ?? arbeitskontextModel?.readModel;

    if (readModel == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Gruppenstatistik')),
        body: const Center(child: Text('Keine Statistikdaten verfuegbar.')),
      );
    }

    final snapshot = _snapshotBuilder.build(
      readModel,
      altersgrenzen: _altersgrenzen,
    );
    final group = snapshot.detailById(widget.groupId);
    if (group == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Gruppenstatistik')),
        body: const Center(child: Text('Gruppe nicht gefunden.')),
      );
    }

    final members = group.memberIds
        .map((id) => snapshot.memberById[id])
        .whereType<Mitglied>()
        .toList(growable: false);
    final hasAgeData = group.ageDistribution.maxCount > 0;
    final hasGenderData = group.gender.any(
      (item) => item.label != 'Ohne Angabe' && item.value > 0,
    );
    final hasConfessionData = group.confessions.isNotEmpty;
    final hasLocationInput = members.any(
      (member) => member.primaryAddress != null,
    );
    final hasStammAddress = (_stammAddress ?? '').trim().isNotEmpty;
    _ensureLocationsFuture(members);

    return Scaffold(
      appBar: AppBar(titleSpacing: 0, title: Text(group.name)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          StatisticsCard(
            title: 'Mitglieder',
            child: StatisticsKpiRow(
              items: [
                StatisticsKpiItem(
                  value: '${group.members}',
                  label: 'Mitglieder',
                  highlight: true,
                ),
                StatisticsKpiItem(value: '${group.leaders}', label: 'Leitende'),
              ],
            ),
          ),
          if (hasAgeData) ...[
            const SizedBox(height: 12),
            StatisticsCard(
              title: 'Altersverteilung',
              child: AgeDistributionChart(
                data: group.ageDistribution,
                enableInteraction: false,
              ),
            ),
          ],
          if (hasGenderData) ...[
            const SizedBox(height: 12),
            StatisticsCard(
              title: 'Geschlecht',
              child: StatisticsPieLegend(items: group.gender),
            ),
          ],
          if (hasConfessionData) ...[
            const SizedBox(height: 12),
            StatisticsCard(
              title: 'Konfession',
              child: StatisticsPieLegend(items: group.confessions),
            ),
          ],
          if (hasLocationInput || hasStammAddress) ...[
            const SizedBox(height: 12),
            FutureBuilder<StatisticsResolvedLocations>(
              future: _locationsFuture,
              builder: (context, locationSnapshot) {
                if (locationSnapshot.connectionState != ConnectionState.done) {
                  return const StatisticsCard(
                    title: 'Standorte',
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                final resolved =
                    locationSnapshot.data ??
                    const StatisticsResolvedLocations(
                      memberPoints: <LatLng>[],
                      stammPoint: null,
                    );
                if (resolved.memberPoints.isEmpty &&
                    resolved.stammPoint == null) {
                  return const SizedBox.shrink();
                }
                return StatisticsMapCard(
                  title: 'Standorte',
                  markers: resolved.memberPoints,
                  stammLocation: resolved.stammPoint,
                );
              },
            ),
          ],
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  void _ensureLocationsFuture(List<Mitglied> members) {
    final signature =
        '${_buildMemberSignature(members)}|${(_stammAddress ?? '').trim()}';
    if (_locationsFuture != null && signature == _locationsSignature) {
      return;
    }
    _locationsSignature = signature;
    _locationsFuture = _locationService.resolveLocations(
      members: members,
      stammAddress: _stammAddress,
    );
  }

  String _buildMemberSignature(List<Mitglied> members) {
    final keys = <String>[];
    for (final member in members) {
      final address = member.primaryAddress;
      if (address == null) {
        continue;
      }
      keys.add(MemberAddressUtils.fingerprint(address));
    }
    keys.sort();
    return keys.join('|');
  }
}
