import 'package:flutter/material.dart';
import 'package:nami/domain/member/member_list_preferences.dart';
import 'package:nami/domain/member/mitglied.dart';
import 'package:nami/domain/member_filters/member_custom_filter.dart';
import 'package:nami/domain/taetigkeit/stufe.dart';
import 'package:nami/presentation/stufe/stufe_visuals.dart';
import 'package:nami/presentation/widgets/member_custom_filter_icons.dart';
import 'package:nami/presentation/widgets/member_list.dart';
import 'package:nami/presentation/widgets/member_list_group_filter_bar.dart';
import 'package:nami/presentation/widgets/member_list_search_bar.dart';

enum MemberFilterOptionsTrigger { tuneButton, listHeader }

class MemberDirectory extends StatefulWidget {
  const MemberDirectory({
    super.key,
    required this.mitglieder,
    this.mitgliedsFilterKeys = const <String, Set<String>>{},
    this.customFilterGroups = const <MemberCustomFilterGroup>[],
    this.showBiberFilter = false,
    this.initialSearch = '',
    this.initialFavourites = const {},
    this.sortKey = MemberSortKey.name,
    this.subtitleMode = MemberSubtitleMode.mitgliedsnummer,
    this.highlightSearchMatches = false,
    this.subtitleTextBuilder,
    this.trailingTextBuilder,
    this.warningBuilder,
    this.enableGroupFilter = true,
    this.hasFilterDeviation = false,
    this.onOpenFilterOptions,
    this.onSearchActivityChanged,
    this.onGroupFilterChanged,
    this.onResetFilters,
    this.onTapMember,
  });
  final List<Mitglied> mitglieder;
  final Map<String, Set<String>> mitgliedsFilterKeys;
  final List<MemberCustomFilterGroup> customFilterGroups;
  final bool showBiberFilter;
  final String initialSearch;
  final Set<String> initialFavourites;
  final MemberSortKey sortKey;
  final MemberSubtitleMode subtitleMode;
  final bool highlightSearchMatches;
  final String? Function(Mitglied mitglied)? subtitleTextBuilder;
  final String? Function(Mitglied mitglied)? trailingTextBuilder;
  final bool Function(Mitglied mitglied)? warningBuilder;
  final bool enableGroupFilter;
  final bool hasFilterDeviation;
  final ValueChanged<MemberFilterOptionsTrigger>? onOpenFilterOptions;
  final ValueChanged<bool>? onSearchActivityChanged;
  final ValueChanged<int>? onGroupFilterChanged;
  final void Function({required bool hadSearch, required int selectedCount})?
  onResetFilters;
  final ValueChanged<String>? onTapMember;

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
    final items = Stufe.values
        .where(
          (stufe) =>
              stufe != Stufe.leitung &&
              (stufe != Stufe.biber || widget.showBiberFilter),
        )
        .map(
          (stufe) => GroupFilterItem(
            keyName: stufe.name,
            label: stufe.displayName,
            chipColor: StufeVisuals.colorFor(stufe),
            semanticLabel: stufe.displayName,
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
            warningBuilder: widget.warningBuilder,
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
          ),
        ),
      ],
    );
  }
}
