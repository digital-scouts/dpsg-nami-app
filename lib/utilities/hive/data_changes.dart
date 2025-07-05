import 'package:hive_ce_flutter/hive_flutter.dart';

part 'data_changes.g.dart';

// flutter packages pub run build_runner build

@HiveType(typeId: 0)
class DataChange extends HiveObject {
  @HiveField(0)
  int id;

  @HiveField(1)
  DateTime changeDate;

  @HiveField(2)
  int gruppierung;

  @HiveField(3)
  int action;

  @HiveField(4)
  List<String> changedFields;

  DataChange({
    required this.id,
    required this.changeDate,
    required this.gruppierung,
    required this.action,
    required this.changedFields,
  });

  DataChangeAction get actionEnum {
    switch (action) {
      case 0:
        return DataChangeAction.create;
      case 1:
        return DataChangeAction.update;
      case 2:
        return DataChangeAction.delete;
      default:
        return DataChangeAction.unknown;
    }
  }
}

enum DataChangeAction {
  create(0),
  update(1),
  delete(2),
  unknown(3);

  const DataChangeAction(this.value);
  final int value;

  @override
  String toString() {
    switch (this) {
      case DataChangeAction.create:
        return 'Erstellt';
      case DataChangeAction.update:
        return 'Aktualisiert';
      case DataChangeAction.delete:
        return 'Gelöscht';
      default:
        return 'Unbekannt';
    }
  }
}
