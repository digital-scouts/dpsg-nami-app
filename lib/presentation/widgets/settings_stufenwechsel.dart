import 'package:flutter/material.dart';
import 'package:nami/domain/stufe/altersgrenzen.dart';
import 'package:nami/domain/taetigkeit/stufe.dart';
import 'package:nami/presentation/stufe/stufe_visuals.dart';
import 'package:syncfusion_flutter_core/theme.dart';
import 'package:syncfusion_flutter_sliders/sliders.dart';

class StufenwechselSettings extends StatefulWidget {
  final DateTime? nextStufenwechsel;
  final Altersgrenzen grenzen;
  final void Function(DateTime? date)? onDateChanged;
  final void Function(Altersgrenzen grenzen)? onSave;
  final Altersgrenzen Function()? onResetDefaults;

  const StufenwechselSettings({
    super.key,
    this.nextStufenwechsel,
    required this.grenzen,
    this.onDateChanged,
    this.onSave,
    this.onResetDefaults,
  });

  @override
  State<StufenwechselSettings> createState() => _StufenwechselSettingsState();
}

class _StufenwechselSettingsState extends State<StufenwechselSettings> {
  late Altersgrenzen _grenzen;

  @override
  void initState() {
    super.initState();
    _grenzen = widget.grenzen;
  }

  @override
  void didUpdateWidget(covariant StufenwechselSettings oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.grenzen != widget.grenzen) {
      _grenzen = widget.grenzen;
    }
  }

  Widget _ageEditorsForStufe(Stufe stufe) {
    final interval = _grenzen.forStufe(stufe);
    final defaults = StufenDefaults.build();
    final globalMinBound = defaults.forStufe(Stufe.biber).minJahre;
    final globalMaxBound = defaults.forStufe(Stufe.rover).maxJahre;
    final stufeColor = StufeVisuals.colorFor(stufe);

    return SfRangeSliderTheme(
      data: SfRangeSliderThemeData(
        tooltipBackgroundColor: stufeColor,
        tooltipTextStyle: const TextStyle(color: Colors.white),
      ),
      child: SfRangeSlider(
        min: globalMinBound.toDouble(),
        max: globalMaxBound.toDouble(),
        interval: 2,
        stepSize: 1,
        showTicks: true,
        showLabels: true,
        enableTooltip: true,
        activeColor: stufeColor,
        inactiveColor: stufeColor.withAlpha(77),
        values: SfRangeValues(
          interval.minJahre.toDouble(),
          interval.maxJahre.toDouble(),
        ),
        onChanged: (SfRangeValues values) {
          final newMin = (values.start as double).round();
          final newMax = (values.end as double).round();
          setState(() {
            _grenzen = _grenzen.copyWithFor(
              stufe,
              interval.copyWith(minJahre: newMin, maxJahre: newMax),
            );
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final stufe in Stufe.values.where(
                (s) => s != Stufe.leitung,
              )) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 48,
                      height: 48,
                      child: Card(
                        elevation: 3,
                        color: theme.colorScheme.surfaceContainerHighest,
                        surfaceTintColor: Colors.transparent,
                        shadowColor: theme.colorScheme.surface,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(6),
                          child: Center(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: Image.asset(
                                StufeVisuals.assetFor(stufe),
                                width: 35.0,
                                height: 35.0,
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stack) =>
                                    const Icon(Icons.group),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: _ageEditorsForStufe(stufe)),
                  ],
                ),
                const SizedBox(height: 12),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
