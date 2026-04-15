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
    this.onOpenFilterOptions,
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
  final VoidCallback? onOpenFilterOptions;
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
    setState(() {
      search = '';
      selectedFilterKeys.clear();
    });
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
            imageAssetPath: StufeVisuals.assetFor(stufe),
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
          iconData: memberCustomFilterIconForKey(group.iconKey),
          semanticLabel: group.displayChipLabel,
          textLabel: group.displayChipLabel,
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
          },
          itemSize: 54,
        ),
        MemberSearchBar(
          initial: search,
          onChanged: (v) => setState(() => search = v),
          onTunePressed: widget.onOpenFilterOptions,
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
            onTapMember: (id) {
              widget.onTapMember?.call(id);
            },
          ),
        ),
      ],
    );
  }
}
