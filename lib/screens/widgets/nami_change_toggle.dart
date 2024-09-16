import 'package:flutter/material.dart';
import 'package:nami/utilities/hive/settings.dart';
import 'package:wiredash/wiredash.dart';

class NamiChangeToggle extends StatefulWidget {
  final bool showEditIcon;

  const NamiChangeToggle({super.key, this.showEditIcon = true});

  @override
  State<NamiChangeToggle> createState() => _NamiChangeToggleState();
}

class _NamiChangeToggleState extends State<NamiChangeToggle> {
  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: const Text('Erlaube Datenänderungen durch den Nutzer'),
      leading: widget.showEditIcon ? const Icon(Icons.edit) : null,
      onTap: () {
        Wiredash.trackEvent('Settings', data: {
          'type': 'toggle nami changes',
          'value': !getNamiChangesEnabled()
        });
        setNamiChangesEnabled(!getNamiChangesEnabled());
        setState(() {});
      },
      trailing: Switch(
        value: getNamiChangesEnabled(),
        onChanged: (value) {
          setNamiChangesEnabled(value);
          setState(() {});
        },
      ),
    );
  }
}
