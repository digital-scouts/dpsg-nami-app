import 'package:flutter/foundation.dart';
import 'package:hive_ce_flutter/adapters.dart';
import 'package:nami/utilities/hive/ausbildung.dart';
import 'package:nami/utilities/hive/data_changes.dart';
import 'package:nami/utilities/hive/mitglied.dart';
import 'package:nami/utilities/hive/taetigkeit.dart';

/// Abstrakte Klasse für Hive-Service
abstract class HiveService {
  // Getter für verschiedene Boxen
  Box<Mitglied> get memberBox;
  Box<Taetigkeit> get taetigkeitBox;
  Box<Ausbildung> get ausbildungBox;
  Box<DataChange> get dataChangesBox;
  Box<Map> get satzungBox;
  Box<Map> get aiChatMessagesBox;
  Box get filterBox;

  // Convenience-Methoden
  List<Mitglied> getAllMembers();
  List<Taetigkeit> getAllTaetigkeiten();
  List<Ausbildung> getAllAusbildungen();
  List<DataChange> getAllDataChanges();

  // Listener-Methoden
  void addMemberBoxListener(VoidCallback listener);
  void removeMemberBoxListener(VoidCallback listener);

  // Cleanup
  Future<void> closeAllBoxes();
}

/// Konkrete Implementierung des HiveService
class HiveServiceImpl implements HiveService {
  @override
  Box<Mitglied> get memberBox => Hive.box<Mitglied>('members');

  @override
  Box<Taetigkeit> get taetigkeitBox => Hive.box<Taetigkeit>('taetigkeit');

  @override
  Box<Ausbildung> get ausbildungBox => Hive.box<Ausbildung>('ausbildung');

  @override
  Box<DataChange> get dataChangesBox => Hive.box<DataChange>('dataChanges');

  @override
  Box<Map> get satzungBox => Hive.box<Map>('satzung_db');

  @override
  Box<Map> get aiChatMessagesBox => Hive.box<Map>('ai_chat_messages');

  @override
  Box get filterBox => Hive.box('filterBox');

  @override
  List<Mitglied> getAllMembers() {
    return memberBox.values.toList().cast<Mitglied>();
  }

  @override
  List<Taetigkeit> getAllTaetigkeiten() {
    return taetigkeitBox.values.toList().cast<Taetigkeit>();
  }

  @override
  List<Ausbildung> getAllAusbildungen() {
    return ausbildungBox.values.toList().cast<Ausbildung>();
  }

  @override
  List<DataChange> getAllDataChanges() {
    return dataChangesBox.values.toList().cast<DataChange>();
  }

  @override
  void addMemberBoxListener(VoidCallback listener) {
    memberBox.listenable().addListener(listener);
  }

  @override
  void removeMemberBoxListener(VoidCallback listener) {
    memberBox.listenable().removeListener(listener);
  }

  @override
  Future<void> closeAllBoxes() async {
    await Future.wait([
      memberBox.close(),
      taetigkeitBox.close(),
      ausbildungBox.close(),
      dataChangesBox.close(),
      satzungBox.close(),
      aiChatMessagesBox.close(),
      filterBox.close(),
    ]);
  }
}

/// Mock-Implementierung für Tests
class MockHiveService implements HiveService {
  final Box<Mitglied> _memberBox;
  final Box<Taetigkeit> _taetigkeitBox;
  final Box<Ausbildung> _ausbildungBox;
  final Box<DataChange> _dataChangesBox;
  final Box<Map> _satzungBox;
  final Box<Map> _aiChatMessagesBox;
  final Box _filterBox;

  MockHiveService({
    required Box<Mitglied> memberBox,
    required Box<Taetigkeit> taetigkeitBox,
    required Box<Ausbildung> ausbildungBox,
    required Box<DataChange> dataChangesBox,
    required Box<Map> satzungBox,
    required Box<Map> aiChatMessagesBox,
    required Box filterBox,
  }) : _memberBox = memberBox,
       _taetigkeitBox = taetigkeitBox,
       _ausbildungBox = ausbildungBox,
       _dataChangesBox = dataChangesBox,
       _satzungBox = satzungBox,
       _aiChatMessagesBox = aiChatMessagesBox,
       _filterBox = filterBox;

  @override
  Box<Mitglied> get memberBox => _memberBox;

  @override
  Box<Taetigkeit> get taetigkeitBox => _taetigkeitBox;

  @override
  Box<Ausbildung> get ausbildungBox => _ausbildungBox;

  @override
  Box<DataChange> get dataChangesBox => _dataChangesBox;

  @override
  Box<Map> get satzungBox => _satzungBox;

  @override
  Box<Map> get aiChatMessagesBox => _aiChatMessagesBox;

  @override
  Box get filterBox => _filterBox;

  @override
  List<Mitglied> getAllMembers() {
    return memberBox.values.toList().cast<Mitglied>();
  }

  @override
  List<Taetigkeit> getAllTaetigkeiten() {
    return taetigkeitBox.values.toList().cast<Taetigkeit>();
  }

  @override
  List<Ausbildung> getAllAusbildungen() {
    return ausbildungBox.values.toList().cast<Ausbildung>();
  }

  @override
  List<DataChange> getAllDataChanges() {
    return dataChangesBox.values.toList().cast<DataChange>();
  }

  @override
  void addMemberBoxListener(VoidCallback listener) {
    memberBox.listenable().addListener(listener);
  }

  @override
  void removeMemberBoxListener(VoidCallback listener) {
    memberBox.listenable().removeListener(listener);
  }

  @override
  Future<void> closeAllBoxes() async {
    // Mock implementation - no actual closing needed
  }
}

/// Globale HiveService-Instanz
HiveService hiveService = HiveServiceImpl();

/// Initialisiert den HiveService
void initializeHiveService() {
  // Für die Produktion verwenden wir die Standard-Implementierung
  // Für Tests kann diese Funktion überschrieben werden
  hiveService = HiveServiceImpl();
}

// Wrapper-Funktionen für Rückwärtskompatibilität
Box<Mitglied> get memberBox => hiveService.memberBox;
Box<Taetigkeit> get taetigkeitBox => hiveService.taetigkeitBox;
Box<Ausbildung> get ausbildungBox => hiveService.ausbildungBox;
Box<DataChange> get dataChangesBox => hiveService.dataChangesBox;
Box<Map> get satzungBox => hiveService.satzungBox;
Box<Map> get aiChatMessagesBox => hiveService.aiChatMessagesBox;
Box get filterBox => hiveService.filterBox;

List<Mitglied> getAllMembers() => hiveService.getAllMembers();
List<Taetigkeit> getAllTaetigkeiten() => hiveService.getAllTaetigkeiten();
List<Ausbildung> getAllAusbildungen() => hiveService.getAllAusbildungen();
List<DataChange> getAllDataChanges() => hiveService.getAllDataChanges();
