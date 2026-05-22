import 'package:flutter/material.dart';
import 'package:nami/presentation/widgets/statistik_agedistribution.dart';
import 'package:nami/presentation/widgets/statistik_groupdistribution.dart';

import '../navigation/app_router.dart';
import '../statistics/statistics_dummy_data.dart';
import '../statistics/statistics_ui.dart';

class StatisticsPage extends StatefulWidget {
  const StatisticsPage({super.key});

  @override
  State<StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends State<StatisticsPage> {
  void _openGroup(String groupId) {
    Navigator.of(context).pushNamed(
      AppRoutes.statisticsGroupDetail,
      arguments: groupId,
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Text(
                  'Statistik',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ],
            ),
          ),
          const TabBar(
            indicatorSize: TabBarIndicatorSize.tab,
            tabs: [
              Tab(text: 'Stamm'),
              Tab(text: 'Global'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _StammStatisticsView(onOpenGroup: _openGroup),
                const _GlobalStatisticsView(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StammStatisticsView extends StatelessWidget {
  const _StammStatisticsView({required this.onOpenGroup});

  final ValueChanged<String> onOpenGroup;

  @override
  Widget build(BuildContext context) {
    final summary = StatisticsDummyData.summary;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        StatisticsCard(
          title: StatisticsDummyData.stammTitle,
          child: StatisticsKpiRow(
            items: [
              StatisticsKpiItem(
                value: '${summary.mitglieder}',
                label: 'Mitglieder',
                highlight: true,
              ),
              StatisticsKpiItem(
                value: '${summary.sonstige}',
                label: 'Sonstige',
              ),
              StatisticsKpiItem(
                value: '${summary.leitende}',
                label: 'Leitende',
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        StatisticsCard(
          title: 'Gruppe',
          padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
          child: StatisticsGroupList(
            items: StatisticsDummyData.groups,
            onOpenGroup: onOpenGroup,
          ),
        ),
        const SizedBox(height: 12),
        StatisticsCard(
          title: 'Gruppenverteilung',
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: GroupDistributionChart(
              data: StatisticsDummyData.stammGroupDistributionData(),
            ),
          ),
        ),
        const SizedBox(height: 12),
        StatisticsCard(
          title: 'Altersverteilung',
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: AgeDistributionChart(
              data: StatisticsDummyData.stammAgeDistributionData(),
              enableInteraction: false,
            ),
          ),
        ),
        const SizedBox(height: 12),
        StatisticsCard(
          title: 'Geschlecht',
          child: StatisticsPieLegend(items: StatisticsDummyData.geschlecht),
        ),
        const SizedBox(height: 12),
        StatisticsCard(
          title: 'Konfession',
          child: StatisticsPieLegend(items: StatisticsDummyData.konfession),
        ),
        const SizedBox(height: 12),
        StatisticsMapCard(
          title: 'Standorte',
          markers: StatisticsDummyData.stammLocations,
        ),
      ],
    );
  }
}

class _GlobalStatisticsView extends StatelessWidget {
  const _GlobalStatisticsView();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        const StatisticsOptInCard(),
      ],
    );
  }
}
