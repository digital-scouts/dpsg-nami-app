import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:nami/domain/member/stufe.dart';
import 'package:nami/domain/member/taetigkeit.dart';

class MemberRolesListTile extends StatelessWidget {
  const MemberRolesListTile({
    super.key,
    required this.taetigkeit,
    this.onDismissRequested,
  });

  final Taetigkeit taetigkeit;
  final ValueChanged<Taetigkeit>? onDismissRequested;

  @override
  Widget build(BuildContext context) {
    final title =
        '${taetigkeit.art.displayName} - ${taetigkeit.stufe.displayName}';

    final monthFmt = DateFormat('MMMM yyyy', 'de');
    final startStr = monthFmt.format(taetigkeit.start);
    final endStr = taetigkeit.ende != null
        ? monthFmt.format(taetigkeit.ende!)
        : null;
    final periode = endStr != null ? '$startStr - $endStr' : startStr;

    final showPermissionLine =
        taetigkeit.istAktiv &&
        (taetigkeit.permission != null && taetigkeit.permission!.isNotEmpty);
    final endsInFuture =
        taetigkeit.ende != null && taetigkeit.ende!.isAfter(DateTime.now());

    final tile = Dismissible(
      key: ValueKey(
        'role-${taetigkeit.stufe.name}-${taetigkeit.start.millisecondsSinceEpoch}',
      ),
      direction: DismissDirection.endToStart,
      confirmDismiss: (direction) async {
        onDismissRequested?.call(taetigkeit);
        return false;
      },
      background: Container(
        color: endsInFuture ? Colors.orange : Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Icon(
          endsInFuture ? Icons.event_busy : Icons.delete,
          color: Colors.white,
        ),
      ),
      child: Card(
        child: ListTile(
          contentPadding: const EdgeInsets.only(left: 5, right: 5),
          leading: _buildLeadingFor(context, taetigkeit),
          title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(periode, maxLines: 1, overflow: TextOverflow.ellipsis),
              if (showPermissionLine)
                Text(
                  taetigkeit.permission ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
      ),
    );

    return Material(child: tile);
  }
}

class MemberRolesRecommendationListTile extends StatelessWidget {
  const MemberRolesRecommendationListTile({
    super.key,
    required this.taetigkeit,
    this.onActionRequested,
  });

  final Taetigkeit taetigkeit;
  final ValueChanged<Taetigkeit>? onActionRequested;

  @override
  Widget build(BuildContext context) {
    final title = taetigkeit.stufe.displayName;
    final monthFmt = DateFormat('MMMM yyyy', 'de');
    final subtitle = 'Stufenwechsel am ${monthFmt.format(taetigkeit.start)}';

    final tile = Card(
      child: ListTile(
        contentPadding: const EdgeInsets.only(left: 5, right: 5),
        leading: _buildLeadingFor(context, taetigkeit),
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: TextButton(
          onPressed: () => onActionRequested?.call(taetigkeit),
          child: const Text('Wechseln'),
        ),
      ),
    );

    return Material(child: tile);
  }
}

Widget _buildLeadingFor(BuildContext context, Taetigkeit taetigkeit) {
  if (taetigkeit.art == TaetigkeitsArt.leitung &&
      taetigkeit.stufe != Stufe.leitung) {
    return Image.asset(
      Stufe.leitung.imagePath,
      width: 80.0,
      height: 80.0,
      color: taetigkeit.stufe.color,
      colorBlendMode: BlendMode.srcIn,
      cacheWidth: 150,
    );
  }
  if (taetigkeit.stufe.imagePath.isNotEmpty) {
    return Image.asset(
      taetigkeit.stufe.imagePath,
      width: 80.0,
      height: 80.0,
      cacheHeight: 150,
    );
  }
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return Image.asset(
    Stufe.leitung.imagePath,
    width: 80.0,
    height: 80.0,
    color: isDark ? Colors.white70 : Colors.black,
    colorBlendMode: BlendMode.srcIn,
    cacheWidth: 150,
  );
}
