import 'package:flutter/material.dart';
import 'package:nami/domain/member/member_list_preferences.dart';
import 'package:nami/domain/member/member_utils.dart';
import 'package:nami/domain/member/mitglied.dart';
import 'package:nami/domain/taetigkeit/stufe.dart';
import 'package:nami/l10n/app_localizations.dart';
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
    this.warningBuilder,
    this.favourites = const {},
    this.selectedFilterKeys = const <String>{},
    this.mitgliedsFilterKeys = const <String, Set<String>>{},
    this.onResetFilters,
    this.onToggleFavourite,
    this.onTapMember,
    this.onTapSortHint,
  });
  final List<Mitglied> mitglieder;
  final String searchString;
  final bool highlightSearchMatches;
  final MemberSortKey sortKey;
  final MemberSubtitleMode subtitleMode;
  final String? Function(Mitglied mitglied)? subtitleTextBuilder;
  final String? Function(Mitglied mitglied)? trailingTextBuilder;
  final bool Function(Mitglied mitglied)? warningBuilder;
  final Set<String> favourites;
  final Set<String> selectedFilterKeys;
  final Map<String, Set<String>> mitgliedsFilterKeys;
  final VoidCallback? onResetFilters;
  final ValueChanged<String>? onToggleFavourite;
  final ValueChanged<String>? onTapMember;
  final VoidCallback? onTapSortHint;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final search = searchString.toLowerCase();
    final filteredSearch = search.isEmpty
        ? mitglieder
              .map((mitglied) => _FilteredMemberEntry(mitglied: mitglied))
              .toList(growable: false)
        : mitglieder
              .map((mitglied) => _resolveFilteredMember(mitglied, search))
              .whereType<_FilteredMemberEntry>()
              .toList(growable: false);

    final filtered = selectedFilterKeys.isEmpty
        ? filteredSearch
        : filteredSearch.where((entry) {
            final aktiveFilter =
                mitgliedsFilterKeys[entry.mitglied.mitgliedsnummer] ??
                const <String>{};
            return aktiveFilter.any(selectedFilterKeys.contains);
          }).toList();
    final hasActiveFilterState =
        searchString.trim().isNotEmpty || selectedFilterKeys.isNotEmpty;

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

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  t.tParams('member_list_count', <String, Object>{
                    'count': filtered.length,
                  }),
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.outlineVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: onTapSortHint,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 2,
                    vertical: 4,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.swap_vert,
                        size: 14,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        _sortHintLabel(t, sortKey),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(t.t('member_list_no_results')),
                      if (hasActiveFilterState && onResetFilters != null) ...[
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: onResetFilters,
                          child: Text(t.t('member_list_reset_filters')),
                        ),
                      ],
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: filtered.length,
                  itemBuilder: (ctx, i) {
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
                      showWarning: warningBuilder?.call(m) ?? false,
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
                ),
        ),
      ],
    );
  }

  String _sortHintLabel(AppLocalizations t, MemberSortKey key) {
    switch (key) {
      case MemberSortKey.age:
        return t.t('member_list_sort_hint_age');
      case MemberSortKey.group:
        return t.t('member_list_sort_hint_group');
      case MemberSortKey.name:
        return t.t('member_list_sort_hint_name');
      case MemberSortKey.vorname:
        return t.t('member_list_sort_hint_vorname');
      case MemberSortKey.memberTime:
        return t.t('member_list_sort_hint_member_time');
    }
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
