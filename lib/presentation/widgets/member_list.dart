import 'package:flutter/material.dart';
import 'package:nami/domain/member/member_utils.dart';
import 'package:nami/domain/member/mitglied.dart';
import 'package:nami/domain/taetigkeit/stufe.dart';
import 'package:nami/presentation/widgets/member_list_tile.dart';

class _FilteredMemberEntry {
  const _FilteredMemberEntry({required this.mitglied, this.subtitleHighlight});

  final Mitglied mitglied;
  final MemberSubtitleHighlight? subtitleHighlight;
}

class MemberListSettingsHandler extends ChangeNotifier {
  MemberListSettingsHandler({String initial = ''}) : _searchString = initial;
  String _searchString;
  String get searchString => _searchString;
  void updateSearchString(String value) {
    _searchString = value.trim();
    notifyListeners();
  }
}

enum MemberSortKey { age, group, name, vorname, memberTime }

class MemberList extends StatelessWidget {
  const MemberList({
    super.key,
    required this.mitglieder,
    this.searchString = '',
    this.highlightSearchMatches = false,
    this.sortKey = MemberSortKey.name,
    this.subtitleMode = MemberSubtitleMode.mitgliedsnummer,
    this.subtitleTextBuilder,
    this.trailingTextBuilder,
    this.favourites = const {},
    this.stufenFilter = const {},
    this.onToggleFavourite,
    this.onTapMember,
  });
  final List<Mitglied> mitglieder;
  final String searchString;
  final bool highlightSearchMatches;
  final MemberSortKey sortKey;
  final MemberSubtitleMode subtitleMode;
  final String? Function(Mitglied mitglied)? subtitleTextBuilder;
  final String? Function(Mitglied mitglied)? trailingTextBuilder;
  final Set<String> favourites;
  final Set<Stufe> stufenFilter;
  final ValueChanged<String>? onToggleFavourite;
  final ValueChanged<String>? onTapMember;

  @override
  Widget build(BuildContext context) {
    final search = searchString.toLowerCase();
    final filteredSearch = search.isEmpty
        ? mitglieder
              .map((mitglied) => _FilteredMemberEntry(mitglied: mitglied))
              .toList(growable: false)
        : mitglieder
              .map((mitglied) => _resolveFilteredMember(mitglied, search))
              .whereType<_FilteredMemberEntry>()
              .toList(growable: false);

    final filtered = stufenFilter.isEmpty
        ? filteredSearch
        : filteredSearch.where((entry) {
            // TODO: Aktueller Filter arbeitet noch auf Stufen aus Taetigkeiten; fuer Ticket 6 auf echte Arbeitskontext-Gruppen umstellen.
            // Nutze alle aktiven Tätigkeiten für den Filter (nicht nur neueste)
            final aktiveStufen = entry.mitglied.taetigkeiten
                .where((t) => t.istAktiv)
                .map((t) => t.stufe)
                .toSet();
            return aktiveStufen.any(stufenFilter.contains);
          }).toList();

    filtered.sort((a, b) {
      final first = a.mitglied;
      final second = b.mitglied;
      switch (sortKey) {
        case MemberSortKey.age:
          // Ältere zuerst (früheres Geburtsdatum)
          return first.geburtsdatum.compareTo(second.geburtsdatum);
        case MemberSortKey.group:
          final sa =
              MemberUtils.aktiveStufe(first)?.index ?? Stufe.values.length + 1;
          final sb =
              MemberUtils.aktiveStufe(second)?.index ?? Stufe.values.length + 1;
          return sa.compareTo(sb);
        case MemberSortKey.name:
          final ln = first.nachname.compareTo(second.nachname);
          if (ln != 0) return ln;
          return first.vorname.compareTo(second.vorname);
        case MemberSortKey.vorname:
          final fn = first.vorname.compareTo(second.vorname);
          if (fn != 0) return fn;
          return first.nachname.compareTo(second.nachname);
        case MemberSortKey.memberTime:
          // Längere Mitgliedschaft zuerst (früheres Eintrittsdatum)
          return first.eintrittsdatum.compareTo(second.eintrittsdatum);
      }
    });

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: filtered.length + 1,
      itemBuilder: (ctx, i) {
        if (i == filtered.length) {
          return ListTile(
            title: Center(
              child: Text(
                filtered.isEmpty
                    ? 'Keine Mitglieder gefunden'
                    : 'Mitglieder: ${filtered.length}',
              ),
            ),
          );
        }
        final entry = filtered[i];
        final m = entry.mitglied;
        return MemberListTile(
          mitglied: m,
          isFavourite: favourites.contains(m.mitgliedsnummer),
          subtitleMode: subtitleMode,
          subtitleText: subtitleTextBuilder?.call(m),
          subtitleHighlight: highlightSearchMatches
              ? entry.subtitleHighlight
              : null,
          trailingText: trailingTextBuilder?.call(m),
          onTap: () {
            if (onTapMember != null) {
              onTapMember!(m.mitgliedsnummer);
            }
          },
          toggleFavorites: () {
            if (onToggleFavourite != null) {
              onToggleFavourite!(m.mitgliedsnummer);
            }
          },
        );
      },
    );
  }

  _FilteredMemberEntry? _resolveFilteredMember(
    Mitglied mitglied,
    String search,
  ) {
    final candidates = <String?>[
      for (final emailAdresse in mitglied.emailAdressen) emailAdresse.wert,
      mitglied.fahrtenname,
      mitglied.vorname,
      mitglied.nachname,
      mitglied.mitgliedsnummer,
    ];

    for (final candidate in candidates) {
      final highlight = _buildHighlight(candidate, search);
      if (highlight != null) {
        return _FilteredMemberEntry(
          mitglied: mitglied,
          subtitleHighlight: highlight,
        );
      }
    }

    return null;
  }

  MemberSubtitleHighlight? _buildHighlight(String? text, String search) {
    if (text == null || text.isEmpty) {
      return null;
    }

    final matchStart = text.toLowerCase().indexOf(search);
    if (matchStart < 0) {
      return null;
    }

    return MemberSubtitleHighlight(
      text: text,
      matchStart: matchStart,
      matchEnd: matchStart + search.length,
    );
  }
}
