import 'package:flutter/material.dart';
import 'package:nami/domain/stufe/altersgrenzen.dart';
import 'package:nami/domain/taetigkeit/stufe.dart';
import 'package:nami/presentation/stufe/stufe_visuals.dart';

class StufenwechselSettingsMinMax extends StatefulWidget {
  final DateTime? nextStufenwechsel;
  final Altersgrenzen grenzen;
  final void Function(DateTime? date)? onDateChanged;
  final void Function(Altersgrenzen grenzen)? onSave;
  final Altersgrenzen Function()? onResetDefaults;

  const StufenwechselSettingsMinMax({
    super.key,
    this.nextStufenwechsel,
    required this.grenzen,
    this.onDateChanged,
    this.onSave,
    this.onResetDefaults,
  });

  @override
  State<StufenwechselSettingsMinMax> createState() =>
      _StufenwechselSettingsMinMaxState();
}

class _StufenwechselSettingsMinMaxState
    extends State<StufenwechselSettingsMinMax> {
  late Altersgrenzen _grenzen;
  late Map<Stufe, TextEditingController> _minControllers;
  late Map<Stufe, TextEditingController> _maxControllers;

  @override
  void initState() {
    super.initState();
    _grenzen = widget.grenzen;
    _initControllers();
  }

  void _initControllers() {
    _minControllers = {};
    _maxControllers = {};
    for (final stufe in Stufe.values.where((s) => s != Stufe.leitung)) {
      final interval = _grenzen.forStufe(stufe);
      _minControllers[stufe] = TextEditingController(
        text: interval.minJahre.toString(),
      );
      _maxControllers[stufe] = TextEditingController(
        text: interval.maxJahre.toString(),
      );
    }
  }

  @override
  void didUpdateWidget(covariant StufenwechselSettingsMinMax oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.grenzen != widget.grenzen) {
      _grenzen = widget.grenzen;
      _disposeControllers();
      _initControllers();
    }
  }

  void _disposeControllers() {
    for (final controller in _minControllers.values) {
      controller.dispose();
    }
    for (final controller in _maxControllers.values) {
      controller.dispose();
    }
  }

  @override
  void dispose() {
    _disposeControllers();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stufen = Stufe.values.where((s) => s != Stufe.leitung).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var index = 0; index < stufen.length; index++)
          _buildAgeRow(
            context: context,
            stufe: stufen[index],
            showDivider: index < stufen.length - 1,
          ),
      ],
    );
  }

  Widget _buildAgeRow({
    required BuildContext context,
    required Stufe stufe,
    required bool showDivider,
  }) {
    final theme = Theme.of(context);
    final stufeColor = StufeVisuals.colorFor(stufe);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: showDivider
            ? Border(
                bottom: BorderSide(
                  color: theme.colorScheme.outline.withValues(alpha: 0.28),
                ),
              )
            : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: stufeColor,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Image.asset(
                StufeVisuals.assetFor(stufe),
                width: 20,
                height: 20,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stack) =>
                    const Icon(Icons.group),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              stufe.displayName,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          _buildInputField(
            context: context,
            controller: _minControllers[stufe],
            hintText: 'Min',
            onChanged: () => _updateAltergrenzen(stufe),
          ),
          const SizedBox(width: 6),
          Text(
            '–',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outlineVariant,
            ),
          ),
          const SizedBox(width: 6),
          _buildInputField(
            context: context,
            controller: _maxControllers[stufe],
            hintText: 'Max',
            onChanged: () => _updateAltergrenzen(stufe),
          ),
          const SizedBox(width: 8),
          Text(
            'Jahre',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outlineVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputField({
    required BuildContext context,
    required TextEditingController? controller,
    required String hintText,
    required VoidCallback onChanged,
  }) {
    final theme = Theme.of(context);

    return SizedBox(
      width: 44,
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        decoration: InputDecoration(
          isDense: true,
          hintText: hintText,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 6,
          ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: theme.colorScheme.outline),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: theme.colorScheme.primary),
          ),
        ),
        style: theme.textTheme.bodySmall,
        onChanged: (_) => onChanged(),
      ),
    );
  }

  void _updateAltergrenzen(Stufe stufe) {
    final minText = _minControllers[stufe]?.text ?? '';
    final maxText = _maxControllers[stufe]?.text ?? '';
    final minVal = int.tryParse(minText);
    final maxVal = int.tryParse(maxText);

    if (minVal != null && maxVal != null && minVal <= maxVal) {
      setState(() {
        final interval = _grenzen.forStufe(stufe);
        _grenzen = _grenzen.copyWithFor(
          stufe,
          interval.copyWith(minJahre: minVal, maxJahre: maxVal),
        );
      });
    }
  }
}
