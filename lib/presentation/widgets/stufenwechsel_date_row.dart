import 'package:flutter/material.dart';
import 'package:nami/l10n/app_localizations.dart';
import 'package:nami/presentation/format/date_formatters.dart';

class StufenwechselDateRow extends StatefulWidget {
  final DateTime? date;
  final void Function(DateTime? date)? onDateChanged;

  const StufenwechselDateRow({super.key, this.date, this.onDateChanged});

  @override
  State<StufenwechselDateRow> createState() => _StufenwechselDateRowState();
}

class _StufenwechselDateRowState extends State<StufenwechselDateRow> {
  late DateTime? _date;

  @override
  void initState() {
    super.initState();
    _date = widget.date;
  }

  @override
  void didUpdateWidget(covariant StufenwechselDateRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.date != widget.date) {
      _date = widget.date;
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? now,
      firstDate: now.subtract(const Duration(days: 365 * 2)),
      lastDate: now.add(const Duration(days: 365 * 2)),
    );
    if (picked != null) {
      setState(() => _date = picked);
      widget.onDateChanged?.call(_date);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = AppLocalizations.of(context);

    return InkWell(
      onTap: _pickDate,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t.t('stufenwechsel_date_title'),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    t.t('stufenwechsel_date_hint'),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outlineVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _date == null
                        ? t.t('no_date_chosen')
                        : DateFormatter.formatGermanLongDate(_date!),
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Icon(Icons.calendar_month, color: theme.colorScheme.outlineVariant),
          ],
        ),
      ),
    );
  }
}
