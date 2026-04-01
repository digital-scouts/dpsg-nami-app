import 'package:flutter/material.dart';
import 'package:nami/domain/member/member_utils.dart';
import 'package:nami/domain/member/mitglied.dart';
import 'package:nami/presentation/format/date_formatters.dart';
import 'package:nami/presentation/stufe/stufe_visuals.dart';
import 'package:nami/presentation/theme/theme.dart';

enum MemberSubtitleMode {
  mitgliedsnummer,
  geburtstag,
  spitzname,
  eintrittsdatum,
}

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
    this.subtitleText,
    this.subtitleHighlight,
    this.trailingText,
    this.onTap,
    this.toggleFavorites,
  });

  final Mitglied mitglied;
  final bool isFavourite;
  final MemberSubtitleMode subtitleMode;
  final String? subtitleText;
  final MemberSubtitleHighlight? subtitleHighlight;
  final String? trailingText;
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
    final primaryColor = stufe != null
        ? StufeVisuals.colorFor(stufe)
        : DPSGColors.keineStufeFarbe;
    final secondaryColor = MemberUtils.isLeitung(mitglied)
        ? DPSGColors.leiterFarbe
        : primaryColor;
    final subtitleWidget = subtitleHighlight != null
        ? _HighlightedSubtitle(highlight: subtitleHighlight!)
        : Text(resolvedSubtitle);

    final tile = Dismissible(
      key: Key(mitglied.mitgliedsnummer),
      direction: DismissDirection.endToStart,
      confirmDismiss: (direction) async {
        if (toggleFavorites != null) {
          toggleFavorites!();
        }
        return false; // Prevent actual dismissal
      },
      onDismissed: (_) {},
      background: Container(
        color: isFavourite ? Colors.red : Colors.amber,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Icon(
          isFavourite ? Icons.bookmark_remove : Icons.bookmark_add,
          color: Colors.white,
        ),
      ),
      child: Card(
        child: InkWell(
          onTap: onTap,
          child: ListTile(
            contentPadding: const EdgeInsets.only(left: 5, right: 5),
            leading: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  // TODO: Leading-Farbverlauf basiert noch auf Stufe/Taetigkeit; spaeter auf Gruppenkontext des Arbeitsmodells umstellen.
                  colors: [secondaryColor, primaryColor],
                  begin: const FractionalOffset(0.0, 0.0),
                  end: const FractionalOffset(0.0, 1.0),
                  stops: const [0.5, 0.5],
                  tileMode: TileMode.clamp,
                ),
              ),
              width: 5,
            ),
            title: Text('${mitglied.vorname} ${mitglied.nachname}'),
            subtitle: subtitleWidget,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (resolvedTrailingText != null &&
                    resolvedTrailingText.isNotEmpty)
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 140),
                      child: Text(
                        resolvedTrailingText,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ),
                if (isFavourite) ...[
                  const SizedBox(width: 5),
                  Container(
                    width: 5,
                    decoration: const BoxDecoration(color: Colors.amber),
                  ),
                ] else
                  const SizedBox(width: 10),
              ],
            ),
          ),
        ),
      ),
    );

    return Material(child: tile);
  }
}

class _HighlightedSubtitle extends StatelessWidget {
  const _HighlightedSubtitle({required this.highlight});

  final MemberSubtitleHighlight highlight;

  @override
  Widget build(BuildContext context) {
    final baseStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
      color: Theme.of(context).listTileTheme.textColor,
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
