import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../model/arbeitskontext_model.dart';

class StatisticsPage extends StatelessWidget {
  const StatisticsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final arbeitskontextModel = context.watch<ArbeitskontextModel>();
    final anzahl = arbeitskontextModel.readModel?.mitglieder.length ?? 0;

    return Center(
      child: Text(
        'Anzahl: $anzahl',
        style: Theme.of(context).textTheme.headlineSmall,
      ),
    );
  }
}
