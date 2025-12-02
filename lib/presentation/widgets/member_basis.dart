import 'package:flutter/material.dart';
import 'package:nami/domain/member/mitglied.dart';
import 'member_basis_info_card.dart';

/// Kombiniertes Detail-Widget für ein Mitglied.
/// Enthält allgemeine Infos + Mitgliedschafts-Infos untereinander.
class MemberDetails extends StatelessWidget {
  const MemberDetails({
    super.key,
    required this.mitglied,
    this.onEndMembership,
    this.spacing = 16,
    this.showGeneralInfo = true,
    this.showMembershipInfo = true,
  });

  final Mitglied mitglied;
  final VoidCallback? onEndMembership;
  final double spacing;
  final bool showGeneralInfo;
  final bool showMembershipInfo;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    if (showGeneralInfo) {
      children.add(MemberGeneralInfoCard(mitglied: mitglied));
    }
    if (showGeneralInfo && showMembershipInfo) {
      children.add(SizedBox(height: spacing));
    }
    if (showMembershipInfo) {
      children.add(
        MemberMembershipInfoCard(
          mitglied: mitglied,
          onEndMembership: onEndMembership,
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(10.0),
      children: <Widget>[...children],
    );
  }
}
