import 'package:flutter/material.dart';
import 'package:nami/domain/taetigkeit/stufe.dart';
import 'package:nami/presentation/stufe/stufe_visuals.dart';

class StufenChoiceChips extends StatelessWidget {
  final bool singleSelect;
  final bool showLeader;
  final bool showBiber;
  final Set<Stufe> ausgewaehlteStufen;
  final void Function(Set<Stufe> stufen)? ausgewaehlteStufenChanged;

  const StufenChoiceChips({
    super.key,
    required this.singleSelect,
    required this.showBiber,
    required this.showLeader,
    required this.ausgewaehlteStufen,
    this.ausgewaehlteStufenChanged,
  });

  List<Stufe> _buildStufen() {
    final list = <Stufe>[
      if (showBiber) Stufe.biber,
      Stufe.woelfling,
      Stufe.jungpfadfinder,
      Stufe.pfadfinder,
      Stufe.rover,
      if (showLeader) Stufe.leitung,
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
          selected: ausgewaehlteStufen.contains(stufe),
          onSelected: (selected) {
            if (ausgewaehlteStufenChanged == null) return;
            final next = Set<Stufe>.from(ausgewaehlteStufen);
            if (singleSelect) {
              if (selected) {
                next
                  ..clear()
                  ..add(stufe);
              } else {
                return;
              }
            } else {
              if (selected) {
                next.add(stufe);
              } else {
                next.remove(stufe);
              }
            }
            ausgewaehlteStufenChanged!(next);
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
