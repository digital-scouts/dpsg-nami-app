import 'package:flutter/material.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:nami/screens/mitgliedsliste/mitglied_details.dart';
import 'package:nami/screens/mitgliedsliste/mitglied_liste_filter.dart';
import 'package:nami/screens/widgets/relogin_banner.dart';
import 'package:nami/utilities/hive/custom_group.dart';
import 'package:nami/utilities/hive/mitglied.dart';
import 'package:nami/utilities/hive/settings.dart';
import 'package:nami/utilities/mitglied.filterAndSort.dart';
import 'package:nami/utilities/nami/nami_rechte.dart';
import 'package:nami/utilities/stufe.dart';
import 'package:provider/provider.dart';
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

  @override
  void initState() {
    super.initState();

    memberBox.listenable().addListener(() {
      setState(() {
        mitglieder = memberBox.values.toList().cast<Mitglied>();
      });
    });
  }

  Widget _buildMemberList(BuildContext context, List<Mitglied> mitglieder) {
    if (mitglieder.isEmpty) {
      return const Center(child: Text('Keine Mitglieder gefunden'));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: mitglieder.length + 1,
      itemBuilder: (context, index) {
        if (index == mitglieder.length) {
          // Wenn das aktuelle Element das letzte ist, gibt einen Text zurück
          return ListTile(
            title: Center(child: Text('Mitglieder: ${mitglieder.length}')),
          );
        }
        bool isFavourite =
            getFavouriteList().contains(mitglieder[index].mitgliedsNummer);
        return Dismissible(
          key: Key(mitglieder[index].mitgliedsNummer.toString()),
          direction: DismissDirection.endToStart,
          confirmDismiss: (direction) async {
            setState(() {
              // Fügen Sie das Mitglied zu den Favoriten hinzu
              toggleFavorites(mitglieder[index]);
            });

            return false;
          },
          background: Container(
            color: isFavourite ? Colors.red : Colors.green,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Icon(
              isFavourite ? Icons.bookmark_remove : Icons.bookmark_add,
              color: Colors.white,
            ),
          ),
          child: Card(
            child: InkWell(
              onTap: () => {
                Wiredash.trackEvent('Show Member Details',
                    data: {'type': 'memberList'}),
                Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (context) =>
                          MitgliedDetail(mitglied: mitglieder[index])),
                )
              },
              child: ListTile(
                leading: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                        colors: [
                          mitglieder[index].currentStufe.farbe,
                          mitglieder[index].currentStufeWithoutLeiter.farbe
                        ],
                        begin: const FractionalOffset(0.0, 0.0),
                        end: const FractionalOffset(0.0, 1.0),
                        stops: const [0.5, 0.5],
                        tileMode: TileMode.clamp),
                  ),
                  width: 5,
                ),
                minLeadingWidth: 5,
                title: Provider.of<MemberListSettingsHandler>(context)
                            .filterOptions
                            .sorting ==
                        MemberSorting.lastname
                    ? Text(
                        '${mitglieder[index].nachname}, ${mitglieder[index].vorname} ')
                    : Text(
                        '${mitglieder[index].vorname} ${mitglieder[index].nachname}'),
                subtitle: switch (
                    Provider.of<MemberListSettingsHandler>(context)
                        .filterOptions
                        .subElement) {
                  MemberSubElement.spitzname =>
                    Text(mitglieder[index].spitzname ?? ''),
                  MemberSubElement.id =>
                    Text(mitglieder[index].mitgliedsNummer.toString()),
                  MemberSubElement.birthday => Text(
                      DateFormat('d. MMMM yyyy', 'de_DE')
                          .format(mitglieder[index].geburtsDatum),
                    )
                },
                trailing: Text(
                    mitglieder[index].currentStufe == Stufe.KEINE_STUFE
                        ? (mitglieder[index].getActiveTaetigkeiten().isNotEmpty
                            ? mitglieder[index]
                                .getActiveTaetigkeiten()
                                .first
                                .taetigkeit
                            : '')
                        : mitglieder[index].currentStufe.display),
              ),
            ),
          ),
        );
      },
    );
  }

  void toggleFavorites(Mitglied mitglied) {
    getFavouriteList().contains(mitglied.mitgliedsNummer)
        ? removeFavouriteList(mitglied.mitgliedsNummer)
        : addFavouriteList(mitglied.mitgliedsNummer);
  }

  Widget _buildFilterGroup(BuildContext context) {
    Map<String, CustomGroup> gruppen =
        Provider.of<MemberListSettingsHandler>(context)
            .filterOptions
            .filterGroup;

    // Zeige keine Gruppe an, die keine Mitglieder haben
    Map<String, CustomGroup> customGruppen = {};

    gruppen.forEach((key, value) {
      if (!value.static ||
          (value.stufe != null &&
              mitglieder.any((mitglied) =>
                  value.stufe == mitglied.currentStufeWithoutLeiter ||
                  (value.stufe == Stufe.LEITER &&
                      mitglied.isMitgliedLeiter())))) {
        customGruppen[key] = value;
      }
    });

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: customGruppen.entries.map((entry) {
            String groupName = entry.key;
            CustomGroup group = entry.value;

            Widget groupImage;
            if (group.stufe == null) {
              groupImage = Icon(group.icon);
            } else {
              groupImage = Image.asset(
                group.stufe!.imagePath ?? Stufe.LEITER.imagePath!,
                width: 30.0,
                height: 30.0,
                cacheHeight: 100,
              );
            }

            return GestureDetector(
              onTap: () {
                Provider.of<MemberListSettingsHandler>(context, listen: false)
                    .updateFilterGroupActive(groupName, !group.active);
              },
              child: Container(
                width: 50.0,
                height: 50.0,
                margin: const EdgeInsets.symmetric(
                    horizontal: 4.0), // Abstand zwischen den Elementen
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: group.active
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.secondaryContainer,
                ),
                child: Center(
                  child: groupImage,
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: TextField(
        onChanged: (value) {
          Provider.of<MemberListSettingsHandler>(context, listen: false)
              .updateSearchString(value);
        },
        enableSuggestions: false,
        autocorrect: false,
        autofillHints: null,
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

  static List<String> getUniqueTaetigkeiten(List<Mitglied> mitglieder) {
    Set<String> uniqueTaetigkeiten = {};

    for (var mitglied in mitglieder) {
      for (var taetigkeit in mitglied.getActiveTaetigkeiten()) {
        uniqueTaetigkeiten.add(taetigkeit.taetigkeit);
      }
    }

    return uniqueTaetigkeiten.toList();
  }

  Future<void> filterDialog(BuildContext context) async {
    final filterHandler = MemberListSettingsHandler();
    await showDialog(
      barrierDismissible: false,
      context: context,
      builder: (BuildContext context) {
        return FilterDialog(
            filterHandler: filterHandler,
            maxTaetigkeiten: getUniqueTaetigkeiten(mitglieder));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<MemberListSettingsHandler>.value(
        value: MemberListSettingsHandler(),
        child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
          return Scaffold(
            appBar: AppBar(
              title: const Center(child: Text("Mitglieder")),
              automaticallyImplyLeading: false,
              actions: <Widget>[
                if (getNamiChangesEnabled() &&
                    getAllowedFeatures().contains(AllowedFeatures.memberCreate))
                  IconButton(
                    icon: const Icon(Icons.person_add_alt_1),
                    onPressed: () {
                      Wiredash.trackEvent('Mitglied bearbeiten opend');
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => MitgliedBearbeiten()),
                      );
                    },
                  ),
                IconButton(
                    onPressed: () => filterDialog(context),
                    icon: const Icon(Icons.tune)),
              ],
            ),
            body: Column(
              children: <Widget>[
                const ReloginBanner(),
                _buildFilterGroup(context),
                _buildSearchBar(context),
                Expanded(
                  child: _buildMemberList(
                      context,
                      Provider.of<MemberListSettingsHandler>(context)
                          .applyFilterAndSort(mitglieder)),
                ),
              ],
            ),
          );
        }));
  }
}
