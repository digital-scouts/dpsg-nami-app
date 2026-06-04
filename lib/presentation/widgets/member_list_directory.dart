import 'package:flutter/material.dart';
import 'package:nami/domain/member/member_list_preferences.dart';
import 'package:nami/domain/member/mitglied.dart';
import 'package:nami/domain/member_filters/member_custom_filter.dart';
import 'package:nami/domain/member_filters/member_fixed_filter_groups.dart';
import 'package:nami/domain/taetigkeit/roles.dart';
import 'package:nami/presentation/stufe/stufe_visuals.dart';
import 'package:nami/presentation/widgets/member_custom_filter_icons.dart';
import 'package:nami/presentation/widgets/member_list.dart';
import 'package:nami/presentation/widgets/member_list_group_filter_bar.dart';
import 'package:nami/presentation/widgets/member_list_search_bar.dart';

enum MemberFilterOptionsTrigger { tuneButton, listHeader }

class MemberFixedFilterGroup {
  const MemberFixedFilterGroup({
    required this.keyName,
    required this.label,
    required this.groupType,
  });

  final String keyName;
  final String label;
  final String groupType;
}

class MemberDirectory extends StatefulWidget {
  const MemberDirectory({
    super.key,
    required this.mitglieder,
    this.mitgliedsFilterKeys = const <String, Set<String>>{},
    this.fixedFilterGroups = const <MemberFixedFilterGroup>[],
    this.customFilterGroups = const <MemberCustomFilterGroup>[],
    this.initialSearch = '',
    this.initialFavourites = const {},
    this.sortKey = MemberSortKey.name,
    this.subtitleMode = MemberSubtitleMode.mitgliedsnummer,
    this.highlightSearchMatches = false,
    this.subtitleTextBuilder,
    this.trailingTextBuilder,
    this.roleCategoryBuilder,
    this.warningBuilder,
    this.lastUpdateAt,
    this.isRefreshing = false,
    this.enableGroupFilter = true,
    this.hasFilterDeviation = false,
    this.onOpenFilterOptions,
    this.onSearchActivityChanged,
    this.onGroupFilterChanged,
    this.onResetFilters,
    this.onTapMember,
    this.onRefresh,
  });
  final List<Mitglied> mitglieder;
  final Map<String, Set<String>> mitgliedsFilterKeys;
  final List<MemberFixedFilterGroup> fixedFilterGroups;
  final List<MemberCustomFilterGroup> customFilterGroups;
  final String initialSearch;
  final Set<String> initialFavourites;
  final MemberSortKey sortKey;
  final MemberSubtitleMode subtitleMode;
  final bool highlightSearchMatches;
  final String? Function(Mitglied mitglied)? subtitleTextBuilder;
  final String? Function(Mitglied mitglied)? trailingTextBuilder;
  final RoleCategory? Function(Mitglied mitglied)? roleCategoryBuilder;
  final bool Function(Mitglied mitglied)? warningBuilder;
  final DateTime? lastUpdateAt;
  final bool isRefreshing;
  final bool enableGroupFilter;
  final bool hasFilterDeviation;
  final ValueChanged<MemberFilterOptionsTrigger>? onOpenFilterOptions;
  final ValueChanged<bool>? onSearchActivityChanged;
  final ValueChanged<int>? onGroupFilterChanged;
  final void Function({required bool hadSearch, required int selectedCount})?
  onResetFilters;
  final ValueChanged<String>? onTapMember;
  final Future<void> Function()? onRefresh;

  @override
  State<MemberDirectory> createState() => _MemberDirectoryState();
}

class _MemberDirectoryState extends State<MemberDirectory> {
  late String search;
  late Set<String> selectedFilterKeys;
  late Set<String> favourites;

  @override
  void initState() {
    super.initState();
    search = widget.initialSearch;
    selectedFilterKeys = <String>{};
    favourites = Set<String>.from(widget.initialFavourites);
  }

  @override
  void didUpdateWidget(covariant MemberDirectory oldWidget) {
    super.didUpdateWidget(oldWidget);
    final availableKeys = _buildItems().map((item) => item.keyName).toSet();
    final nextSelectedKeys = selectedFilterKeys.intersection(availableKeys);
    if (nextSelectedKeys.length != selectedFilterKeys.length) {
      setState(() {
        selectedFilterKeys = nextSelectedKeys;
      });
    }
  }

  void toggleFavourite(String id) {
    setState(() {
      if (favourites.contains(id)) {
        favourites.remove(id);
      } else {
        favourites.add(id);
      }
    });
  }

  void _resetFilters() {
    final hadSearch = search.trim().isNotEmpty;
    final selectedCount = selectedFilterKeys.length;
    setState(() {
      search = '';
      selectedFilterKeys.clear();
    });
    if (hadSearch || selectedCount > 0) {
      widget.onResetFilters?.call(
        hadSearch: hadSearch,
        selectedCount: selectedCount,
      );
    }
  }

  void _updateSearch(String value) {
    final hadSearch = search.trim().isNotEmpty;
    final hasSearch = value.trim().isNotEmpty;
    setState(() => search = value);
    if (hadSearch != hasSearch) {
      widget.onSearchActivityChanged?.call(hasSearch);
    }
  }

  List<GroupFilterItem> _buildItems() {
    final items = widget.fixedFilterGroups
        .map(
          (group) => GroupFilterItem(
            keyName: group.keyName,
            label: group.label,
            chipColor: _resolveChipColor(group.groupType),
            semanticLabel: group.label,
          ),
        )
        .toList(growable: true);

    for (final group in widget.customFilterGroups.where(
      (group) => group.isActive,
    )) {
      items.add(
        GroupFilterItem(
          keyName: group.filterKey,
          label: group.displayChipLabel,
          iconData: memberCustomFilterIconForKey(group.iconKey),
          semanticLabel: group.displayChipLabel,
        ),
      );
    }
    return items;
  }

  @override
  Widget build(BuildContext context) {
    final items = _buildItems();

    return Column(
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border(
              bottom: BorderSide(color: Theme.of(context).colorScheme.outline),
            ),
          ),
          child: Column(
            children: [
              MemberSearchBar(
                initial: search,
                onChanged: _updateSearch,
                showFilterIndicator: widget.hasFilterDeviation,
                onTunePressed: () => widget.onOpenFilterOptions?.call(
                  MemberFilterOptionsTrigger.tuneButton,
                ),
              ),
              GroupFilterBar(
                items: items,
                selectedKeys: selectedFilterKeys,
                onChanged: (next) {
                  if (!widget.enableGroupFilter) {
                    return;
                  }
                  setState(() {
                    selectedFilterKeys = next;
                  });
                  widget.onGroupFilterChanged?.call(selectedFilterKeys.length);
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: MemberList(
            mitglieder: widget.mitglieder,
            searchString: search,
            highlightSearchMatches: widget.highlightSearchMatches,
            sortKey: widget.sortKey,
            subtitleMode: widget.subtitleMode,
            subtitleTextBuilder: widget.subtitleTextBuilder,
            trailingTextBuilder: widget.trailingTextBuilder,
            roleCategoryBuilder: widget.roleCategoryBuilder,
            warningBuilder: widget.warningBuilder,
            lastUpdateAt: widget.lastUpdateAt,
            isRefreshing: widget.isRefreshing,
            favourites: favourites,
            selectedFilterKeys: widget.enableGroupFilter
                ? selectedFilterKeys
                : const <String>{},
            mitgliedsFilterKeys: widget.mitgliedsFilterKeys,
            onResetFilters: _resetFilters,
            onToggleFavourite: toggleFavourite,
            onTapSortHint: () => widget.onOpenFilterOptions?.call(
              MemberFilterOptionsTrigger.listHeader,
            ),
            onTapMember: (id) {
              widget.onTapMember?.call(id);
            },
            onRefresh: widget.onRefresh,
          ),
        ),
      ],
    );
  }

  Color? _resolveChipColor(String gruppenTyp) {
    final stufe = MemberFixedFilterGroups.stufeForGruppenTyp(gruppenTyp);
    if (stufe == null) {
      return null;
    }

    return StufeVisuals.colorFor(stufe);
  }
}
