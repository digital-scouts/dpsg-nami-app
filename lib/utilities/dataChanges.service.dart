import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:nami/utilities/hive/dataChanges.dart';
import 'package:nami/utilities/hive/settings.dart';
import 'package:nami/utilities/logger.dart';

class DataChangesService {
  final Box<DataChange> _box = Hive.box('dataChanges');

  DataChangesService();

  Future<void> addDataChangeEntry(int id,
      {List<String> changedFields = const [],
      DataChangeAction action = DataChangeAction.unknown}) async {
    sensLog.i('IDS from latest change: $id');
    final entry = DataChange(
        id: id,
        changeDate: DateTime.now(),
        gruppierung: getGruppierungId() ?? 0,
        action: action.value,
        changedFields: changedFields);
    await _box.add(entry);
  }

  List<DataChange> getLatestEntry(
      {Duration duration = const Duration(minutes: 1)}) {
    var now = DateTime.now();
    return getEntriesInRange(now.subtract(duration), now);
  }

  List<DataChange> getEntriesInRange(DateTime start, DateTime end) {
    List<DataChange> entries = [];
    for (int i = 0; i < _box.length; i++) {
      DataChange entry = _box.getAt(i)!;
      if (entry.changeDate.isAfter(start) && entry.changeDate.isBefore(end)) {
        entries.add(entry);
      }
    }
    entries.sort((a, b) => b.changeDate.compareTo(a.changeDate));
    return entries;
  }
}
