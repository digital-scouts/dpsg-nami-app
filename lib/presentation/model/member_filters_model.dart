import 'package:flutter/material.dart';

import '../../domain/member/member_list_preferences.dart';
import '../../domain/member_filters/member_custom_filter.dart';
import '../../domain/member_filters/member_filter_repository.dart';

class MemberFiltersModel extends ChangeNotifier {
  MemberFiltersModel(this._repository);

  final MemberFilterRepository _repository;

  int? _layerId;
  bool _isLoading = false;
  MemberFilterLayerSettings _settings = const MemberFilterLayerSettings();

  int? get layerId => _layerId;
  bool get isLoading => _isLoading;
  MemberSortKey get sortKey => _settings.sortKey;
  MemberSubtitleMode get subtitleMode => _settings.subtitleMode;
  List<MemberCustomFilterGroup> get customGroups => _settings.customGroups;

  Future<void> ensureLoadedForLayer(int? layerId) async {
    if (layerId == null || (_layerId == layerId && !_isLoading)) {
      return;
    }

    _isLoading = true;
    notifyListeners();
    final loaded = await _repository.loadForLayer(layerId);
    _layerId = layerId;
    _settings = _ensureDefaults(loaded);
    _isLoading = false;
    notifyListeners();
    await _persist();
  }

  Future<void> setSortKey(MemberSortKey sortKey) async {
    _settings = _settings.copyWith(sortKey: sortKey);
    notifyListeners();
    await _persist();
  }

  Future<void> setSubtitleMode(MemberSubtitleMode subtitleMode) async {
    _settings = _settings.copyWith(subtitleMode: subtitleMode);
    notifyListeners();
    await _persist();
  }

  Future<void> setCustomGroupActive(String groupId, bool isActive) async {
    _settings = _settings.copyWith(
      customGroups: _settings.customGroups
          .map(
            (group) => group.id == groupId
                ? group.copyWith(isActive: isActive)
                : group,
          )
          .toList(growable: false),
    );
    notifyListeners();
    await _persist();
  }

  Future<void> saveCustomGroup(MemberCustomFilterGroup group) async {
    final nextGroups = <MemberCustomFilterGroup>[];
    var replaced = false;
    for (final existing in _settings.customGroups) {
      if (existing.id == group.id) {
        nextGroups.add(group);
        replaced = true;
      } else {
        nextGroups.add(existing);
      }
    }
    if (!replaced) {
      nextGroups.add(group);
    }
    _settings = _settings.copyWith(customGroups: nextGroups);
    notifyListeners();
    await _persist();
  }

  Future<void> deleteCustomGroup(String groupId) async {
    _settings = _settings.copyWith(
      customGroups: _settings.customGroups
          .where((group) => group.id != groupId)
          .toList(growable: false),
    );
    notifyListeners();
    await _persist();
  }

  MemberFilterLayerSettings _ensureDefaults(
    MemberFilterLayerSettings settings,
  ) {
    if (settings.defaultsInitialisiert) {
      return settings;
    }
    return settings.copyWith(
      customGroups: <MemberCustomFilterGroup>[
        ...settings.customGroups,
        MemberCustomFilterGroup.defaultRest,
      ],
      defaultsInitialisiert: true,
    );
  }

  Future<void> _persist() async {
    final currentLayerId = _layerId;
    if (currentLayerId == null) {
      return;
    }
    await _repository.saveForLayer(currentLayerId, _settings);
  }
}
