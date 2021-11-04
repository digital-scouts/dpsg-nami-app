import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nami/hive/settings.dart';
import 'package:nami/utilities/app_theme.dart';

import 'login.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);
  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late String? token;
  late int? userId;

  @override
  void initState() {
    super.initState();
    token = getNamiApiCookie();
    userId = getNamiLoginId();
  }

  Widget _buildWidgetElement(IconData icon, String text, String subtext) {
    return SizedBox(
      width: 160.0,
      height: 110.0,
      child: Card(
        color: const Color.fromARGB(255, 21, 21, 21),
        elevation: 2.0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
        child: Center(
            child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            children: <Widget>[
              Icon(
                icon,
                color: Colors.white,
              ),
              const SizedBox(
                height: 10.0,
              ),
              Text(
                text,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 17.0),
              ),
              const SizedBox(
                height: 5.0,
              ),
              Text(
                subtext,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w100),
              )
            ],
          ),
        )),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
        color: AppTheme.nearlyWhite,
        child: SafeArea(
            child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Padding(
              padding: EdgeInsets.all(18.0),
              child: Text(
                "Welcome, Doctor code \nSelect an option",
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 28.0,
                    fontWeight: FontWeight.bold),
                textAlign: TextAlign.start,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Center(
                child: Wrap(
                  spacing: 20,
                  runSpacing: 20.0,
                  children: <Widget>[
                    _buildWidgetElement(
                        Icons.account_box, 'Wölflinge', '5 Kinder'),
                    _buildWidgetElement(
                        Icons.account_box, 'Jungpfadfinder', '5 Kinder'),
                    _buildWidgetElement(
                        Icons.account_box, 'Pfadfinder', '5 Kinder'),
                    _buildWidgetElement(Icons.account_box, 'Rover', '5 Kinder'),
                    _buildWidgetElement(
                        Icons.account_box, 'Sonstige', '5 Kinder'),
                  ],
                ),
              ),
            )
          ],
        )));
  }
}
