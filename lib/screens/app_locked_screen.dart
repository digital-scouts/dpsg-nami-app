import 'package:flutter/material.dart';

class AppLockedScreen extends StatelessWidget {
  const AppLockedScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Image.asset(
            'assets/images/door.jpg',
            fit: BoxFit.cover,
          ),
          const Center(
            child: Text(
              'App is locked',
              style: TextStyle(
                fontSize: 24,
                color: Colors.white,
                shadows: <Shadow>[
                  Shadow(
                    offset: Offset(2.0, 2.0),
                    blurRadius: 3.0,
                    color: Color.fromARGB(255, 0, 0, 0),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
