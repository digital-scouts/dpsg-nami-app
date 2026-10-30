import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:nami/domain/appearance/appearance_catalog.dart';
import 'package:nami/l10n/app_localizations.dart';
import 'package:nami/presentation/model/arbeitskontext_model.dart';
import 'package:nami/presentation/theme/theme.dart';
import 'package:nami/presentation/widgets/app_startbuehne.dart';
// ignore: depend_on_referenced_packages
import 'package:storybook_flutter/storybook_flutter.dart';

/// Startbühne (#279): Knoten, Status, Checkliste und Sperre mit wählbarer
/// Ladezeit. Ein neuer Wert in den Knobs startet den Ablauf neu. Die Bühne
/// bleibt immer Standard; die Supporter-Palette wirkt nur auf den Inhalt.
Story appStartbuehneStory() => Story(
  name: 'Start/Startbühne',
  builder: (context) {
    final dark = context.knobs.boolean(label: 'Dunkel', initial: false);
    final reduziert = context.knobs.boolean(
      label: 'Bewegung reduzieren',
      initial: false,
    );
    final palette = context.knobs.options<AppPaletteId>(
      label: 'Palette (Inhalt)',
      initial: AppPaletteId.standard,
      options: [
        for (final p in AppPaletteId.values) Option(label: p.name, value: p),
      ],
    );
    final ladezeit = context.knobs.options<int>(
      label: 'Ladezeit',
      initial: 3000,
      options: const [
        Option(label: 'kurz 0,2 s (nur Abgang)', value: 200),
        Option(label: 'mittel 1 s (Knoten)', value: 1000),
        Option(label: 'lang 3 s (Status)', value: 3000),
        Option(label: 'endlos', value: 0),
      ],
    );
    final art = context.knobs.options<String>(
      label: 'Fall',
      initial: 'status',
      options: const [
        Option(label: 'Kaltstart', value: 'status'),
        Option(label: 'Erstanmeldung (Checkliste)', value: 'checkliste'),
        Option(label: 'Kaltstart mit App-Sperre', value: 'sperre'),
      ],
    );
    final brightness = dark ? Brightness.dark : Brightness.light;
    return MaterialApp(
      key: ValueKey('$dark-$reduziert-$palette-$ladezeit-$art'),
      theme: buildTheme(palette, Brightness.light),
      darkTheme: buildTheme(palette, Brightness.dark),
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      localizationsDelegates: [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        AppLocalizations.delegate,
      ],
      supportedLocales: const [Locale('de'), Locale('en')],
      locale: const Locale('de'),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          platformBrightness: brightness,
          disableAnimations: reduziert,
        ),
        child: _Ablauf(ladezeit: ladezeit, art: art, child: child!),
      ),
      home: Scaffold(
        appBar: AppBar(title: const Text('Mitglieder')),
        body: ListView(
          children: [
            for (final name in const [
              'Lena Albrecht',
              'Mats Brandt',
              'Sami Engel',
            ])
              ListTile(title: Text(name)),
          ],
        ),
      ),
    );
  },
);

class _Ablauf extends StatefulWidget {
  const _Ablauf({
    required this.ladezeit,
    required this.art,
    required this.child,
  });

  final int ladezeit;
  final String art;
  final Widget child;

  @override
  State<_Ablauf> createState() => _AblaufState();
}

class _AblaufState extends State<_Ablauf> {
  late final ValueNotifier<StartbuehneLage> _lage = ValueNotifier(_start());

  static const _schritte = [
    ArbeitskontextLoadingStepStatus(
      labelKey: 'nav_work_context_step_login',
      state: ArbeitskontextLoadingStepState.done,
    ),
    ArbeitskontextLoadingStepStatus(
      labelKey: 'nav_work_context_step_groups',
      state: ArbeitskontextLoadingStepState.done,
      detailKey: 'nav_work_context_step_groups_done',
      detailCount: 3,
    ),
    ArbeitskontextLoadingStepStatus(
      labelKey: 'nav_work_context_step_members',
      state: ArbeitskontextLoadingStepState.loading,
    ),
    ArbeitskontextLoadingStepStatus(
      labelKey: 'nav_work_context_step_roles',
      state: ArbeitskontextLoadingStepState.waiting,
    ),
  ];

  StartbuehneLage _start() => switch (widget.art) {
    'sperre' => const StartbuehneLage(laedt: false, gesperrt: true),
    'checkliste' => const StartbuehneLage(laedt: true, schritte: _schritte),
    _ => const StartbuehneLage(
      laedt: true,
      statusKey: 'nav_work_context_loading_title',
    ),
  };

  @override
  void initState() {
    super.initState();
    if (widget.ladezeit > 0 && widget.art != 'sperre') {
      Future<void>.delayed(Duration(milliseconds: widget.ladezeit), () {
        if (mounted) {
          _lage.value = StartbuehneLage.bereitLage;
        }
      });
    }
  }

  @override
  void dispose() {
    _lage.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppStartbuehne(
      lage: _lage,
      onEntsperren: () => _lage.value = StartbuehneLage.bereitLage,
      child: widget.child,
    );
  }
}
