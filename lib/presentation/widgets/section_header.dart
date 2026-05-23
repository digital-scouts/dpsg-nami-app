import 'package:flutter/material.dart';

class DpsgSectionHeader extends StatelessWidget {
  const DpsgSectionHeader({
    super.key,
    required this.label,
    this.padding = const EdgeInsets.only(left: 4, bottom: 6),
    this.uppercase = true,
    this.color,
  });

  final String label;
  final EdgeInsetsGeometry padding;
  final bool uppercase;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = uppercase ? label.toUpperCase() : label;

    return Padding(
      padding: padding,
      child: Text(
        text,
        style: theme.textTheme.labelMedium?.copyWith(
          color: color ?? theme.colorScheme.primary,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}
