import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/qualifikation/plane_qualifikations_erinnerungen_usecase.dart';
import '../model/arbeitskontext_model.dart';
import '../model/auth_session_model.dart';
import '../model/qualifikations_einstellungen_model.dart';
import '../navigation/app_router.dart';
import '../screens/member_detail_page.dart';

/// Id der Hub-Meldung zu eigenen ablaufenden Qualifikationen.
const qualifikationsMeldungId = 'qualifikation-laeuft-ab';

/// Eigene Qualifikationen, die bald ablaufen oder abgelaufen sind, fuer die
/// Meldung im Hub. Ohne die noetigen Modelle (Tests, Stories) leer.
List<EigenerQualifikationsAblauf> eigeneQualifikationsAblaeufe(
  BuildContext context, {
  DateTime? heute,
}) {
  final readModel = context.watch<ArbeitskontextModel?>()?.readModel;
  final einstellungen = context
      .watch<QualifikationsEinstellungenModel?>()
      ?.einstellungen;
  final personId = context.watch<AuthSessionModel?>()?.profile?.namiId;
  if (readModel == null || einstellungen == null || personId == null) {
    return const <EigenerQualifikationsAblauf>[];
  }
  final jetzt = heute ?? DateTime.now();
  return const PlaneQualifikationsErinnerungenUseCase().eigeneAblaeufe(
    readModel: readModel,
    einstellungen: einstellungen,
    eigenePersonId: personId,
    heute: DateTime(jetzt.year, jetzt.month, jetzt.day),
  );
}

/// Oeffnet die eigenen Mitgliedsdetails, wenn die Person im Kontext ist.
Future<void> oeffneEigeneMitgliedsdetails(BuildContext context) async {
  final readModel = context.read<ArbeitskontextModel?>()?.readModel;
  final personId = context.read<AuthSessionModel?>()?.profile?.namiId;
  if (readModel == null || personId == null) {
    return;
  }
  for (final mitglied in readModel.mitglieder) {
    if (mitglied.personId == personId) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          settings: RouteSettings(
            name: AppRoutes.memberDetail,
            arguments: mitglied.mitgliedsnummer,
          ),
          builder: (_) => MemberDetailPage(mitglied: mitglied),
        ),
      );
      return;
    }
  }
}
