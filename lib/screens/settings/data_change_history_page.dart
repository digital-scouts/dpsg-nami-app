import 'package:flutter/material.dart';
import 'package:nami/screens/widgets/data_change_history.dart';
import 'package:nami/utilities/dataChanges.service.dart';

class DataChangeHistoryPage extends StatelessWidget {
  const DataChangeHistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final changes = DataChangesService().getLatestEntry(
      duration: const Duration(days: 30),
    );

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: DataChangeHistory(
          changes: changes,
          title: 'Änderungen der letzten 30 Tage',
          isDialog: false,
          showDate: false,
        ),
      ),
    );
  }
}
