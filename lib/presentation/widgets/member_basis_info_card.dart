import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nami/domain/member/member_utils.dart';
import 'package:nami/domain/member/mitglied.dart';
import 'package:nami/domain/member_filters/beitragsart.dart';
import 'package:nami/l10n/app_localizations.dart';
import 'package:nami/presentation/format/date_formatters.dart';
import 'package:nami/presentation/notifications/app_snackbar.dart';
import 'package:url_launcher/url_launcher_string.dart';

const double _memberDetailsCardRadius = 16;

/// Zeigt allgemeine Informationen zu einem Mitglied.
/// Input: Nur die Domain-Entität `Mitglied`.
class MemberGeneralInfoCard extends StatelessWidget {
  const MemberGeneralInfoCard({super.key, required this.mitglied});

  final Mitglied mitglied;

  @override
  Widget build(BuildContext context) {
    final hasKnownBirthday =
        mitglied.geburtsdatum != Mitglied.peoplePlaceholderDate;
    final alter = hasKnownBirthday ? MemberUtils.alterInJahren(mitglied) : null;
    final pronoun = mitglied.pronoun?.trim();
    final hasPronoun = pronoun != null && pronoun.isNotEmpty;

    final infoRows = <_InfoRow>[
      if (hasKnownBirthday)
        _InfoRow(
          icon: Icons.cake,
          label: AppLocalizations.of(context).t('member_info_birthday'),
          value:
              '$alter (${DateFormatter.formatGermanShortDate(mitglied.geburtsdatum)})',
        ),
      _InfoRow(
        icon: Icons.wc,
        label: 'Geschlecht',
        value: memberGenderLabel(context, mitglied.gender),
      ),
      if (hasPronoun)
        _InfoRow(
          icon: Icons.record_voice_over,
          label: 'Pronomen',
          value: pronoun,
        ),
    ];

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 5.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_memberDetailsCardRadius),
      ),
      child: Column(children: [...infoRows.map((r) => _InfoTile(row: r))]),
    );
  }
}

/// Kontaktangaben eines Mitglieds. Sichtbar sind die erste Telefonnummer und
/// die erste E-Mail-Adresse, weitere Eintraege lassen sich aufklappen.
class MemberContactInfoCard extends StatefulWidget {
  const MemberContactInfoCard({super.key, required this.mitglied});

  final Mitglied mitglied;

  @override
  State<MemberContactInfoCard> createState() => _MemberContactInfoCardState();
}

class _MemberContactInfoCardState extends State<MemberContactInfoCard> {
  bool _offen = false;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final mitglied = widget.mitglied;
    final telefonRows = mitglied.telefonnummern
        .map(
          (telefonnummer) => _InfoRow(
            icon: telefonnummer.label == Mitglied.phoneMobileLabel
                ? Icons.phone_android
                : Icons.call,
            label: telefonnummer.label ?? t.t('member_info_default_phone'),
            value: telefonnummer.wert,
            copy: true,
            isLink: true,
            linkType: 'tel',
          ),
        )
        .toList(growable: false);
    final emailRows = mitglied.emailAdressen
        .map(
          (emailAdresse) => _InfoRow(
            icon: Icons.email_outlined,
            label: emailAdresse.label ?? t.t('member_info_default_email'),
            value: emailAdresse.wert,
            copy: true,
            isLink: true,
            linkType: 'mailto',
          ),
        )
        .toList(growable: false);

    final sichtbar = <_InfoRow>[...telefonRows.take(1), ...emailRows.take(1)];
    final weitere = <_InfoRow>[...telefonRows.skip(1), ...emailRows.skip(1)];

    if (sichtbar.isEmpty) {
      sichtbar.add(
        _InfoRow(
          icon: Icons.contact_phone_outlined,
          label: 'Info',
          value: 'Keine Angaben vorhanden',
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 5.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_memberDetailsCardRadius),
      ),
      child: Column(
        children: [
          ...sichtbar.map((r) => _InfoTile(row: r)),
          if (_offen) ...weitere.map((r) => _InfoTile(row: r)),
          if (weitere.isNotEmpty)
            MemberAufklappZeile(
              offen: _offen,
              text: _offen
                  ? t.t('member_contact_less')
                  : _weitereText(
                      t,
                      telefon: telefonRows.length - 1,
                      email: emailRows.length - 1,
                    ),
              onTap: () => setState(() => _offen = !_offen),
            ),
        ],
      ),
    );
  }

  String _weitereText(
    AppLocalizations t, {
    required int telefon,
    required int email,
  }) {
    return <String>[
      if (telefon == 1) t.t('member_contact_more_phone'),
      if (telefon > 1) t.t('member_contact_more_phones', {'n': telefon}),
      if (email == 1) t.t('member_contact_more_email'),
      if (email > 1) t.t('member_contact_more_emails', {'n': email}),
    ].join(', ');
  }
}

/// Zeile zum Auf- und Zuklappen weiterer Eintraege in einer Detailkarte.
class MemberAufklappZeile extends StatelessWidget {
  const MemberAufklappZeile({
    super.key,
    required this.offen,
    required this.text,
    required this.onTap,
  });

  final bool offen;
  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final farbe = theme.colorScheme.primary;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        child: Row(
          children: [
            Flexible(
              child: Text(
                text,
                style: theme.textTheme.labelLarge?.copyWith(color: farbe),
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              offen ? Icons.expand_less : Icons.expand_more,
              size: 18,
              color: farbe,
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.copy = false,
    this.isLink = false,
    this.linkType,
  });
  final IconData icon;
  final String label;
  final String value;
  final bool copy;
  final bool isLink;
  final String? linkType; // 'mailto' | 'tel'
}

class _InfoTile extends StatefulWidget {
  const _InfoTile({required this.row});
  final _InfoRow row;

  @override
  State<_InfoTile> createState() => _InfoTileState();
}

class _InfoTileState extends State<_InfoTile> {
  static const _copyHighlightDuration = Duration(milliseconds: 700);
  static const _copyAnimationDuration = Duration(milliseconds: 180);
  static const _copyHighlightColor = Color(0xFF2E7D32);

  Timer? _copyHighlightTimer;
  bool _isCopyHighlighted = false;

  @override
  void dispose() {
    _copyHighlightTimer?.cancel();
    super.dispose();
  }

  Future<void> _copyValue() async {
    setState(() {
      _isCopyHighlighted = true;
    });

    _copyHighlightTimer?.cancel();
    _copyHighlightTimer = Timer(_copyHighlightDuration, () {
      if (!mounted) {
        return;
      }
      setState(() {
        _isCopyHighlighted = false;
      });
    });

    await Clipboard.setData(ClipboardData(text: widget.row.value));
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      leading: Icon(widget.row.icon, size: 20),
      title: _buildTitle(context),
      subtitle: Text(widget.row.label),
      trailing: widget.row.copy
          ? AnimatedScale(
              scale: _isCopyHighlighted ? 1.08 : 1,
              duration: _copyAnimationDuration,
              child: AnimatedContainer(
                key: const ValueKey('copy-highlight-container'),
                duration: _copyAnimationDuration,
                curve: Curves.easeOut,
                decoration: BoxDecoration(
                  color: _isCopyHighlighted
                      ? _copyHighlightColor.withValues(alpha: 0.14)
                      : Colors.transparent,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: Icon(
                    Icons.copy,
                    size: 18,
                    color: _isCopyHighlighted ? _copyHighlightColor : null,
                  ),
                  tooltip: AppLocalizations.of(context).t('common_copy'),
                  onPressed: _copyValue,
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildTitle(BuildContext context) {
    final theme = Theme.of(context);
    final maxStyle = theme.textTheme.titleMedium!;
    return LayoutBuilder(
      builder: (ctx, constraints) {
        final fittedStyle = _fitTextStyle(
          context: ctx,
          text: widget.row.value,
          base: maxStyle,
          maxWidth: constraints.maxWidth,
          maxSize: maxStyle.fontSize ?? 16,
          minSize: (maxStyle.fontSize ?? 16) * 0.8, // 80% minimal
        );

        if (!widget.row.isLink || widget.row.linkType == null) {
          return Text(
            widget.row.value,
            overflow: TextOverflow.ellipsis,
            style: fittedStyle,
          );
        }

        final scheme = widget.row.linkType!; // 'tel' oder 'mailto'
        final path = widget.row.value;
        final uri = Uri(scheme: scheme, path: path).toString();
        return RichText(
          textAlign: TextAlign.left,
          text: TextSpan(
            text: path,
            style: fittedStyle.copyWith(color: theme.colorScheme.primary),
            recognizer: TapGestureRecognizer()
              ..onTap = () async {
                if (await canLaunchUrlString(uri)) {
                  await launchUrlString(uri);
                } else {
                  AppSnackbar.show(
                    context,
                    message: AppLocalizations.of(
                      context,
                    ).t('member_info_link_open_failed'),
                    type: AppSnackbarType.error,
                  );
                }
              },
          ),
        );
      },
    );
  }

  TextStyle _fitTextStyle({
    required BuildContext context,
    required String text,
    required TextStyle base,
    required double maxWidth,
    required double maxSize,
    required double minSize,
  }) {
    double size = maxSize;
    final TextDirection dir = Directionality.of(context);
    while (size > minSize) {
      final style = base.copyWith(fontSize: size);
      final tp = TextPainter(
        text: TextSpan(text: text, style: style),
        maxLines: 1,
        textDirection: dir,
        ellipsis: '…',
      )..layout(minWidth: 0, maxWidth: maxWidth);
      if (tp.didExceedMaxLines == false) {
        return style;
      }
      size -= 1; // schrittweise verkleinern
    }
    return base.copyWith(fontSize: minSize);
  }
}

/// Zeigt Mitgliedschafts-Details: Mitgliedsnummer, Beitragsart, Stamm und
/// Gruppe.
class MemberMembershipInfoCard extends StatelessWidget {
  const MemberMembershipInfoCard({
    super.key,
    required this.mitglied,
    this.beitragsart,
    this.stammNamen = const <String>[],
    this.gruppenNamen = const <String>[],
    this.onEndMembership,
  });

  final Mitglied mitglied;
  final Beitragsart? beitragsart;
  final List<String> stammNamen;
  final List<String> gruppenNamen;
  final VoidCallback? onEndMembership;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    // Eintritt und Status stehen in Kachel und Kopf der Detailseite.
    final infoRows = <_InfoRow>[
      _InfoRow(
        icon: Icons.confirmation_number,
        label: t.t('member_info_member_number'),
        value: mitglied.mitgliedsnummer,
        copy: true,
      ),
      _InfoRow(
        icon: Icons.payments_outlined,
        label: 'Beitragsart',
        value: beitragsart?.displayName ?? '-',
      ),
      _InfoRow(
        icon: Icons.home_work_outlined,
        label: 'Stamm',
        value: _displayListeOderStrich(stammNamen),
      ),
      _InfoRow(
        icon: Icons.groups_outlined,
        label: 'Gruppe',
        value: _displayListeOderStrich(gruppenNamen),
      ),
    ];
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 5.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_memberDetailsCardRadius),
      ),
      child: Column(
        children: [
          ...infoRows.map((r) => _InfoTile(row: r)),
          if (onEndMembership != null)
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.redAccent),
              title: Text(
                t.t('member_info_end_membership'),
                style: TextStyle(color: Colors.redAccent),
              ),
              onTap: onEndMembership,
            ),
        ],
      ),
    );
  }
}

/// Anzeigetext fuer das Hitobito-Geschlecht, `-` wenn unbekannt.
String memberGenderLabel(BuildContext context, String? rawGender) {
  final normalized = rawGender?.trim().toLowerCase();
  final t = AppLocalizations.of(context);
  if (normalized == null || normalized.isEmpty) {
    return '-';
  }
  switch (normalized) {
    case 'm':
    case 'male':
    case 'maennlich':
    case 'männlich':
      return t.t('member_edit_gender_male');
    case 'w':
    case 'f':
    case 'female':
    case 'weiblich':
      return t.t('member_edit_gender_female');
    case 'd':
    case 'divers':
      return 'Divers';
    default:
      return rawGender!.trim();
  }
}

String _displayListeOderStrich(List<String> values) {
  final normalized = values
      .map((value) => value.trim())
      .where((value) => value.isNotEmpty)
      .toSet()
      .toList(growable: false);
  if (normalized.isEmpty) {
    return '-';
  }
  if (normalized.length == 1) {
    return normalized.first;
  }
  return normalized.join(', ');
}
