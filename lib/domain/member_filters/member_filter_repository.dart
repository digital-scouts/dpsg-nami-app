import '../member/member_list_preferences.dart';
import 'member_custom_filter.dart';

class MemberFilterLayerSettings {
  const MemberFilterLayerSettings({
    this.sortKey = MemberSortKey.name,
    this.subtitleMode = MemberSubtitleMode.mitgliedsnummer,
    this.customGroups = const <MemberCustomFilterGroup>[],
    this.defaultsInitialisiert = false,
  });

  final MemberSortKey sortKey;
  final MemberSubtitleMode subtitleMode;
  final List<MemberCustomFilterGroup> customGroups;
  final bool defaultsInitialisiert;

  MemberFilterLayerSettings copyWith({
    MemberSortKey? sortKey,
    MemberSubtitleMode? subtitleMode,
    List<MemberCustomFilterGroup>? customGroups,
    bool? defaultsInitialisiert,
  }) => MemberFilterLayerSettings(
    sortKey: sortKey ?? this.sortKey,
    subtitleMode: subtitleMode ?? this.subtitleMode,
    customGroups: customGroups ?? this.customGroups,
    defaultsInitialisiert: defaultsInitialisiert ?? this.defaultsInitialisiert,
  );

  Map<String, dynamic> toJson() => {
    'sortKey': sortKey.name,
    'subtitleMode': subtitleMode.name,
    'customGroups': customGroups
        .map((group) => group.toJson())
        .toList(growable: false),
    'defaultsInitialisiert': defaultsInitialisiert,
  };

  factory MemberFilterLayerSettings.fromJson(Map<String, dynamic> json) {
    final sortKeyName = json['sortKey'] as String?;
    final subtitleModeName = json['subtitleMode'] as String?;
    final customGroupsJson = json['customGroups'];
    return MemberFilterLayerSettings(
      sortKey: MemberSortKey.values.firstWhere(
        (value) => value.name == sortKeyName,
        orElse: () => MemberSortKey.name,
      ),
      subtitleMode: MemberSubtitleMode.values.firstWhere(
        (value) => value.name == subtitleModeName,
        orElse: () => MemberSubtitleMode.mitgliedsnummer,
      ),
      customGroups: customGroupsJson is List
          ? customGroupsJson
                .whereType<Map<String, dynamic>>()
                .map(MemberCustomFilterGroup.fromJson)
                .toList(growable: false)
          : const <MemberCustomFilterGroup>[],
      defaultsInitialisiert: json['defaultsInitialisiert'] as bool? ?? false,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is MemberFilterLayerSettings &&
        other.sortKey == sortKey &&
        other.subtitleMode == subtitleMode &&
        _listEquals(other.customGroups, customGroups) &&
        other.defaultsInitialisiert == defaultsInitialisiert;
  }

  @override
  int get hashCode => Object.hash(
    sortKey,
    subtitleMode,
    Object.hashAll(customGroups),
    defaultsInitialisiert,
  );

  static bool _listEquals<T>(List<T> a, List<T> b) {
    if (identical(a, b)) {
      return true;
    }
    if (a.length != b.length) {
      return false;
    }
    for (var index = 0; index < a.length; index += 1) {
      if (a[index] != b[index]) {
        return false;
      }
    }
    return true;
  }
}

abstract class MemberFilterRepository {
  Future<MemberFilterLayerSettings> loadForLayer(int layerId);
  Future<void> saveForLayer(int layerId, MemberFilterLayerSettings settings);
}
