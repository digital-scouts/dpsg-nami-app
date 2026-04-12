import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';

import '../../l10n/app_localizations.dart';

class MemberSearchBar extends StatelessWidget {
  const MemberSearchBar({
    super.key,
    required this.initial,
    required this.onChanged,
    this.onTunePressed,
  });
  final String initial;
  final ValueChanged<String> onChanged;
  final VoidCallback? onTunePressed;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      child: Row(
        children: [
          Expanded(
            child: FormBuilder(
              child: FormBuilderTextField(
                name: 'search',
                initialValue: initial,
                onChanged: (v) => onChanged(v ?? ''),
                enableSuggestions: false,
                autocorrect: false,
                autofillHints: null,
                decoration: InputDecoration(
                  hintStyle: Theme.of(context).textTheme.bodySmall,
                  filled: true,
                  fillColor: () {
                    final theme = Theme.of(context);
                    final themed = theme.inputDecorationTheme.fillColor;
                    return themed;
                  }(),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 10,
                  ),
                  border: const OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(10)),
                    borderSide: BorderSide.none,
                  ),
                  prefixIcon: const Icon(Icons.search),
                  hintText: t.t('member_list_search_hint'),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.tune),
            tooltip: t.t('member_filter_open_tooltip'),
            onPressed: onTunePressed,
          ),
        ],
      ),
    );
  }
}
