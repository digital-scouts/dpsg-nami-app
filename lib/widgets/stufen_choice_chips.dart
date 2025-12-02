import 'package:flutter/material.dart';
import 'package:nami/domain/taetigkeit/stufe.dart';
import 'package:nami/presentation/stufe/stufe_visuals.dart';

class StufenChoiceChips extends StatelessWidget {
  final bool showBiber;
  final Stufe ausgewaehlteStufe;
  final void Function(Stufe stufe)? onChanged;

  const StufenChoiceChips({
    super.key,
    required this.showBiber,
    required this.ausgewaehlteStufe,
    this.onChanged,
  });

  List<Stufe> _buildStufen() {
    final list = <Stufe>[
      if (showBiber) Stufe.biber,
      Stufe.woelfling,
      Stufe.jungpfadfinder,
      Stufe.pfadfinder,
      Stufe.rover,
    ];
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final stufen = _buildStufen();
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: stufen.map((stufe) {
        return ChoiceChip(
          selected: stufe == ausgewaehlteStufe,
          onSelected: (selected) {
            if (selected && onChanged != null) onChanged!(stufe);
          },
          label: Text(stufe.shortDisplayName),
          showCheckmark: false,
          avatar: CircleAvatar(
            backgroundColor: Colors.transparent,
            child: Image.asset(StufeVisuals.assetFor(stufe), cacheHeight: 50),
          ),
        );
      }).toList(),
    );
  }
}
