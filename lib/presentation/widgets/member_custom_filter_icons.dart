import 'package:flutter/material.dart';

class MemberCustomFilterIconOption {
  const MemberCustomFilterIconOption({
    required this.key,
    required this.icon,
    required this.labelKey,
  });

  final String key;
  final IconData icon;
  final String labelKey;
}

const List<MemberCustomFilterIconOption> memberCustomFilterIconOptions =
    <MemberCustomFilterIconOption>[
      MemberCustomFilterIconOption(
        key: 'groups',
        icon: Icons.groups,
        labelKey: 'member_filter_icon_groups',
      ),
      MemberCustomFilterIconOption(
        key: 'diversity_1',
        icon: Icons.diversity_1,
        labelKey: 'member_filter_icon_diversity_1',
      ),
      MemberCustomFilterIconOption(
        key: 'group',
        icon: Icons.group,
        labelKey: 'member_filter_icon_group',
      ),
      MemberCustomFilterIconOption(
        key: 'person',
        icon: Icons.person,
        labelKey: 'member_filter_icon_person',
      ),
      MemberCustomFilterIconOption(
        key: 'manage_accounts',
        icon: Icons.manage_accounts,
        labelKey: 'member_filter_icon_manage_accounts',
      ),
      MemberCustomFilterIconOption(
        key: 'star',
        icon: Icons.star,
        labelKey: 'member_filter_icon_star',
      ),
      MemberCustomFilterIconOption(
        key: 'handyman',
        icon: Icons.handyman,
        labelKey: 'member_filter_icon_handyman',
      ),
      MemberCustomFilterIconOption(
        key: 'sos',
        icon: Icons.sos,
        labelKey: 'member_filter_icon_sos',
      ),
      MemberCustomFilterIconOption(
        key: 'school',
        icon: Icons.school,
        labelKey: 'member_filter_icon_school',
      ),
      MemberCustomFilterIconOption(
        key: 'home',
        icon: Icons.home,
        labelKey: 'member_filter_icon_home',
      ),
    ];

IconData? memberCustomFilterIconForKey(String? key) {
  if (key == null) {
    return null;
  }
  for (final option in memberCustomFilterIconOptions) {
    if (option.key == key) {
      return option.icon;
    }
  }
  return null;
}
