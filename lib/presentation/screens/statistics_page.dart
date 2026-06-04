import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:nami/data/settings/shared_prefs_address_settings_repository.dart';
import 'package:nami/data/settings/shared_prefs_stufen_settings_repository.dart';
import 'package:nami/domain/stufe/altersgrenzen.dart';
import 'package:nami/presentation/widgets/statistik_agedistribution.dart';
import 'package:nami/presentation/widgets/statistik_groupdistribution.dart';
import 'package:provider/provider.dart';

import '../../domain/arbeitskontext/arbeitskontext_read_model.dart';
import '../../domain/member/member_address_utils.dart';
import '../../domain/member/mitglied.dart';
import '../../services/statistics_location_service.dart';
import '../model/arbeitskontext_model.dart';
import '../navigation/app_router.dart';
import '../statistics/statistics_snapshot_builder.dart';
import '../statistics/statistics_ui.dart';

class StatisticsPage extends StatefulWidget {
  const StatisticsPage({super.key, this.debugReadModel});

  final ArbeitskontextReadModel? debugReadModel;

  @override
  State<StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends State<StatisticsPage> {
  static const StatisticsSnapshotBuilder _snapshotBuilder =
      StatisticsSnapshotBuilder();
  final SharedPrefsStufenSettingsRepository _stufenSettingsRepository =
      SharedPrefsStufenSettingsRepository();
  final SharedPrefsAddressSettingsRepository _addressSettingsRepository =
      SharedPrefsAddressSettingsRepository();
  Altersgrenzen _altersgrenzen = StufenDefaults.build();
  String? _stammAddress;

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

  void _openGroup(String groupId) {
    final arguments = widget.debugReadModel == null
        ? groupId
        : <String, Object?>{
            'groupId': groupId,
            'readModel': widget.debugReadModel,
          };
    Navigator.of(
      context,
    ).pushNamed(AppRoutes.statisticsGroupDetail, arguments: arguments);
  }

  @override
  Widget build(BuildContext context) {
    final injectedReadModel = widget.debugReadModel;
    final arbeitskontextModel = injectedReadModel == null
        ? context.watch<ArbeitskontextModel>()
        : null;
    final readModel = injectedReadModel ?? arbeitskontextModel?.readModel;

    if (injectedReadModel == null &&
        (arbeitskontextModel!.isLoading ||
            arbeitskontextModel.isLoadingRoles) &&
        readModel == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (readModel == null) {
      return const Center(child: Text('Keine Statistikdaten verfuegbar.'));
    }

    final snapshot = _snapshotBuilder.build(
      readModel,
      altersgrenzen: _altersgrenzen,
    );

    return _StammStatisticsView(
      snapshot: snapshot,
      onOpenGroup: _openGroup,
      stammAddress: _stammAddress,
    );
  }
}

class _StammStatisticsView extends StatelessWidget {
  const _StammStatisticsView({
    required this.snapshot,
    required this.onOpenGroup,
    required this.stammAddress,
  });

  final StatisticsSnapshot snapshot;
  final ValueChanged<String> onOpenGroup;
  final String? stammAddress;

  @override
  Widget build(BuildContext context) {
    final hasAgeData = snapshot.ageDistribution.maxCount > 0;
    final hasGenderData = snapshot.gender.any(
      (item) => item.label != 'Ohne Angabe' && item.value > 0,
    );
    final hasConfessionData = snapshot.confessions.isNotEmpty;
    final hasLocationInput = snapshot.memberById.values.any(
      (member) => member.primaryAddress != null,
    );
    final hasStammAddress = (stammAddress ?? '').trim().isNotEmpty;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        StatisticsCard(
          title: snapshot.stammTitle,
          child: StatisticsKpiRow(
            items: [
              StatisticsKpiItem(
                value: '${snapshot.members}',
                label: 'Mitglieder',
                highlight: true,
              ),
              StatisticsKpiItem(
                value: '${snapshot.leaders}',
                label: 'Leitende',
              ),
              StatisticsKpiItem(
                value: '${snapshot.sonstige}',
                label: 'Sonstige',
              ),
            ],
          ),
        ),
        if (snapshot.groups.isNotEmpty) ...[
          const SizedBox(height: 12),
          StatisticsCard(
            title: 'Gruppen',
            padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
            child: StatisticsGroupList(
              items: snapshot.groups,
              onOpenGroup: onOpenGroup,
            ),
          ),
        ],
        const SizedBox(height: 12),
        StatisticsCard(
          title: 'Gruppenverteilung',
          child: GroupDistributionChart(data: snapshot.groupDistributions),
        ),
        if (hasAgeData) ...[
          const SizedBox(height: 12),
          StatisticsCard(
            title: 'Altersverteilung',
            child: AgeDistributionChart(
              data: snapshot.ageDistribution,
              enableInteraction: false,
            ),
          ),
        ],
        if (hasGenderData) ...[
          const SizedBox(height: 12),
          StatisticsCard(
            title: 'Geschlecht',
            child: StatisticsPieLegend(items: snapshot.gender),
          ),
        ],
        if (hasConfessionData) ...[
          const SizedBox(height: 12),
          StatisticsCard(
            title: 'Konfession',
            child: StatisticsPieLegend(items: snapshot.confessions),
          ),
        ],
        if (hasLocationInput || hasStammAddress) ...[
          const SizedBox(height: 12),
          _StatisticsLocationsCard(
            title: 'Standorte',
            members: snapshot.memberById.values.toList(growable: false),
            stammAddress: stammAddress,
          ),
        ],
      ],
    );
  }
}

class _StatisticsLocationsCard extends StatefulWidget {
  const _StatisticsLocationsCard({
    required this.title,
    required this.members,
    required this.stammAddress,
  });

  final String title;
  final List<Mitglied> members;
  final String? stammAddress;

  @override
  State<_StatisticsLocationsCard> createState() =>
      _StatisticsLocationsCardState();
}

class _StatisticsLocationsCardState extends State<_StatisticsLocationsCard> {
  final StatisticsLocationService _locationService =
      StatisticsLocationService();
  late Future<StatisticsResolvedLocations> _future;
  late String _memberSignature;
  String? _stammAddressSignature;

  @override
  void initState() {
    super.initState();
    _memberSignature = _buildMemberSignature(widget.members);
    _stammAddressSignature = _normalizeAddress(widget.stammAddress);
    _future = _locationService.resolveLocations(
      members: widget.members,
      stammAddress: widget.stammAddress,
    );
  }

  @override
  void didUpdateWidget(covariant _StatisticsLocationsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextSignature = _buildMemberSignature(widget.members);
    final nextStammAddress = _normalizeAddress(widget.stammAddress);
    if (nextSignature == _memberSignature &&
        nextStammAddress == _stammAddressSignature) {
      return;
    }
    _memberSignature = nextSignature;
    _stammAddressSignature = nextStammAddress;
    _future = _locationService.resolveLocations(
      members: widget.members,
      stammAddress: widget.stammAddress,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.members.any((member) => member.primaryAddress != null) &&
        _normalizeAddress(widget.stammAddress).isEmpty) {
      return const SizedBox.shrink();
    }

    return FutureBuilder<StatisticsResolvedLocations>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const StatisticsCard(
            title: 'Standorte',
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final resolved =
            snapshot.data ??
            const StatisticsResolvedLocations(
              memberPoints: <LatLng>[],
              stammPoint: null,
            );
        final markers = resolved.memberPoints;
        if (markers.isEmpty && resolved.stammPoint == null) {
          return const SizedBox.shrink();
        }

        return StatisticsMapCard(
          title: widget.title,
          markers: markers,
          stammLocation: resolved.stammPoint,
        );
      },
    );
  }

  String _normalizeAddress(String? value) => (value ?? '').trim();

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
