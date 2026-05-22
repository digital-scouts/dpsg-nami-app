import 'package:flutter/material.dart';
import 'package:nami/presentation/widgets/statistik_agedistribution.dart';

import '../statistics/statistics_dummy_data.dart';
import '../statistics/statistics_ui.dart';

class StatisticsGroupDetailPage extends StatelessWidget {
  const StatisticsGroupDetailPage({super.key, required this.groupId});

  final String groupId;

  @override
  Widget build(BuildContext context) {
    final group = StatisticsDummyData.groupById(groupId);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(group.name),
            Text(
              '${group.stageLabel} - ${group.members} Mitglieder',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
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
                StatisticsKpiItem(
                  value: '${group.leitende}',
                  label: 'Leitende',
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          StatisticsCard(
            title: 'Altersverteilung',
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: AgeDistributionChart(
                data: StatisticsDummyData.ageDistributionForGroup(group),
                enableInteraction: false,
              ),
            ),
          ),
          const SizedBox(height: 12),
          StatisticsCard(
            title: 'Geschlecht',
            child: StatisticsPieLegend(items: group.gender),
          ),
          const SizedBox(height: 12),
          StatisticsMapCard(title: 'Standorte', markers: group.locations),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
