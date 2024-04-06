import 'package:flutter/material.dart';
import 'package:nami/utilities/mitglied.filterAndSort.dart';

Future<FilterOptions?> filterDialog(
    BuildContext context, FilterOptions f) async {
  FilterOptions filter = f.copy();
  return await showDialog(
      barrierDismissible: false,
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
          return AlertDialog(
            title: const Text('Filtern & Sortieren'),
            content: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
              Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Text("Sortiere nach",
                      style: Theme.of(context).textTheme.bodyLarge),
                  const SizedBox(width: 15),
                  Expanded(
                      child: DropdownButton<MemberSorting>(
                          value: filter.sorting,
                          icon: const Icon(Icons.expand_more),
                          isExpanded: true,
                          onChanged: (MemberSorting? sort) {
                            setState(() {
                              filter.sorting = sort ?? MemberSorting.name;
                            });
                          },
                          items: MemberSorting.values
                              .map((MemberSorting sort) =>
                                  DropdownMenuItem<MemberSorting>(
                                      value: sort,
                                      child: Text(
                                        memberSortingValues[sort] ?? "",
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyLarge,
                                      )))
                              .toList()))
                ],
              ),
              CheckboxListTile(
                contentPadding: const EdgeInsets.only(left: 0),
                value: filter.disableInactive,
                title: const Text('Inaktive Mitglieder ausblenden'),
                onChanged: (bool? value) {
                  setState(() {
                    filter.disableInactive = value ?? false;
                  });
                },
              ),
              const Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Text("Subtext", style: Theme.of(context).textTheme.bodyLarge),
                  const SizedBox(width: 15),
                  Expanded(
                      child: DropdownButton<MemberSubElement>(
                          value: filter.subElement,
                          isExpanded: true,
                          icon: const Icon(Icons.expand_more),
                          onChanged: (MemberSubElement? subElement) {
                            setState(() {
                              filter.subElement =
                                  subElement ?? MemberSubElement.id;
                            });
                          },
                          items: MemberSubElement.values
                              .map((MemberSubElement sort) =>
                                  DropdownMenuItem<MemberSubElement>(
                                      value: sort,
                                      child: Text(
                                        memberSubElementValues[sort] ?? "",
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyLarge,
                                      )))
                              .toList()))
                ],
              ),
            ]),
            actions: <Widget>[
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(null);
                },
                child: const Text('Abbrechen'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(filter);
                },
                child: const Text('Anwenden'),
              ),
            ],
          );
        });
      });
}
