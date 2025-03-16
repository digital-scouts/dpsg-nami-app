import 'package:flutter/material.dart';
import 'package:hive_ce/hive.dart';
import 'package:nami/utilities/hive/dataChanges.dart';
import 'package:nami/utilities/hive/mitglied.dart';

class DataChangeHistory extends StatelessWidget {
  final List<DataChange> changes;
  final String title;
  final bool isDialog;
  final bool showDate;

  const DataChangeHistory(
      {super.key,
      required this.changes,
      required this.title,
      this.isDialog = false,
      this.showDate = true});

  @override
  Widget build(BuildContext context) {
    Box<Mitglied> membersBox = Hive.box('members');

    // Änderungen nach Datum gruppieren
    Map<String, List<DataChange>> groupedChanges = {};
    for (var change in changes) {
      String date = change.changeDate.toLocal().toString().split(' ')[0];
      if (groupedChanges.containsKey(date)) {
        groupedChanges[date]!.add(change);
      } else {
        groupedChanges[date] = [change];
      }
    }

    final content = SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: groupedChanges.entries.map((entry) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!showDate)
                Text(
                  entry.key,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ...entry.value.map((change) {
                final member = membersBox.get(change.id);
                return ListTile(
                  title: Text(
                      '${member?.vorname ?? 'Unbekannt'} ${member?.nachname ?? ''}'),
                  subtitle: Text(
                      '${change.actionEnum.toString().split('.').last} ${change.changedFields.isNotEmpty ? ':' : ''} ${change.changedFields.join(', ')}'),
                );
              }),
            ],
          );
        }).toList(),
      ),
    );

    if (isDialog) {
      return AlertDialog(
        title: Text(title),
        content: content,
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('OK'),
          ),
        ],
      );
    } else {
      return Scaffold(
        appBar: AppBar(title: Text(title)),
        body: Padding(
          padding: const EdgeInsets.all(8.0),
          child: content,
        ),
      );
    }
  }
}
