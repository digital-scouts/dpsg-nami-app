import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:nami/utilities/hive/mitglied.dart';

Future<void> storeFakeSetOfMemberInHive(
    Box<Mitglied> box,
    ValueNotifier<bool?> memberOverviewProgressNotifier,
    ValueNotifier<double> memberAllProgressNotifier) async {
  await fakeLoading(memberOverviewProgressNotifier, memberAllProgressNotifier);

  List<Mitglied> members = [];
  for (var element in members) {
    box.put(element.id, element);
  }
}

Future<void> fakeLoading(ValueNotifier<bool?> memberOverviewProgressNotifier,
    ValueNotifier<double> memberAllProgressNotifier) async {
  await Future.delayed(const Duration(seconds: 1));
  memberOverviewProgressNotifier.value = true;
  Random random = Random();
  while (memberAllProgressNotifier.value < 1) {
    await Future.delayed(const Duration(milliseconds: 200));
    memberAllProgressNotifier.value += (0.02 + random.nextDouble() * 0.08);
    if (memberAllProgressNotifier.value > 1) {
      memberAllProgressNotifier.value = 1;
    }
  }
}
