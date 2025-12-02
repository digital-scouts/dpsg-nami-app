import 'package:flutter/material.dart';
import 'package:nami/domain/member/mitglied.dart';
import 'package:nami/presentation/widgets/member_list_tile.dart';
import 'package:nami/domain/member/member_utils.dart';
import 'package:nami/domain/member/stufe.dart';

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
    this.sortKey = MemberSortKey.name,
    this.subtitleMode = MemberSubtitleMode.mitgliedsnummer,
    this.favourites = const {},
    this.stufenFilter = const {},
    this.onToggleFavourite,
    this.onTapMember,
  });
  final List<Mitglied> mitglieder;
  final String searchString;
  final MemberSortKey sortKey;
  final MemberSubtitleMode subtitleMode;
  final Set<String> favourites;
  final Set<Stufe> stufenFilter;
  final ValueChanged<String>? onToggleFavourite;
  final ValueChanged<String>? onTapMember;

  @override
  Widget build(BuildContext context) {
    final search = searchString.toLowerCase();
    bool match(String? v) => v != null && v.toLowerCase().contains(search);
    final filteredSearch =
        (search.isEmpty
                ? mitglieder
                : mitglieder.where(
                    (m) =>
                        match(m.vorname) ||
                        match(m.nachname) ||
                        match(m.fahrtenname) ||
                        match(m.mitgliedsnummer) ||
                        match(m.email1) ||
                        match(m.email2) ||
                        match(m.telefon1) ||
                        match(m.telefon2) ||
                        match(m.telefon3),
                  ))
            .toList();

    final filtered = stufenFilter.isEmpty
        ? filteredSearch
        : filteredSearch.where((m) {
            // Nutze alle aktiven Tätigkeiten für den Filter (nicht nur neueste)
            final aktiveStufen = m.taetigkeiten
                .where((t) => t.istAktiv)
                .map((t) => t.stufe)
                .toSet();
            return aktiveStufen.any(stufenFilter.contains);
          }).toList();

    filtered.sort((a, b) {
      switch (sortKey) {
        case MemberSortKey.age:
          // Ältere zuerst (früheres Geburtsdatum)
          return a.geburtsdatum.compareTo(b.geburtsdatum);
        case MemberSortKey.group:
          final sa =
              MemberUtils.aktiveStufe(a)?.index ?? Stufe.values.length + 1;
          final sb =
              MemberUtils.aktiveStufe(b)?.index ?? Stufe.values.length + 1;
          return sa.compareTo(sb);
        case MemberSortKey.name:
          final ln = a.nachname.compareTo(b.nachname);
          if (ln != 0) return ln;
          return a.vorname.compareTo(b.vorname);
        case MemberSortKey.vorname:
          final fn = a.vorname.compareTo(b.vorname);
          if (fn != 0) return fn;
          return a.nachname.compareTo(b.nachname);
        case MemberSortKey.memberTime:
          // Längere Mitgliedschaft zuerst (früheres Eintrittsdatum)
          return a.eintrittsdatum.compareTo(b.eintrittsdatum);
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
        final m = filtered[i];
        return MemberListTile(
          mitglied: m,
          isFavourite: favourites.contains(m.mitgliedsnummer),
          subtitleMode: subtitleMode,
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
}
