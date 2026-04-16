import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:nami/domain/taetigkeit/role_derivation.dart';
import 'package:nami/domain/taetigkeit/roles.dart';
import 'package:nami/domain/taetigkeit/stufe.dart';
import 'package:nami/l10n/app_localizations.dart';
import 'package:nami/presentation/stufe/stufe_visuals.dart';

class MemberRolesListTile extends StatelessWidget {
  const MemberRolesListTile({
    super.key,
    required this.taetigkeit,
    this.onDismissRequested,
  });

  final Role taetigkeit;
  final ValueChanged<Role>? onDismissRequested;

  @override
  Widget build(BuildContext context) {
    final title =
        '${taetigkeit.art.displayName} - ${taetigkeit.stufe.displayName}';

    final monthFmt = DateFormat(
      'MMMM yyyy',
      Localizations.localeOf(context).toLanguageTag(),
    );
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

  final Role taetigkeit;
  final ValueChanged<Role>? onActionRequested;

  @override
  Widget build(BuildContext context) {
    final title = taetigkeit.stufe.displayName;
    final monthFmt = DateFormat(
      'MMMM yyyy',
      Localizations.localeOf(context).toLanguageTag(),
    );
    final subtitle = AppLocalizations.of(context).t(
      'member_roles_stage_change_at',
      {'date': monthFmt.format(taetigkeit.start)},
    );

    final tile = Card(
      child: ListTile(
        contentPadding: const EdgeInsets.only(left: 5, right: 5),
        leading: _buildLeadingFor(context, taetigkeit),
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: TextButton(
          onPressed: () => onActionRequested?.call(taetigkeit),
          child: Text(AppLocalizations.of(context).t('member_roles_switch')),
        ),
      ),
    );

    return Material(child: tile);
  }
}

Widget _buildLeadingFor(BuildContext context, Role taetigkeit) {
  if (taetigkeit.art == RoleCategory.leitung &&
      taetigkeit.stufe != Stufe.leitung) {
    return Image.asset(
      StufeVisuals.assetFor(Stufe.leitung),
      width: 80.0,
      height: 80.0,
      color: StufeVisuals.colorFor(taetigkeit.stufe),
      colorBlendMode: BlendMode.srcIn,
      cacheWidth: 150,
    );
  }
  final asset = StufeVisuals.assetFor(taetigkeit.stufe);
  if (asset.isNotEmpty) {
    return Image.asset(asset, width: 80.0, height: 80.0, cacheHeight: 150);
  }
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return Image.asset(
    StufeVisuals.assetFor(Stufe.leitung),
    width: 80.0,
    height: 80.0,
    color: isDark ? Colors.white70 : Colors.black,
    colorBlendMode: BlendMode.srcIn,
    cacheWidth: 150,
  );
}
