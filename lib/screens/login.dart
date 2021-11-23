import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nami/hive/settings.dart';
import 'package:nami/utilities/constants.dart';
import 'package:nami/utilities/nami.service.dart';
import 'dart:async';
import 'package:flutter_spinkit/flutter_spinkit.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _rememberMe = false;
  int _mitgliedsnummer = 0;
  String _password = '';
  bool _wrongCredentials = false;
  bool _loading = false;

  void wrongCredentials() {
    setState(() {
      _wrongCredentials = true;
    });
    Timer(
        const Duration(seconds: 3),
        () => setState(() {
              _wrongCredentials = false;
            }));
  }

  Widget _buildMitgliednummerTF() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text(
          'Mitgliednummer',
          style: kLabelStyle,
        ),
        const SizedBox(height: 10.0),
        Container(
          alignment: Alignment.centerLeft,
          decoration: kBoxDecorationStyle,
          height: 60.0,
          child: TextField(
            onChanged: (number) {
              if (number.isNotEmpty) _mitgliedsnummer = int.parse(number);
            },
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              FilteringTextInputFormatter.allow(RegExp(r"[0-9.]")),
              TextInputFormatter.withFunction((oldValue, newValue) {
                try {
                  final text = newValue.text;
                  if (text.isNotEmpty) double.parse(text);
                  return newValue;
                } catch (e) {
                  //ignore catch
                }
                return oldValue;
              }),
            ],
            keyboardType: TextInputType.number,
            style: const TextStyle(
              color: Colors.white,
              fontFamily: 'OpenSans',
            ),
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.only(top: 14.0),
              prefixIcon: Icon(
                Icons.account_box,
                color: Colors.white,
              ),
              hintText: 'Mitgliednummer eingeben',
              hintStyle: kHintTextStyle,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordTF() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text(
          'Password',
          style: kLabelStyle,
        ),
        const SizedBox(height: 10.0),
        Container(
          alignment: Alignment.centerLeft,
          decoration: kBoxDecorationStyle,
          height: 60.0,
          child: TextField(
            onChanged: (text) {
              _password = text;
            },
            obscureText: true,
            style: const TextStyle(
              color: Colors.white,
              fontFamily: 'OpenSans',
            ),
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.only(top: 14.0),
              prefixIcon: Icon(
                Icons.lock,
                color: Colors.white,
              ),
              hintText: 'Passwort eingeben',
              hintStyle: kHintTextStyle,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildForgotPasswordBtn() {
    return Container(
      alignment: Alignment.centerRight,
      child: TextButton(
        onPressed: () => print('Forgot Password Button Pressed'),
        child: const Text(
          'Passwort vergessen?',
          style: kLabelStyle,
        ),
      ),
    );
  }

  Widget _buildRememberMeCheckbox() {
    return Container(
      height: 20.0,
      child: Row(
        children: <Widget>[
          Theme(
            data: ThemeData(unselectedWidgetColor: Colors.white),
            child: Checkbox(
              value: _rememberMe,
              checkColor: Colors.green,
              activeColor: Colors.white,
              onChanged: (value) {
                setState(() {
                  print('rememberMe: $value');
                  _rememberMe = value! | false;
                });
              },
            ),
          ),
          Text(
            'Daten speichern',
            style: kLabelStyle,
          ),
        ],
      ),
    );
  }

  Widget _wrongIdOrPassword() {
    if (_wrongCredentials) {
      return Container(
        alignment: Alignment.centerRight,
        child: const Text(
          'Mitgliedsnummer oder Passwort falsch',
          style: TextStyle(
            color: Colors.red,
            fontWeight: FontWeight.normal,
            fontFamily: 'OpenSans',
          ),
        ),
      );
    } else {
      return Container();
    }
  }

  Widget _loadingSpinner() {
    if (_loading) {
      return Container(
        alignment: Alignment.center,
        child: const SpinKitRotatingCircle(color: Colors.white, size: 50.0),
      );
    } else {
      return Container();
    }
  }

  Widget _buildLoginBtn() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 25.0),
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          primary: _wrongCredentials ? Colors.red : Colors.white,
        ),
        onPressed: () async => {
          setState(() {
            _loading = true;
          }),
          if (await namiLoginWithPassword(_mitgliedsnummer, _password))
            {
              setState(() {
                _loading = false;
              }),
              Navigator.pop(context, true),
              if (_rememberMe) {setNamiPassword(_password)},
              setNamiLoginId(_mitgliedsnummer),
            }
          else
            {
              wrongCredentials(),
              setState(() {
                _loading = false;
              }),
            }
        },
        child: Text(
          'ANMELDEN',
          style: TextStyle(
            color: _wrongCredentials ? Colors.white : const Color(0xFF527DAA),
            letterSpacing: 1.5,
            fontSize: 18.0,
            fontWeight: FontWeight.bold,
            fontFamily: 'OpenSans',
          ),
        ),
      ),
    );
  }

  Widget _buildSignupBtn() {
    return GestureDetector(
      onTap: () => print('Sign Up Button Pressed'),
      child: RichText(
        text: const TextSpan(
          children: [
            TextSpan(
              text: 'Zugang beantragen',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18.0,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: Stack(
            children: <Widget>[
              Container(
                // background gradient
                height: double.infinity,
                width: double.infinity,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFF73AEF5),
                      Color(0xFF61A4F1),
                      Color(0xFF478DE0),
                      Color(0xFF398AE5),
                    ],
                    stops: [0.1, 0.4, 0.7, 0.9],
                  ),
                ),
              ),
              Container(
                height: double.infinity,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 40.0,
                    vertical: 120.0,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Image.asset('assets/images/dpsg_logo.png'),
                      const SizedBox(height: 30.0),
                      Text('V1'),
                      _buildMitgliednummerTF(),
                      const SizedBox(
                        height: 30.0,
                      ),
                      _buildPasswordTF(),
                      _buildForgotPasswordBtn(),
                      _buildRememberMeCheckbox(),
                      _buildLoginBtn(),
                      _wrongIdOrPassword(),
                      _buildSignupBtn(),
                      _loadingSpinner()
                    ],
                  ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
