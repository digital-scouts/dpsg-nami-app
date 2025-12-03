import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';

class MemberSearchBar extends StatelessWidget {
  const MemberSearchBar({
    super.key,
    required this.initial,
    required this.onChanged,
  });
  final String initial;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
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
            fillColor: Colors.white.withValues(alpha: 0.05),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 10,
            ),
            border: const OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(10)),
              borderSide: BorderSide.none,
            ),
            prefixIcon: const Icon(Icons.search),
            hintText: 'Suche nach Name, Mail, Telefon oder Mitgliedsnummer',
          ),
        ),
      ),
    );
  }
}
