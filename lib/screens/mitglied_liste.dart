import 'package:backdrop/backdrop.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:nami/utilities/hive/mitglied.dart';
import 'package:nami/utilities/mitglied.filterAndSort.dart';
import 'package:nami/utilities/constants.dart';

class MitgliedsListe extends StatefulWidget {
  const MitgliedsListe({Key? key}) : super(key: key);

  @override
  _MitgliedsListeState createState() => _MitgliedsListeState();
}

class _MitgliedsListeState extends State<MitgliedsListe> {
  List<Mitglied> mitglieder =
      Hive.box<Mitglied>('members').values.toList().cast<Mitglied>();
  List<Mitglied> filteredMitglieder = List.empty();
  String searchString = "";
  MemberSorting sorting = MemberSorting.name;
  List<DropdownMenuItem<String>> sortingDropdownValues =
      List.empty(growable: true);
  List<bool> filterGroup = List.generate(Stufe.values.length, (index) => false);
  bool disableInactive = true;

  @override
  void initState() {
    super.initState();
    filteredMitglieder = mitglieder;

    for (MemberSorting value in MemberSorting.values) {
      sortingDropdownValues.add(DropdownMenuItem<String>(
          child: Text(value.string()), value: value.string()));
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

    setState(() {
      filteredMitglieder;
    });
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
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: filteredMitglieder.length,
      itemBuilder: (context, index) {
        return GestureDetector(
          onTap: () => print(
              'clicked on ${filteredMitglieder[index].mitgliedsNummer.toString()}'),
          child: Card(
            child: ListTile(
              leading: Container(
                color: StufenExtension.getValueFromString(
                        filteredMitglieder[index].stufe)
                    .color(),
                width: 5,
              ),
              minLeadingWidth: 5,
              title: Text(
                  '${filteredMitglieder[index].vorname} ${filteredMitglieder[index].nachname}'),
              subtitle:
                  Text(filteredMitglieder[index].mitgliedsNummer.toString()),
              trailing: Text(filteredMitglieder[index].stufe),
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
        const Text("Sortiere nach"),
        const SizedBox(width: 15),
        DropdownButton<String>(
            value: sorting.string(),
            icon: const Icon(Icons.expand_more),
            iconSize: 24,
            elevation: 16,
            style: const TextStyle(color: Colors.deepPurple),
            underline: Container(
              height: 2,
              color: Colors.deepPurpleAccent,
            ),
            onChanged: setSorting,
            items: sortingDropdownValues)
      ],
    );
  }

  Widget _buildFilterGroup() {
    return Column(
      children: [
        CheckboxListTile(
            value: filterGroup[0],
            title: const Text('Wölflinge'),
            onChanged: (value) =>
                setFilterGroup(0, value! ? value : !filterGroup[0])),
        CheckboxListTile(
            value: filterGroup[1],
            title: const Text('Jungpfadfinder'),
            onChanged: (value) =>
                setFilterGroup(1, value! ? value : !filterGroup[1])),
        CheckboxListTile(
            value: filterGroup[2],
            title: const Text('Pfadfinder'),
            onChanged: (value) =>
                setFilterGroup(2, value! ? value : !filterGroup[2])),
        CheckboxListTile(
            value: filterGroup[3],
            title: const Text('Rover'),
            onChanged: (value) =>
                setFilterGroup(3, value! ? value : !filterGroup[3])),
        CheckboxListTile(
            value: filterGroup[4],
            title: const Text('Leiter'),
            onChanged: (value) =>
                setFilterGroup(4, value! ? value : !filterGroup[4])),
        CheckboxListTile(
            value: filterGroup[5],
            title: const Text('keine Gruppe'),
            onChanged: (value) =>
                setFilterGroup(5, value! ? value : !filterGroup[5])),
      ],
    );
  }

  Widget _buildFilter() {
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _buildSortDropdown(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
            child: TextField(
              onChanged: setSearchValue,
              decoration: const InputDecoration(
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(),
                hintText: 'Textsuche (Name, Mail, Mitgliedsnummer)',
              ),
            ),
          ),
          _buildFilterGroup(),
          const Divider(color: Colors.black),
          CheckboxListTile(
            value: disableInactive,
            title: const Text('Inaktive Mitglieder ausblenden'),
            onChanged: setDisabledInactive,
          ),
        ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: BackdropScaffold(
            appBar: BackdropAppBar(
              title: const Text("Mitglieder"),
              leading: const BackButton(),
              actions: const <Widget>[
                BackdropToggleButton(
                  icon: AnimatedIcons.search_ellipsis,
                )
              ],
            ),
            backLayer: _buildFilter(),
            frontLayer: _buildMemberList()));
  }
}
