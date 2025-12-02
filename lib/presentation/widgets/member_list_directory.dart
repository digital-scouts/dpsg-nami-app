import 'package:flutter/material.dart';
import 'package:nami/domain/member/mitglied.dart';
import 'package:nami/domain/member/stufe.dart';
import 'package:nami/presentation/widgets/member_list.dart';
import 'package:nami/presentation/widgets/member_list_group_filter_bar.dart';
import 'package:nami/presentation/widgets/member_list_search_bar.dart';
import 'package:nami/presentation/widgets/member_list_tile.dart';

class MemberDirectory extends StatefulWidget {
  const MemberDirectory({
    super.key,
    required this.mitglieder,
    this.initialSearch = '',
    this.initialStufen = const {},
    this.initialFavourites = const {},
    this.sortKey = MemberSortKey.name,
    this.subtitleMode = MemberSubtitleMode.mitgliedsnummer,
  });
  final List<Mitglied> mitglieder;
  final String initialSearch;
  final Set<Stufe> initialStufen;
  final Set<String> initialFavourites;
  final MemberSortKey sortKey;
  final MemberSubtitleMode subtitleMode;

  @override
  State<MemberDirectory> createState() => _MemberDirectoryState();
}

class _MemberDirectoryState extends State<MemberDirectory> {
  late String search;
  late Set<Stufe> selectedStufen;
  late Set<String> favourites;

  @override
  void initState() {
    super.initState();
    search = widget.initialSearch;
    selectedStufen = Set<Stufe>.from(widget.initialStufen);
    favourites = Set<String>.from(widget.initialFavourites);
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

  @override
  Widget build(BuildContext context) {
    final items = Stufe.values
        .map(
          (s) => GroupFilterItem(
            keyName: s.name,
            imageAssetPath: s.imagePath,
            semanticLabel: s.displayName,
          ),
        )
        .toList();

    return Column(
      children: [
        GroupFilterBar(
          items: items,
          selectedKeys: selectedStufen.map((e) => e.name).toSet(),
          onChanged: (next) {
            setState(() {
              selectedStufen
                ..clear()
                ..addAll(Stufe.values.where((s) => next.contains(s.name)));
            });
          },
          itemSize: 54,
        ),
        MemberSearchBar(
          initial: search,
          onChanged: (v) => setState(() => search = v),
        ),
        Expanded(
          child: MemberList(
            mitglieder: widget.mitglieder,
            searchString: search,
            sortKey: widget.sortKey,
            subtitleMode: widget.subtitleMode,
            favourites: favourites,
            stufenFilter: selectedStufen,
            onToggleFavourite: toggleFavourite,
            onTapMember: (id) {
              // TODO: Handle member tap
              debugPrint('Mitglied $id angetippt');
            },
          ),
        ),
      ],
    );
  }
}
