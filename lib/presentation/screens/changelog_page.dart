import 'package:flutter/material.dart';
import 'package:nami/l10n/app_localizations.dart';
import 'package:nami/presentation/widgets/changelog_widget.dart';

class ChangelogPage extends StatelessWidget {
  const ChangelogPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).t('changelog_title')),
      ),
      body: const ChangelogWidget(),
    );
  }
}
