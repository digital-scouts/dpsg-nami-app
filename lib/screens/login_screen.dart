import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:nami/utilities/app.state.dart';
import 'package:nami/utilities/hive/hive.handler.dart';
import 'package:nami/utilities/hive/settings.dart';
import 'package:nami/utilities/logger.dart';
import 'package:nami/utilities/nami/nami_login.service.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

const kHintTextStyle = TextStyle(
  color: Colors.white54,
  fontFamily: 'OpenSans',
);

const kLabelStyle = TextStyle(
  color: Colors.white,
  fontWeight: FontWeight.bold,
  fontFamily: 'OpenSans',
);

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  LoginScreenState createState() => LoginScreenState();
}

class LoginScreenState extends State<LoginScreen> {
  bool _rememberMe = false;
  int _mitgliedsnummer = 0;
  String _password = '';
  bool _isPasswordVisible = false;
  bool _wrongCredentials = false;
  bool _loading = false;

  void wrongCredentials() {
    setState(() {
      _wrongCredentials = true;
    });
  }

  Future<void> loginButtonPressed() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _wrongCredentials = false;
    });
    final appStateHandler = context.read<AppStateHandler>();
    final differentUser = _mitgliedsnummer != getNamiLoginId();
    if (differentUser) {
      logout();
    }
    if (await namiLoginWithPassword(_mitgliedsnummer, _password)) {
      setState(() {
        _loading = false;
      });
      setNamiLoginId(_mitgliedsnummer);
      if (_rememberMe) {
        setNamiPassword(_password);
      } else {
        deleteNamiPassword();
      }
      appStateHandler.lastAuthenticated = DateTime.now();
      if (differentUser || appStateHandler.currentState == AppState.loggedOut) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          appStateHandler.setLoadDataState(loadAll: true);
        });
      } else if (appStateHandler.currentState == AppState.relogin) {
        /// setting to result to `true` to signal that the relogin was successful
        // ignore: use_build_context_synchronously
        Navigator.pop(context, true);
      }
    } else {
      wrongCredentials();
      setState(() {
        _loading = false;
      });
    }
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
          decoration: BoxDecoration(
            color: const Color(0xFF6CA8F1),
            borderRadius: BorderRadius.circular(10.0),
            border: _wrongCredentials
                ? Border.all(color: Colors.red, width: 2.0)
                : null,
            boxShadow: const [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 6.0,
                offset: Offset(0, 2),
              ),
            ],
          ),
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
            textInputAction: TextInputAction.next,
            keyboardType: TextInputType.number,
            autofillHints: const [AutofillHints.username],
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
          decoration: BoxDecoration(
            color: const Color(0xFF6CA8F1),
            borderRadius: BorderRadius.circular(10.0),
            border: _wrongCredentials
                ? Border.all(color: Colors.red, width: 2.0)
                : null,
            boxShadow: const [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 6.0,
                offset: Offset(0, 2),
              ),
            ],
          ),
          height: 60.0,
          child: TextField(
            onChanged: (text) {
              _password = text;
            },
            onSubmitted: (_) => loginButtonPressed(),
            obscureText: !_isPasswordVisible,
            autofillHints: const [AutofillHints.password],
            style: const TextStyle(
              color: Colors.white,
              fontFamily: 'OpenSans',
            ),
            decoration: InputDecoration(
              border: InputBorder.none,
              contentPadding: const EdgeInsets.only(top: 14.0),
              prefixIcon: const Icon(
                Icons.lock,
                color: Colors.white,
              ),
              suffixIcon: IconButton(
                icon: Icon(
                  _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                  color: Colors.white,
                ),
                onPressed: () {
                  setState(() {
                    _isPasswordVisible = !_isPasswordVisible;
                  });
                },
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
        onPressed: () => launchUrl(Uri.parse(
            ('https://nami.dpsg.de/ica/pages/access/forgotPassword.jsp'))),
        child: const Text(
          'Passwort vergessen?',
          style: kLabelStyle,
        ),
      ),
    );
  }

  Widget _buildRememberMeCheckbox() {
    return SizedBox(
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
                  sensLog.t('rememberMe: $value');
                  _rememberMe = value! | false;
                });
              },
            ),
          ),
          const Text(
            "Daten speichern",
            style: kLabelStyle,
          ),
        ],
      ),
    );
  }

  Widget _wrongIdOrPassword() {
    if (_wrongCredentials) {
      return Container(
        alignment: Alignment.center,
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
          backgroundColor: _wrongCredentials ? Colors.red : Colors.white,
        ),
        onPressed: loginButtonPressed,
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

  void popNavigation() {
    Navigator.pop(context);
  }

  Widget _buildSignupBtn() {
    return InkWell(
      onTap: () {
        launchUrl(
            Uri.parse(('https://nami.dpsg.de/ica/pages/requestLogin.jsp')));
      },
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
              SizedBox(
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
                      Image.asset(
                        'assets/images/dpsg_logo.png',
                        cacheHeight: 444,
                      ),
                      const SizedBox(height: 30.0),
                      AutofillGroup(
                        child: Column(
                          children: [
                            _buildMitgliednummerTF(),
                            const SizedBox(height: 30.0),
                            _buildPasswordTF(),
                          ],
                        ),
                      ),
                      _buildForgotPasswordBtn(),
                      _buildRememberMeCheckbox(),
                      _buildLoginBtn(),
                      _wrongIdOrPassword(),
                      _buildSignupBtn(),
                      _loadingSpinner(),
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
