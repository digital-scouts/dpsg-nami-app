import 'package:flutter/material.dart';
import 'package:nami/domain/taetigkeit/role_derivation.dart';
import 'package:nami/domain/taetigkeit/roles.dart';

import 'member_roles_list_tile.dart';

class MemberRolesList extends StatelessWidget {
  const MemberRolesList({
    super.key,
    required this.roles,
    this.onDismissRequested,
    this.onRecommendationRequested,
    this.recommendation,
  });

  final List<Role> roles;
  final ValueChanged<Role>? onDismissRequested;
  final ValueChanged<Role>? onRecommendationRequested;
  final Role? recommendation;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final sorted = [...roles]..sort((a, b) => b.start.compareTo(a.start));
    final futureRoles = sorted.where((t) => t.start.isAfter(now)).toList();
    final activeRoles = sorted
        .where(
          (t) =>
              !t.start.isAfter(now) && (t.ende == null || t.ende!.isAfter(now)),
        )
        .toList();
    final pastRoles = sorted
        .where((t) => t.ende != null && !t.ende!.isAfter(now))
        .toList();

    return ListView(
      children: [
        if (futureRoles.isNotEmpty)
          _Section(
            title: 'Zukünftig',
            roles: futureRoles,
            recommendation: recommendation,
            onRecommendationRequested: onRecommendationRequested,
            onDismissRequested: onDismissRequested,
          ),
        if (activeRoles.isNotEmpty)
          _Section(
            title: 'Aktiv',
            roles: activeRoles,
            onDismissRequested: onDismissRequested,
          ),
        if (pastRoles.isNotEmpty)
          _Section(
            title: 'Abgeschlossen',
            roles: pastRoles,
            onDismissRequested: onDismissRequested,
          ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.roles,
    this.onDismissRequested,
    this.recommendation,
    this.onRecommendationRequested,
  });

  final String title;
  final List<Role> roles;
  final ValueChanged<Role>? onDismissRequested;
  final Role? recommendation;
  final ValueChanged<Role>? onRecommendationRequested;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            child: Text(title, style: Theme.of(context).textTheme.titleMedium),
          ),
          if (recommendation != null)
            MemberRolesRecommendationListTile(
              taetigkeit: recommendation!,
              onActionRequested: onRecommendationRequested,
            ),
          ...roles.map(
            (t) => MemberRolesListTile(
              taetigkeit: t,
              onDismissRequested: onDismissRequested,
            ),
          ),
        ],
      ),
    );
  }
}
