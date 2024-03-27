import 'package:backdrop/backdrop.dart';
import 'package:flutter/material.dart';
// import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:nami/screens/mitgliedsliste/mitglied_details.dart';
import 'package:nami/utilities/extensions.dart';
import 'package:nami/utilities/hive/mitglied.dart';
import 'package:nami/utilities/mitglied.filterAndSort.dart';
import 'package:nami/utilities/stufe.dart';
import 'package:nami/utilities/theme.dart';

import 'mitglied_bearbeiten.dart';

class MitgliedsListe extends StatefulWidget {
  const MitgliedsListe({Key? key}) : super(key: key);

  @override
  MitgliedsListeState createState() => MitgliedsListeState();
}

class MitgliedsListeState extends State<MitgliedsListe> {
  Box<Mitglied> memberBox = Hive.box<Mitglied>('members');
  List<Mitglied> mitglieder =
      Hive.box<Mitglied>('members').values.toList().cast<Mitglied>();
  List<Mitglied> filteredMitglieder = List.empty();
  String searchString = "";
  MemberSorting sorting = MemberSorting.name;
  List<DropdownMenuItem<String>> sortingDropdownValues =
      List.empty(growable: true);
  List<bool> filterGroup = List.generate(Stufe.stufen.length, (index) => false);
  bool disableInactive = true;

  @override
  void initState() {
    super.initState();
    memberBox.listenable().addListener(() {
      mitglieder = memberBox.values.toList().cast<Mitglied>();
      applyFilterAndSort();
    });

    filteredMitglieder = mitglieder;

    for (MemberSorting value in MemberSorting.values) {
      sortingDropdownValues.add(DropdownMenuItem<String>(
          value: value.string(), child: Text(value.string())));
    }

    applyFilterAndSort();
  }

  void applyFilterAndSort() {
    filteredMitglieder = List.from(mitglieder);

    //string
    if (searchString.isNotEmpty) {
      filterByString(filteredMitglieder, searchString);
    }

    //gruppe
    List<Stufe> gruppen = List.empty(growable: true);
    for (var i = 0; i < filterGroup.length; i++) {
      if (filterGroup[i]) {
        gruppen.add(Stufe.values[i]);
      }
    }
    filterByStufe(filteredMitglieder, gruppen);

    if (disableInactive) {
      filterByStatus(filteredMitglieder);
    }

    //sort
    switch (sorting.string()) {
      case memberSortingAgeString:
        sortByAge(filteredMitglieder);
        break;
      case memberSortingGroupString:
        sortByStufe(filteredMitglieder);
        break;
      case memberSortingNameString:
        sortByName(filteredMitglieder);
        break;
      case memberSortingMemberTimeString:
        sortByMitgliedsalter(filteredMitglieder);
        break;
    }

    try {
      setState(() {
        filteredMitglieder;
      });
    } catch (_) {}
  }

  void setSearchValue(String value) {
    searchString = value;
    applyFilterAndSort();
  }

  void setSorting(String? sort) {
    sorting = MemberSortingExtension.getValue(sort);
    applyFilterAndSort();
  }

  void setFilterGroup(int index, bool value) {
    filterGroup[index] = value;
    applyFilterAndSort();
  }

  void setDisabledInactive(bool? value) {
    disableInactive = value! ? value : !disableInactive;
    applyFilterAndSort();
  }

  Widget _buildMemberList() {
    if (filteredMitglieder.isEmpty) {
      return const Center(child: Text('Keine Mitglieder gefunden'));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: filteredMitglieder.length,
      itemBuilder: (context, index) {
        return Card(
          child: InkWell(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                  builder: (context) =>
                      MitgliedDetail(mitglied: filteredMitglieder[index])),
            ),
            child: ListTile(
              leading: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                      colors: [
                        filteredMitglieder[index].isMitgliedLeiter()
                            ? DPSGColors.leiterFarbe
                            : Stufe.getStufeByString(
                                    filteredMitglieder[index].stufe)
                                .farbe,
                        Stufe.getStufeByString(filteredMitglieder[index].stufe)
                            .farbe
                      ],
                      begin: const FractionalOffset(0.0, 0.0),
                      end: const FractionalOffset(0.0, 1.0),
                      stops: const [0.5, 0.5],
                      tileMode: TileMode.clamp),
                ),
                width: 5,
              ),
              minLeadingWidth: 5,
              title: Text(
                  '${filteredMitglieder[index].vorname} ${filteredMitglieder[index].nachname}'),
              subtitle:
                  Text(filteredMitglieder[index].geburtsDatum.prettyPrint()),
              trailing: Text(filteredMitglieder[index].stufe == 'keine Stufe'
                  ? ''
                  : filteredMitglieder[index].stufe),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSortDropdown() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text("Sortiere nach", style: Theme.of(context).textTheme.bodyLarge),
        const SizedBox(width: 15),
        DropdownButton<String>(
            value: sorting.string(),
            icon: const Icon(Icons.expand_more),
            style: Theme.of(context).textTheme.bodyLarge,
            onChanged: setSorting,
            items: sortingDropdownValues)
      ],
    );
  }

  Widget _buildFilterGroup() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          for (final stufe in Stufe.stufen)
            // TODO: show only filter for groups with members
            GestureDetector(
              onTap: () {
                setFilterGroup(stufe.index, !filterGroup[stufe.index]);
              },
              child: Container(
                width: 50.0,
                height: 50.0,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: filterGroup[stufe.index]
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.surfaceVariant,
                ),
                child: Center(
                  child: Image.asset(
                    stufe.imagePath!,
                    width: 30.0,
                    height: 30.0,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: TextField(
        onChanged: setSearchValue,
        decoration: InputDecoration(
          hintStyle: Theme.of(context).textTheme.bodySmall,
          filled: true,
          hintText: 'Textsuche (Name, Mail, Mitgliedsnummer)',
        ),
      ),
    );
  }

  Widget _buildFilter() {
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _buildSortDropdown(),
          const Divider(),
          CheckboxListTile(
            value: disableInactive,
            title: const Text('Inaktive Mitglieder ausblenden'),
            onChanged: setDisabledInactive,
          ),
        ]);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
      return BackdropScaffold(
          headerHeight: 100,
          subHeader: Column(
            children: <Widget>[
              _buildFilterGroup(),
              _buildSearchBar(),
            ],
          ),
          appBar: BackdropAppBar(
            title: const Center(child: Text("Mitglieder")),
            automaticallyImplyLeading: false,
            actions: <Widget>[
              IconButton(
                icon: const Icon(Icons.add),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => MitgliedBearbeiten(
                              mitglied: null,
                            )),
                  );
                },
              ),
              BackdropToggleButton(
                icon: AnimatedIcons.search_ellipsis,
                color: Theme.of(context).iconTheme.color ?? Colors.black,
              ),
            ],
          ),
          backLayer: SizedBox(
              height: constraints.maxHeight,
              width: constraints.maxWidth,
              child: _buildFilter()),
          backLayerBackgroundColor: Theme.of(context).colorScheme.surface,
          frontLayer: SizedBox(
              height: constraints.maxHeight,
              width: constraints.maxWidth,
              child: _buildMemberList()));
    });
  }
}
