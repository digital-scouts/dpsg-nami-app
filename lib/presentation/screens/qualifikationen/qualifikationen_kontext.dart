import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../../domain/appearance/appearance_catalog.dart';
import '../../../domain/arbeitskontext/arbeitskontext_read_model.dart';
import '../../../domain/member/member_utils.dart';
import '../../model/appearance_model.dart';
import '../../model/arbeitskontext_model.dart';
import '../../model/auth_session_model.dart';

/// Gemeinsame Lesehilfen der Qualifikationen-Seiten. Stories und Tests
/// koennen das Read Model direkt uebergeben.
class QualifikationenKontext {
  const QualifikationenKontext._();

  static ArbeitskontextReadModel? readModel(
    BuildContext context,
    ArbeitskontextReadModel? vorgegeben,
  ) => vorgegeben ?? _maybeWatch<ArbeitskontextModel>(context)?.readModel;

  /// Ohne AppearanceModel (Stories, Tests) ist alles frei.
  static bool supporterFrei(BuildContext context) =>
      _maybeWatch<AppearanceModel>(
        context,
      )?.access.isTierUnlocked(SupportTier.supporter) ??
      true;

  static int? eigenePersonId(BuildContext context) =>
      _maybeWatch<AuthSessionModel>(context)?.profile?.namiId;

  /// Personen mit mindestens einer heute aktiven Rolle ausser
  /// `Group::Mitglieder::*`.
  static int personenMitRolle(
    ArbeitskontextReadModel readModel,
    DateTime heute,
  ) => readModel.mitglieder
      .where(
        (mitglied) => mitglied.roles.any(
          (rolle) =>
              rolle.isActiveAt(heute) && !MemberUtils.istMitgliederRolle(rolle),
        ),
      )
      .length;

  static DateTime heute(DateTime Function()? heuteProvider) {
    final jetzt = heuteProvider?.call() ?? DateTime.now();
    return DateTime(jetzt.year, jetzt.month, jetzt.day);
  }

  static T? _maybeWatch<T>(BuildContext context) {
    try {
      return context.watch<T>();
    } on ProviderNotFoundException {
      return null;
    }
  }
}
