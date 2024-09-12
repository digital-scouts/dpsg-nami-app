import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:nami/screens/mitgliedsliste/mitglied_details.dart';
import 'package:nami/screens/mitgliedsliste/mitglied_liste_filter.dart';
import 'package:nami/screens/widgets/relogin_banner.dart';
import 'package:nami/utilities/hive/mitglied.dart';
import 'package:nami/utilities/hive/settings.dart';
import 'package:nami/utilities/mitglied.filterAndSort.dart';
import 'package:nami/utilities/stufe.dart';
import 'package:nami/utilities/theme.dart';
import 'package:wiredash/wiredash.dart';

import 'mitglied_bearbeiten.dart';

class MitgliedsListe extends StatefulWidget {
  const MitgliedsListe({super.key});

  @override
  MitgliedsListeState createState() => MitgliedsListeState();
}

class MitgliedsListeState extends State<MitgliedsListe> {
  Box<Mitglied> memberBox = Hive.box<Mitglied>('members');
  List<Mitglied> mitglieder =
      Hive.box<Mitglied>('members').values.toList().cast<Mitglied>();
  List<Mitglied> filteredMitglieder = List.empty();

  FilterOptions filter = FilterOptions(filterGroup: []);

  @override
  void initState() {
    super.initState();
    filter = FilterOptions(
        filterGroup: List.filled(Stufe.values.length, false),
        disableInactive: getListFilterInactive(),
        sorting: getListSort(),
        subElement: getListSubtext());

    memberBox.listenable().addListener(() {
      mitglieder = memberBox.values.toList().cast<Mitglied>();
      applyFilterAndSort();
    });

    filteredMitglieder = mitglieder;

    applyFilterAndSort();
  }

  void applyFilterAndSort() {
    filteredMitglieder = List.from(mitglieder);

    //string
    if (filter.searchString.isNotEmpty) {
      filterByString(filteredMitglieder, filter.searchString);
    }

    //gruppe
    List<Stufe> gruppen = List.empty(growable: true);
    for (var i = 0; i < filter.filterGroup.length; i++) {
      if (filter.filterGroup[i]) {
        gruppen.add(Stufe.values[i]);
      }
    }
    filterByStufe(filteredMitglieder, gruppen);

    if (filter.disableInactive) {
      filterByStatus(filteredMitglieder);
    }

    //sort
    switch (filter.sorting) {
      case MemberSorting.age:
        sortByAge(filteredMitglieder);
        break;
      case MemberSorting.group:
        sortByStufe(filteredMitglieder);
        break;
      case MemberSorting.name:
        sortByName(filteredMitglieder);
        break;
      case MemberSorting.lastname:
        sortByLastName(filteredMitglieder);
        break;
      case MemberSorting.memberTime:
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
    filter.searchString = value;
    applyFilterAndSort();
  }

  void setFilterGroup(int index, bool value) {
    filter.filterGroup[index] = value;
    applyFilterAndSort();
  }

  Widget _buildMemberList() {
    if (filteredMitglieder.isEmpty) {
      return const Center(child: Text('Keine Mitglieder gefunden'));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: filteredMitglieder.length + 1,
      itemBuilder: (context, index) {
        if (index == filteredMitglieder.length) {
          // Wenn das aktuelle Element das letzte ist, gibt einen Text zurück
          return ListTile(
            title:
                Center(child: Text('Mitglieder: ${filteredMitglieder.length}')),
          );
        }
        return Card(
          child: InkWell(
            onTap: () => {
              Wiredash.of(context).trackEvent('Show Member Details',
                  data: {'type': 'memberList'}),
              Navigator.of(context)
                  .push(
                    MaterialPageRoute(
                        builder: (context) => MitgliedDetail(
                            mitglied: filteredMitglieder[index])),
                  )
                  .then((value) => setState(() {
                        applyFilterAndSort();
                      }))
            },
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
              title: filter.sorting == MemberSorting.lastname
                  ? Text(
                      '${filteredMitglieder[index].nachname}, ${filteredMitglieder[index].vorname} ')
                  : Text(
                      '${filteredMitglieder[index].vorname} ${filteredMitglieder[index].nachname}'),
              subtitle: switch (filter.subElement) {
                MemberSubElement.id =>
                  Text(filteredMitglieder[index].mitgliedsNummer.toString()),
                MemberSubElement.birthday => Text(
                    DateFormat('d. MMMM yyyy', 'de_DE')
                        .format(filteredMitglieder[index].geburtsDatum),
                  )
              },
              trailing: Text(filteredMitglieder[index].stufe == 'keine Stufe'
                  ? (filteredMitglieder[index]
                          .getActiveTaetigkeiten()
                          .isNotEmpty
                      ? filteredMitglieder[index]
                          .getActiveTaetigkeiten()
                          .first
                          .taetigkeit
                      : '')
                  : filteredMitglieder[index].stufe),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFilterGroup() {
    List<Stufe> gruppen = List.empty(growable: true);
    if (mitglieder.any((m) => m.stufe == Stufe.BIBER.display)) {
      gruppen.add(Stufe.BIBER);
    }
    gruppen.add(Stufe.WOELFLING);
    gruppen.add(Stufe.JUNGPADFINDER);
    gruppen.add(Stufe.PFADFINDER);
    gruppen.add(Stufe.ROVER);
    gruppen.add(Stufe.LEITER);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          for (final stufe in gruppen)
            GestureDetector(
              onTap: () {
                setFilterGroup(stufe.index, !filter.filterGroup[stufe.index]);
              },
              child: Container(
                width: 50.0,
                height: 50.0,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: filter.filterGroup[stufe.index]
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.surfaceContainer,
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
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: TextField(
        onChanged: setSearchValue,
        decoration: InputDecoration(
          hintStyle: Theme.of(context).textTheme.bodySmall,
          filled: true,
          fillColor: Colors.white.withOpacity(0.05),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
          border: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(10)),
            borderSide: BorderSide.none,
          ),
          icon: const Icon(Icons.search),
          hintText: 'Suche nach Name, Mail oder Mitgliedsnummer',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Wiredash.of(context).showPromoterSurvey(
      options: const PsOptions(
        frequency: Duration(days: 100),
        initialDelay: Duration(days: 7),
        minimumAppStarts: 3,
      ),
    );
    return LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
      return Scaffold(
        appBar: AppBar(
          title: const Center(child: Text("Mitglieder")),
          automaticallyImplyLeading: false,
          actions: <Widget>[
            IconButton(
              icon: const Icon(Icons.person_add),
              onPressed: () {
                Wiredash.of(context).trackEvent('Open new Member clicked');
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => MitgliedBearbeiten(
                            mitglied: null,
                          )),
                );
              },
            ),
            IconButton(
                onPressed: () => filterDialog(context, filter).then((value) => {
                      if (value != null)
                        {
                          setState(() {
                            filter = value;
                          }),
                          setListFilterInactive(value.disableInactive),
                          setListSort(value.sorting),
                          setListSubtext(value.subElement),
                          applyFilterAndSort()
                        }
                    }),
                icon: const Icon(Icons.tune)),
          ],
        ),
        body: Column(
          children: <Widget>[
            const ReloginBanner(),
            _buildFilterGroup(),
            _buildSearchBar(),
            Expanded(
              child: _buildMemberList(),
            ),
          ],
        ),
      );
    });
  }
}
