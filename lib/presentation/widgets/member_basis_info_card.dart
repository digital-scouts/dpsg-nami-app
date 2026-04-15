import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nami/domain/member/member_utils.dart';
import 'package:nami/domain/member/mitglied.dart';
import 'package:nami/presentation/format/date_formatters.dart';
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
    final telefonRows = mitglied.telefonnummern
        .map(
          (telefonnummer) => _InfoRow(
            icon: telefonnummer.label == Mitglied.phoneMobileLabel
                ? Icons.phone_android
                : Icons.call,
            label: telefonnummer.label ?? 'Telefonnummer',
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
            icon: Icons.email,
            label: emailAdresse.label ?? 'E-Mail',
            value: emailAdresse.wert,
            copy: true,
            isLink: true,
            linkType: 'mailto',
          ),
        )
        .toList(growable: false);

    final infoRows = <_InfoRow>[
      if (hasKnownBirthday)
        _InfoRow(
          icon: Icons.cake,
          label: 'Geburtstag',
          value:
              '$alter (${DateFormatter.formatGermanShortDate(mitglied.geburtsdatum)})',
        ),
      if (mitglied.fahrtenname != null && mitglied.fahrtenname!.isNotEmpty)
        _InfoRow(
          icon: Icons.tag,
          label: 'Fahrtenname',
          value: mitglied.fahrtenname!,
        ),
      ...telefonRows,
      ...emailRows,
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
                  tooltip: 'Kopieren',
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
            style: fittedStyle.copyWith(color: Colors.blue),
            recognizer: TapGestureRecognizer()
              ..onTap = () async {
                if (await canLaunchUrlString(uri)) {
                  await launchUrlString(uri);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Kann Link nicht öffnen')),
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

/// Zeigt Mitgliedschafts-Infos: Mitgliedsnummer, Eintrittsdatum, Status und Button.
class MemberMembershipInfoCard extends StatelessWidget {
  const MemberMembershipInfoCard({
    super.key,
    required this.mitglied,
    this.onEndMembership,
  });

  final Mitglied mitglied;
  final VoidCallback? onEndMembership;

  @override
  Widget build(BuildContext context) {
    final hasKnownEntryDate =
        mitglied.eintrittsdatum != Mitglied.peoplePlaceholderDate;
    final infoRows = <_InfoRow>[
      _InfoRow(
        icon: Icons.confirmation_number,
        label: 'Mitgliedsnummer',
        value: mitglied.mitgliedsnummer,
        copy: true,
      ),
      if (hasKnownEntryDate)
        _InfoRow(
          icon: Icons.login,
          label: 'Eintrittsdatum',
          value: DateFormatter.formatGermanShortDate(mitglied.eintrittsdatum),
        ),
      if (mitglied.updatedAt != null)
        _InfoRow(
          icon: Icons.update,
          label: 'Zuletzt aktualisiert',
          value: DateFormatter.formatGermanShortDateTime(mitglied.updatedAt!),
        ),
      _InfoRow(
        icon: mitglied.istAusgetreten ? Icons.cancel : Icons.check_circle,
        label: 'Status',
        value: mitglied.istAusgetreten ? 'Beendet' : 'Aktiv',
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
              title: const Text(
                'Mitgliedschaft beenden',
                style: TextStyle(color: Colors.redAccent),
              ),
              onTap: onEndMembership,
            ),
        ],
      ),
    );
  }
}
