import 'package:flutter/foundation.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:nami/utilities/hive/hive_service.dart';
import 'package:nami/utilities/hive/mitglied.dart';
import 'package:nami/utilities/hive/settings.dart';

/// Service für Mitglieder-Datenoperationen
abstract class MemberService {
  List<Mitglied> getAllMembers();
  Stream<List<Mitglied>> getMembersStream();
  void addToFavorites(int memberNumber);
  void removeFromFavorites(int memberNumber);
  bool isFavorite(int memberNumber);
  List<int> getFavoritesList();

  /// Registriere einen Listener für Änderungen
  void addListener(VoidCallback listener);
  void removeListener(VoidCallback listener);
}

/// Hive-basierte Implementierung des MemberService
class HiveMemberService implements MemberService {
  final Box<Mitglied> _memberBox;

  HiveMemberService({Box<Mitglied>? memberBox})
    : _memberBox = memberBox ?? hiveService.memberBox;

  @override
  List<Mitglied> getAllMembers() {
    return _memberBox.values.toList().cast<Mitglied>();
  }

  @override
  Stream<List<Mitglied>> getMembersStream() {
    return Stream.fromIterable([getAllMembers()]);
  }

  @override
  void addToFavorites(int memberNumber) {
    addFavouriteList(memberNumber);
  }

  @override
  void removeFromFavorites(int memberNumber) {
    removeFavouriteList(memberNumber);
  }

  @override
  bool isFavorite(int memberNumber) {
    return getFavouriteList().contains(memberNumber);
  }

  @override
  List<int> getFavoritesList() {
    return getFavouriteList();
  }

  @override
  void addListener(VoidCallback listener) {
    _memberBox.listenable().addListener(listener);
  }

  @override
  void removeListener(VoidCallback listener) {
    _memberBox.listenable().removeListener(listener);
  }

  /// Listenable für Änderungen an der Member Box
  ValueListenable<Box<Mitglied>> get listenable => _memberBox.listenable();
}
