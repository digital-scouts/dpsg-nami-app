import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:nami/screens/widgets/groupBarChart.widget.dart';
import 'package:nami/screens/widgets/stufenwechselInfo.widget.dart';
import 'package:nami/utilities/hive/mitglied.dart';

class StatistikScreen extends StatefulWidget {
  const StatistikScreen({Key? key}) : super(key: key);

  @override
  StatistikScreenState createState() => StatistikScreenState();
}

class StatistikScreenState extends State<StatistikScreen> {
  Box<Mitglied> memberBox = Hive.box<Mitglied>('members');
  List<Mitglied> mitglieder =
      Hive.box<Mitglied>('members').values.toList().cast<Mitglied>();

  @override
  void initState() {
    super.initState();
    memberBox.listenable().addListener(() {
      mitglieder = memberBox.values.toList().cast<Mitglied>();
    });
  }

  Widget _buildMemberCountStatistik() {
    Map<String, GroupData> memberPerGroup =
        mitglieder.fold<Map<String, GroupData>>({}, (map, member) {
      String stufe = member.stufe;
      String taetigkeit = member.isMitgliedLeiter() ? 'leiter' : 'mitglied';

      if (stufe == 'keine Stufe') {
        taetigkeit = stufe;
      }

      if (!map.containsKey(stufe)) {
        map["Wölfling"] = GroupData(0, 0);
        map["Jungpfadfinder"] = GroupData(0, 0);
        map["Pfadfinder"] = GroupData(0, 0);
        map["Rover"] = GroupData(0, 0);
        map["keine Stufe"] = GroupData(0, 0);
      }

      if (taetigkeit == 'leiter') {
        map[stufe]!.leiter += 1;
      } else {
        map[stufe]!.mitglied += 1;
      }

      return map;
    });
    // memberPerGroup.remove('keine Stufe');

    return GroupBarChart(memberPerGroup: memberPerGroup);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Statistiken'),
      ),
      body: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final double containerWidth = constraints.maxWidth * 0.45;
          final double containerHeight = constraints.maxHeight * 0.25;
          const double spacing = 10.0;

          return Column(
            children: [
              const SizedBox(height: spacing),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  SizedBox(
                    width: constraints.maxWidth * 0.05,
                    height: containerHeight,
                  ),
                  SizedBox(
                    width: constraints.maxWidth * 0.35,
                    height: containerHeight,
                    child: _buildMemberCountStatistik(),
                  ),
                  SizedBox(
                    width: constraints.maxWidth * 0.05,
                    height: containerHeight,
                  ),
                  Container(
                    width: constraints.maxWidth * 0.40,
                    height: containerHeight,
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      borderRadius: BorderRadius.circular(5.0),
                    ),
                    child: const Center(
                      child: Text(
                        'Stufenwechsel',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 20.0,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: spacing),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  SizedBox(
                      width: containerWidth * 2 + spacing * 2,
                      height: containerHeight * 1.5,
                      child: const StufenwechselInfo()),
                ],
              ),
              const SizedBox(height: spacing),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Container(
                    width: containerWidth * 2 + spacing * 2,
                    height: containerHeight,
                    decoration: BoxDecoration(
                      color: Colors.yellow,
                      borderRadius: BorderRadius.circular(10.0),
                    ),
                    child: const Center(
                      child: Text(
                        'Demografie',
                        style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                          fontSize: 20.0,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
