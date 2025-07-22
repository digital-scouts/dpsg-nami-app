import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:intl/intl.dart';
import 'package:nami/services/member_service.dart';
import 'package:nami/utilities/hive/mitglied.dart';
import 'package:nami/utilities/stufe.dart';

import 'mitglieder_bloc.dart';

class MitgliedCard extends StatelessWidget {
  final Mitglied mitglied;
  final VoidCallback? onTap;
  final bool isFavorite;
  final VoidCallback? onFavoriteToggle;

  const MitgliedCard({
    super.key,
    required this.mitglied,
    this.onTap,
    this.isFavorite = false,
    this.onFavoriteToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(mitglied.mitgliedsNummer.toString()),
      direction: DismissDirection.endToStart,
      confirmDismiss: (direction) async {
        onFavoriteToggle?.call();
        return false;
      },
      background: Container(
        color: isFavorite ? Colors.red : Colors.green,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Icon(
          isFavorite ? Icons.bookmark_remove : Icons.bookmark_add,
          color: Colors.white,
        ),
      ),
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: InkWell(
          onTap: onTap,
          child: ListTile(
            leading: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    mitglied.currentStufe.farbe,
                    mitglied.currentStufeWithoutLeiter.farbe,
                  ],
                  begin: const FractionalOffset(0.0, 0.0),
                  end: const FractionalOffset(0.0, 1.0),
                  stops: const [0.5, 0.5],
                  tileMode: TileMode.clamp,
                ),
              ),
              width: 5,
            ),
            minLeadingWidth: 5,
            title: Text(
              '${mitglied.vorname} ${mitglied.nachname}',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (mitglied.spitzname != null &&
                    mitglied.spitzname!.isNotEmpty)
                  Text(
                    mitglied.spitzname!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                Text(
                  'Nr. ${mitglied.mitgliedsNummer}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Text(
                  DateFormat(
                    'd. MMMM yyyy',
                    'de_DE',
                  ).format(mitglied.geburtsDatum),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  mitglied.currentStufe == Stufe.KEINE_STUFE
                      ? (mitglied.getActiveTaetigkeiten().isNotEmpty
                            ? mitglied.getActiveTaetigkeiten().first.taetigkeit
                            : 'Keine Stufe')
                      : mitglied.currentStufe.display,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: mitglied.currentStufe.farbe,
                  ),
                ),
                if (isFavorite)
                  Icon(
                    Icons.bookmark,
                    size: 16,
                    color: Theme.of(context).primaryColor,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class MitgliederSearchBar extends StatelessWidget {
  final String searchString;
  final Function(String) onChanged;

  const MitgliederSearchBar({
    super.key,
    required this.searchString,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: FormBuilderTextField(
        name: 'search',
        initialValue: searchString,
        onChanged: (value) => onChanged(value?.toString() ?? ''),
        enableSuggestions: false,
        autocorrect: false,
        decoration: InputDecoration(
          hintStyle: Theme.of(context).textTheme.bodySmall,
          filled: true,
          fillColor: Colors.white.withOpacity(0.05),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          prefixIcon: const Icon(Icons.search),
          hintText: 'Suche nach Name, E-Mail oder Mitgliedsnummer',
          suffixIcon: searchString.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () => onChanged(''),
                )
              : null,
        ),
      ),
    );
  }
}

class MitgliederFilterChips extends StatelessWidget {
  final String? selectedFilter;
  final Function(String?) onFilterChanged;

  const MitgliederFilterChips({
    super.key,
    this.selectedFilter,
    required this.onFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    final filters = [
      {'label': 'Alle', 'value': null},
      {'label': 'Biber', 'value': 'biber'},
      {'label': 'Wölflinge', 'value': 'woe'},
      {'label': 'Jungpfadfinder', 'value': 'jufi'},
      {'label': 'Pfadfinder', 'value': 'pfadi'},
      {'label': 'Rover', 'value': 'rover'},
      {'label': 'Leiter', 'value': 'leiter'},
    ];

    return SizedBox(
      height: 60,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: filters.length,
        itemBuilder: (context, index) {
          final filter = filters[index];
          final isSelected = selectedFilter == filter['value'];

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(filter['label'] as String),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  onFilterChanged(filter['value']);
                } else if (isSelected) {
                  onFilterChanged(null);
                }
              },
              selectedColor: Theme.of(context).primaryColor.withOpacity(0.2),
              checkmarkColor: Theme.of(context).primaryColor,
            ),
          );
        },
      ),
    );
  }
}

class MitgliederListView extends StatelessWidget {
  final MemberService memberService;

  const MitgliederListView({super.key, required this.memberService});

  List<Mitglied> _filterMitglieder(
    List<Mitglied> mitglieder,
    String searchString,
    String? filter,
  ) {
    var filtered = mitglieder;

    // Apply search filter
    if (searchString.isNotEmpty) {
      filtered = filtered.where((mitglied) {
        return mitglied.vorname.toLowerCase().contains(
              searchString.toLowerCase(),
            ) ||
            mitglied.nachname.toLowerCase().contains(
              searchString.toLowerCase(),
            ) ||
            mitglied.mitgliedsNummer.toString().contains(searchString) ||
            (mitglied.spitzname?.toLowerCase().contains(
                  searchString.toLowerCase(),
                ) ??
                false);
      }).toList();
    }

    // Apply stufe filter
    if (filter != null) {
      switch (filter) {
        case 'biber':
          filtered = filtered
              .where((m) => m.currentStufeWithoutLeiter == Stufe.BIBER)
              .toList();
          break;
        case 'woe':
          filtered = filtered
              .where((m) => m.currentStufeWithoutLeiter == Stufe.WOELFLING)
              .toList();
          break;
        case 'jufi':
          filtered = filtered
              .where((m) => m.currentStufeWithoutLeiter == Stufe.JUNGPADFINDER)
              .toList();
          break;
        case 'pfadi':
          filtered = filtered
              .where((m) => m.currentStufeWithoutLeiter == Stufe.PFADFINDER)
              .toList();
          break;
        case 'rover':
          filtered = filtered
              .where((m) => m.currentStufeWithoutLeiter == Stufe.ROVER)
              .toList();
          break;
        case 'leiter':
          filtered = filtered.where((m) => m.isMitgliedLeiter()).toList();
          break;
      }
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MitgliederBloc, MitgliederState>(
      builder: (context, state) {
        if (state is MitgliederLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (state is MitgliederError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.red[400]),
                const SizedBox(height: 16),
                Text(
                  'Fehler',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  state.message,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    context.read<MitgliederBloc>().add(LoadMitglieder());
                  },
                  child: const Text('Erneut versuchen'),
                ),
              ],
            ),
          );
        }

        if (state is MitgliederLoaded) {
          final filteredMitglieder = _filterMitglieder(
            state.mitglieder,
            state.searchString,
            state.filter,
          );

          if (filteredMitglieder.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.people_outline,
                    size: 64,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    state.searchString.isNotEmpty || state.filter != null
                        ? 'Keine Mitglieder gefunden'
                        : 'Keine Mitglieder vorhanden',
                    style: const TextStyle(fontSize: 18),
                  ),
                  if (state.searchString.isNotEmpty || state.filter != null)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text(
                        'Versuche andere Suchkriterien',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                ],
              ),
            );
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Icon(Icons.people, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      '${filteredMitglieder.length} Mitglieder',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: filteredMitglieder.length,
                  itemBuilder: (context, index) {
                    final mitglied = filteredMitglieder[index];
                    final isFavorite = memberService.isFavorite(
                      mitglied.mitgliedsNummer,
                    );

                    return MitgliedCard(
                      mitglied: mitglied,
                      isFavorite: isFavorite,
                      onTap: () {
                        // TODO: Navigate to member details
                      },
                      onFavoriteToggle: () {
                        context.read<MitgliederBloc>().add(
                          ToggleFavorite(mitglied.mitgliedsNummer),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          );
        }

        return const Center(child: Text('Keine Daten verfügbar'));
      },
    );
  }
}
