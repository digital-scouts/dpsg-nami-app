import 'package:flutter/material.dart';

import '../../domain/member/mitglied.dart';
import '../widgets/member_basis.dart';

class MemberDetailPage extends StatelessWidget {
  const MemberDetailPage({super.key, required this.mitglied});

  final Mitglied mitglied;

  @override
  Widget build(BuildContext context) {
    final title = mitglied.fullName.trim().isEmpty
        ? mitglied.mitgliedsnummer
        : mitglied.fullName;

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: MemberDetails(mitglied: mitglied),
    );
  }
}
