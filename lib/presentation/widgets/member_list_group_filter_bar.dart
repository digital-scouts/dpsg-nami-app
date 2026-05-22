import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

class GroupFilterItem {
  final String keyName;
  final Color? chipColor;
  final IconData? iconData;
  final String? semanticLabel;
  final String label;

  const GroupFilterItem({
    required this.keyName,
    required this.label,
    this.chipColor,
    this.iconData,
    this.semanticLabel,
  });
}

class GroupFilterBar extends StatefulWidget {
  final List<GroupFilterItem> items;
  final Set<String> selectedKeys;
  final ValueChanged<Set<String>> onChanged;
  final EdgeInsetsGeometry padding;

  const GroupFilterBar({
    super.key,
    required this.items,
    required this.selectedKeys,
    required this.onChanged,
    this.padding = const EdgeInsets.fromLTRB(16, 0, 16, 8),
  });

  @override
  State<GroupFilterBar> createState() => _GroupFilterBarState();
}

class _GroupFilterBarState extends State<GroupFilterBar> {
  static const double _chipHeight = 34;
  static const double _chipSpacing = 8;
  static const double _chipRunSpacing = 8;

  bool _expanded = false;

  @override
  void didUpdateWidget(covariant GroupFilterBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.items.length != oldWidget.items.length && _expanded) {
      setState(() {
        _expanded = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final t = AppLocalizations.of(context);

    return Padding(
      padding: widget.padding,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final rowCount = _estimateRowCount(
            maxWidth: constraints.maxWidth,
            items: widget.items,
            theme: theme,
          );
          final isExpandable = rowCount > 2;
          final visibleRows = _expanded
              ? rowCount
              : rowCount.clamp(1, 2).toInt();
          final maxHeight = _heightForRows(visibleRows);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ClipRect(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  constraints: BoxConstraints(maxHeight: maxHeight),
                  child: Wrap(
                    spacing: _chipSpacing,
                    runSpacing: _chipRunSpacing,
                    alignment: WrapAlignment.center,
                    runAlignment: WrapAlignment.center,
                    children: widget.items
                        .map(
                          (item) => _buildChip(
                            context,
                            item,
                            isActive: widget.selectedKeys.contains(
                              item.keyName,
                            ),
                          ),
                        )
                        .toList(growable: false),
                  ),
                ),
              ),
              if (isExpandable)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: theme.colorScheme.outlineVariant,
                      visualDensity: VisualDensity.compact,
                      textStyle: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    onPressed: () => setState(() => _expanded = !_expanded),
                    icon: Icon(
                      _expanded ? Icons.expand_less : Icons.expand_more,
                      size: 18,
                    ),
                    label: Text(
                      _expanded
                          ? t.t('member_filter_chips_collapse')
                          : t.t('member_filter_chips_expand'),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  double _heightForRows(int rowCount) {
    if (rowCount <= 0) {
      return 0;
    }
    return rowCount * _chipHeight + (rowCount - 1) * _chipRunSpacing;
  }

  int _estimateRowCount({
    required double maxWidth,
    required List<GroupFilterItem> items,
    required ThemeData theme,
  }) {
    if (maxWidth.isInfinite || maxWidth <= 0) {
      return 1;
    }
    final textStyle = theme.textTheme.labelMedium?.copyWith(
      fontSize: 13,
      fontWeight: FontWeight.w500,
    );
    var rows = 1;
    var currentLineWidth = 0.0;

    for (final item in items) {
      final itemWidth = _estimateChipWidth(item, textStyle) + 3;
      final requiredWidth = currentLineWidth == 0
          ? itemWidth
          : currentLineWidth + _chipSpacing + itemWidth;
      if (requiredWidth <= maxWidth) {
        currentLineWidth = requiredWidth;
      } else {
        rows += 1;
        currentLineWidth = itemWidth;
      }
    }
    return rows;
  }

  double _estimateChipWidth(GroupFilterItem item, TextStyle? textStyle) {
    final textPainter = TextPainter(
      text: TextSpan(text: item.label, style: textStyle),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    final indicatorWidth = item.iconData != null ? 15.0 : 8.0;
    return 12 + indicatorWidth + 6 + textPainter.width + 12;
  }

  Widget _buildChip(
    BuildContext context,
    GroupFilterItem item, {
    required bool isActive,
  }) {
    final theme = Theme.of(context);
    final semanticLabel = item.semanticLabel ?? '${item.keyName} Filter';
    final accentColor = item.chipColor ?? theme.colorScheme.primary;
    final chipBackgroundColor = isActive
        ? accentColor.withValues(
            alpha: theme.brightness == Brightness.dark ? 0.3 : 0.12,
          )
        : theme.colorScheme.surface;
    final chipBorderColor = isActive
        ? accentColor
        : theme.colorScheme.outline.withValues(alpha: 0.55);
    final chipTextColor = isActive ? accentColor : theme.colorScheme.onSurface;

    return Semantics(
      label: semanticLabel,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () {
          final next = Set<String>.from(widget.selectedKeys);
          if (isActive) {
            next.remove(item.keyName);
          } else {
            next.add(item.keyName);
          }
          widget.onChanged(next);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOut,
          height: _chipHeight,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: chipBackgroundColor,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: chipBorderColor, width: 1.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (item.iconData != null) ...[
                Icon(item.iconData, size: 15, color: chipTextColor),
              ] else ...[
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: accentColor,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
              const SizedBox(width: 6),
              Text(
                item.label,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: chipTextColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
