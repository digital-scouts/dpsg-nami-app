import 'package:flutter/material.dart';
import 'package:nami/ignore_deprecated_utilities/nami/model/nami_gruppierung.model.dart';

class ChooseGruppierungWidget extends StatelessWidget {
  final List<NamiGruppierungModel> gruppierungen;
  final ValueChanged<NamiGruppierungModel> onGruppierungSelected;

  const ChooseGruppierungWidget({
    super.key,
    required this.gruppierungen,
    required this.onGruppierungSelected,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Gruppierung auswählen'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Du hast Zugriff auf mehrere Gruppierungen, bitte wähle eine Gruppierung aus. Du kannst die Gruppierung später ändern.',
          ),
          const SizedBox(height: 20),
          DropdownButton<NamiGruppierungModel>(
            items: gruppierungen.map((NamiGruppierungModel gruppierung) {
              return DropdownMenuItem<NamiGruppierungModel>(
                value: gruppierung,
                child: Text(gruppierung.name),
              );
            }).toList(),
            onChanged: (NamiGruppierungModel? selectedGruppierung) {
              if (selectedGruppierung != null) {
                onGruppierungSelected(selectedGruppierung);
                Navigator.of(context).pop();
              } else {}
            },
          ),
        ],
      ),
    );
  }
}
