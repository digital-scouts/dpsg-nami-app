import 'package:backdrop/backdrop.dart';
import 'package:flutter/material.dart';
// import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:nami/screens/mitgliedsliste/mitglied_details.dart';
import 'package:nami/utilities/hive/mitglied.dart';
import 'package:nami/utilities/mitglied.filterAndSort.dart';
import 'package:nami/utilities/stufe.dart';

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
        gruppen.add(Stufe.stufen[i]);
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
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: filteredMitglieder.length,
      itemBuilder: (context, index) {
        return GestureDetector(
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (context) =>
                  MitgliedDetail(mitglied: filteredMitglieder[index]))),
          child: Card(
            child: ListTile(
              leading: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                      colors: [
                        filteredMitglieder[index].isMitgliedLeiter()
                            ? Stufe.leiterFarbe
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
                  Text(filteredMitglieder[index].mitgliedsNummer.toString()),
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
              decoration: InputDecoration(
                hintStyle: Theme.of(context).textTheme.bodySmall,
                filled: true,
                hintText: 'Textsuche (Name, Mail, Mitgliedsnummer)',
              ),
            ),
          ),
          _buildFilterGroup(),
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
    return Scaffold(
        body: BackdropScaffold(
            appBar: BackdropAppBar(
              title: const Center(child: Text("Mitglieder")),
              automaticallyImplyLeading: false,
              actions: <Widget>[
                BackdropToggleButton(
                  icon: AnimatedIcons.search_ellipsis,
                  color: Theme.of(context).iconTheme.color ?? Colors.black,
                ),
              ],
            ),
            backLayer: _buildFilter(),
            frontLayer: _buildMemberList()));
  }
}
