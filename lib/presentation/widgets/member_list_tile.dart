import 'package:flutter/material.dart';
import 'package:nami/domain/member/member_list_preferences.dart';
import 'package:nami/domain/member/member_utils.dart';
import 'package:nami/domain/member/mitglied.dart';
import 'package:nami/domain/taetigkeit/roles.dart';
import 'package:nami/presentation/format/date_formatters.dart';
import 'package:nami/presentation/stufe/stufe_visuals.dart';
import 'package:nami/presentation/theme/theme.dart';

class MemberSubtitleHighlight {
  const MemberSubtitleHighlight({
    required this.text,
    required this.matchStart,
    required this.matchEnd,
  }) : assert(matchStart >= 0),
       assert(matchEnd >= matchStart),
       assert(matchEnd <= text.length);

  final String text;
  final int matchStart;
  final int matchEnd;
}

class MemberListTile extends StatelessWidget {
  const MemberListTile({
    super.key,
    required this.mitglied,
    required this.isFavourite,
    required this.subtitleMode,
    this.showWarning = false,
    this.subtitleText,
    this.subtitleHighlight,
    this.trailingText,
    this.roleCategory,
    this.onTap,
    this.toggleFavorites,
  });

  final Mitglied mitglied;
  final bool isFavourite;
  final MemberSubtitleMode subtitleMode;
  final bool showWarning;
  final String? subtitleText;
  final MemberSubtitleHighlight? subtitleHighlight;
  final String? trailingText;
  final RoleCategory? roleCategory;
  final VoidCallback? onTap;
  final VoidCallback? toggleFavorites;

  @override
  Widget build(BuildContext context) {
    final stufe = MemberUtils.aktiveStufe(mitglied);
    final resolvedTrailingText = trailingText
        ?.split(' - ')
        .where((segment) => segment.isNotEmpty)
        .join('\n');
    final resolvedSubtitle =
        subtitleText ??
        () {
          switch (subtitleMode) {
            case MemberSubtitleMode.mitgliedsnummer:
              return mitglied.mitgliedsnummer;
            case MemberSubtitleMode.geburtstag:
              return DateFormatter.formatGermanLongDate(mitglied.geburtsdatum);
            case MemberSubtitleMode.spitzname:
              return mitglied.fahrtenname ?? '';
            case MemberSubtitleMode.eintrittsdatum:
              return DateFormatter.formatGermanLongDate(
                mitglied.eintrittsdatum,
              );
          }
        }();
    final isSonstiges = roleCategory == RoleCategory.sonstiges;
    final primaryColor = stufe != null
        ? StufeVisuals.colorFor(stufe)
        : DPSGColors.keineStufeFarbe;
    final secondaryColor = MemberUtils.isLeitung(mitglied)
        ? DPSGColors.leiterFarbe
        : primaryColor;
    final stripeColor = Theme.of(context).colorScheme.outline;
    final subtitleWidget = subtitleHighlight != null
        ? _HighlightedSubtitle(highlight: subtitleHighlight!)
        : Text(resolvedSubtitle);

    final tile = Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Dismissible(
        key: Key(mitglied.mitgliedsnummer),
        direction: DismissDirection.endToStart,
        confirmDismiss: (direction) async {
          if (toggleFavorites != null) {
            toggleFavorites!();
          }
          return false;
        },
        onDismissed: (_) {},
        background: Container(
          decoration: BoxDecoration(
            color: isFavourite ? Colors.red : Colors.amber,
            borderRadius: BorderRadius.circular(16),
          ),
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Icon(
            isFavourite ? Icons.bookmark_remove : Icons.bookmark_add,
            color: Colors.white,
          ),
        ),
        child: Material(
          color: Theme.of(context).colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Theme.of(context).colorScheme.outline),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(0, 12, 16, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 4,
                    height: 42,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      color: isSonstiges ? stripeColor : null,
                      gradient: isSonstiges
                          ? null
                          : LinearGradient(
                              colors: [secondaryColor, primaryColor],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              stops: const [0.5, 0.5],
                            ),
                      borderRadius: const BorderRadius.horizontal(
                        right: Radius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${mitglied.vorname} ${mitglied.nachname}'.trim(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                        ),
                        const SizedBox(height: 2),
                        DefaultTextStyle.merge(
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                fontSize: 13,
                                color: Theme.of(
                                  context,
                                ).colorScheme.outlineVariant,
                              ),
                          child: subtitleWidget,
                        ),
                      ],
                    ),
                  ),
                  if (resolvedTrailingText != null &&
                      resolvedTrailingText.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 140),
                      child: Text(
                        resolvedTrailingText,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.outlineVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                  if (showWarning) ...[
                    const SizedBox(width: 8),
                    const Tooltip(
                      message: 'Offener Problemfall',
                      child: Icon(
                        Icons.warning_amber_rounded,
                        color: Colors.orange,
                        size: 20,
                      ),
                    ),
                  ],
                  if (isFavourite) ...[
                    const SizedBox(width: 8),
                    const Icon(Icons.bookmark, size: 18, color: Colors.amber),
                  ],
                  const SizedBox(width: 6),
                  Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    return tile;
  }
}

class _HighlightedSubtitle extends StatelessWidget {
  const _HighlightedSubtitle({required this.highlight});

  final MemberSubtitleHighlight highlight;

  @override
  Widget build(BuildContext context) {
    final baseStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
      fontSize: 13,
      color: Theme.of(context).colorScheme.outlineVariant,
    );
    final highlightedStyle = baseStyle?.copyWith(
      color: Theme.of(context).colorScheme.primary,
      fontWeight: FontWeight.w700,
    );
    final prefix = highlight.text.substring(0, highlight.matchStart);
    final match = highlight.text.substring(
      highlight.matchStart,
      highlight.matchEnd,
    );
    final suffix = highlight.text.substring(highlight.matchEnd);

    return RichText(
      text: TextSpan(
        style: baseStyle,
        children: <InlineSpan>[
          TextSpan(text: prefix),
          TextSpan(text: match, style: highlightedStyle),
          TextSpan(text: suffix),
        ],
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }
}
