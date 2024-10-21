import 'package:flutter/material.dart';
import 'package:multi_dropdown/multi_dropdown.dart';
import 'package:nami/utilities/mitglied.filterAndSort.dart';

class FilterDialog extends StatefulWidget {
  final MemberListSettingsHandler filterHandler;
  final List<String> maxTaetigkeiten;

  const FilterDialog(
      {super.key, required this.filterHandler, required this.maxTaetigkeiten});

  @override
  FilterDialogState createState() => FilterDialogState();
}

class FilterDialogState extends State<FilterDialog> {
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Filtern & Sortieren'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Text("Sortiere nach",
                    style: Theme.of(context).textTheme.bodyLarge),
                const SizedBox(width: 15),
                Expanded(
                  child: DropdownButton<MemberSorting>(
                    value: widget.filterHandler.filterOptions.sorting,
                    icon: const Icon(Icons.expand_more),
                    isExpanded: true,
                    onChanged: (MemberSorting? sort) {
                      setState(() {
                        widget.filterHandler
                            .updateSorting(sort ?? MemberSorting.name);
                      });
                    },
                    items: MemberSorting.values
                        .map((MemberSorting sort) =>
                            DropdownMenuItem<MemberSorting>(
                              value: sort,
                              child: Text(
                                memberSortingValues[sort] ?? "",
                                style: Theme.of(context).textTheme.bodyLarge,
                              ),
                            ))
                        .toList(),
                  ),
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Text("Zusatztext",
                    style: Theme.of(context).textTheme.bodyLarge),
                const SizedBox(width: 15),
                Expanded(
                  child: DropdownButton<MemberSubElement>(
                    value: widget.filterHandler.filterOptions.subElement,
                    isExpanded: true,
                    icon: const Icon(Icons.expand_more),
                    onChanged: (MemberSubElement? subElement) {
                      setState(() {
                        widget.filterHandler.updateSubElement(
                            subElement ?? MemberSubElement.id);
                      });
                    },
                    items: MemberSubElement.values
                        .map((MemberSubElement sort) =>
                            DropdownMenuItem<MemberSubElement>(
                              value: sort,
                              child: Text(
                                memberSubElementValues[sort] ?? "",
                                style: Theme.of(context).textTheme.bodyLarge,
                              ),
                            ))
                        .toList(),
                  ),
                ),
              ],
            ),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Gruppen'),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () {
                    editGroupSettingsDialog(context, null)
                        .then((MapEntry<String, CustomGroup>? value) => {
                              if (value != null)
                                widget.filterHandler
                                    .updateFilterGroup(value.key, value.value),
                              setState(() {})
                            });
                  },
                ),
              ],
            ),
            for (var gruppe in widget
                .filterHandler.filterOptions.filterGroup.entries
                .where((e) => !e.value.static))
              ListTile(
                leading: Icon(gruppe.value.icon),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () => editGroupSettingsDialog(context, gruppe)
                          .then((MapEntry<String, CustomGroup>? value) => {
                                if (value == null || value.key != gruppe.key)
                                  widget.filterHandler
                                      .removeFilterGroup(gruppe.key),
                                if (value != null)
                                  widget.filterHandler.updateFilterGroup(
                                      value.key, value.value),
                                setState(() {})
                              }),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () {
                        widget.filterHandler.removeFilterGroup(gruppe.key);
                        setState(() {});
                      },
                    ),
                  ],
                ),
                title: Text(gruppe.key),
              )
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('Schließen'),
        ),
      ],
    );
  }

  Future<MapEntry<String, CustomGroup>> editGroupSettingsDialog(
      BuildContext context, MapEntry<String, CustomGroup>? group) async {
    return await showDialog(
      context: context,
      builder: (BuildContext context) {
        return EditGroupSettingsDialog(
            group: group, maxTaetigkeiten: widget.maxTaetigkeiten);
      },
    );
  }
}

class EditGroupSettingsDialog extends StatefulWidget {
  final MapEntry<String, CustomGroup>? group;

  final List<String> maxTaetigkeiten;

  const EditGroupSettingsDialog(
      {super.key, this.group, required this.maxTaetigkeiten});

  @override
  EditGroupSettingsDialogState createState() => EditGroupSettingsDialogState();
}

class EditGroupSettingsDialogState extends State<EditGroupSettingsDialog> {
  late TextEditingController nameController;
  late IconData icon;
  late List<String> taetigkeiten;
  late bool showNonMembers;
  late bool showInactive;
  List<IconData> icons = [
    Icons.group,
    Icons.person,
    Icons.star,
    Icons.school,
  ];

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: widget.group?.key ?? '');
    icon = widget.group?.value.icon ?? Icons.group;
    taetigkeiten = widget.group?.value.taetigkeiten ?? [];
    showNonMembers = widget.group?.value.showNonMembers ?? false;
    showInactive = widget.group?.value.showInactive ?? false;
  }

  @override
  void dispose() {
    nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Eigen Gruppe bearbeiten'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Gruppenname'),
            ),
            const SizedBox(height: 16),
            Text('Icon', style: Theme.of(context).textTheme.bodyLarge),
            Wrap(
              spacing: 8.0,
              runSpacing: 8.0,
              children: icons.map((IconData i) {
                return ChoiceChip(
                  label: Icon(i),
                  selected: icon == i,
                  onSelected: (bool selected) {
                    if (selected) {
                      setState(() {
                        icon = i;
                      });
                    }
                  },
                );
              }).toList(),
            ),
            MultiDropdown<String>(
              items: widget.maxTaetigkeiten
                  .map((String item) => DropdownItem<String>(
                      value: item,
                      label: item,
                      selected: taetigkeiten.contains(item)))
                  .toList(),
              maxSelections: 4,
              chipDecoration: const ChipDecoration(
                  labelStyle: TextStyle(color: Colors.white),
                  backgroundColor: Colors.blue),
              dropdownItemDecoration: DropdownItemDecoration(
                backgroundColor: Theme.of(context).primaryColor,
                selectedBackgroundColor: Theme.of(context).primaryColor,
              ),
              onSelectionChange: (selectedItems) {
                setState(() {
                  taetigkeiten = selectedItems;
                });
              },
            ),
            const SizedBox(height: 16),
            CheckboxListTile(
              title: const Text('Zeige Nicht-Mitglieder'),
              value: showNonMembers,
              onChanged: (bool? value) {
                setState(() {
                  showNonMembers = value ?? false;
                });
              },
            ),
            CheckboxListTile(
              title: const Text('Zeige Inaktive'),
              value: showInactive,
              onChanged: (bool? value) {
                setState(() {
                  showInactive = value ?? false;
                });
              },
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('Abbrechen'),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(context).pop(MapEntry(
              nameController.text,
              CustomGroup(
                icon: icon,
                active: widget.group?.value.active ?? true,
                taetigkeiten: taetigkeiten,
                showNonMembers: showNonMembers,
                showInactive: showInactive,
              ),
            ));
          },
          child: const Text('Speichern'),
        ),
      ],
    );
  }
}
