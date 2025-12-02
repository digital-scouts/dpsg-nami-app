import 'package:flutter/material.dart';
import 'package:nami/domain/member/member_utils.dart';
import 'package:nami/domain/member/mitglied.dart';
import 'package:nami/domain/member/stufe.dart';
import 'package:nami/presentation/theme/theme.dart';
import 'package:nami/presentation/format/date_formatters.dart';

enum MemberSubtitleMode {
  mitgliedsnummer,
  geburtstag,
  spitzname,
  eintrittsdatum,
}

class MemberListTile extends StatelessWidget {
  const MemberListTile({
    super.key,
    required this.mitglied,
    required this.isFavourite,
    required this.subtitleMode,
    this.onTap,
    this.toggleFavorites,
  });

  final Mitglied mitglied;
  final bool isFavourite;
  final MemberSubtitleMode subtitleMode;
  final VoidCallback? onTap;
  final VoidCallback? toggleFavorites;

  @override
  Widget build(BuildContext context) {
    final stufe = MemberUtils.aktiveStufe(mitglied);
    final isLeitung = MemberUtils.isLeitung(mitglied);
    final primaryColor = stufe?.color ?? DPSGColors.keineStufeFarbe;
    final secondaryColor = isLeitung ? DPSGColors.leiterFarbe : primaryColor;

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
            subtitle: Text(() {
              switch (subtitleMode) {
                case MemberSubtitleMode.mitgliedsnummer:
                  return mitglied.mitgliedsnummer;
                case MemberSubtitleMode.geburtstag:
                  return DateFormatter.formatGermanLongDate(
                    mitglied.geburtsdatum,
                  );
                case MemberSubtitleMode.spitzname:
                  return mitglied.fahrtenname ?? '';
                case MemberSubtitleMode.eintrittsdatum:
                  return DateFormatter.formatGermanLongDate(
                    mitglied.eintrittsdatum,
                  );
              }
            }()),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Text(
                    isLeitung
                        ? Stufe.leitung.displayName
                        : stufe?.displayName ?? '',
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
