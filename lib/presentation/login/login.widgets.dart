import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:nami/presentation/login/login.bloc.dart';
import 'package:url_launcher/url_launcher.dart';

const kHintTextStyle = TextStyle(color: Colors.white54, fontFamily: 'OpenSans');

const kLabelStyle = TextStyle(
  color: Colors.white,
  fontWeight: FontWeight.bold,
  fontFamily: 'OpenSans',
);

class MitgliedsnummerInput extends StatelessWidget {
  final TextEditingController controller;

  const MitgliedsnummerInput({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LoginBloc, LoginState>(
      builder: (context, state) {
        final hasError =
            state is LoginFailure &&
            state.errorType == LoginErrorType.wrongCredentials;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text('Mitgliednummer', style: kLabelStyle),
            const SizedBox(height: 10.0),
            Container(
              alignment: Alignment.centerLeft,
              decoration: BoxDecoration(
                color: const Color(0xFF6CA8F1),
                borderRadius: BorderRadius.circular(10.0),
                border: hasError
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
                controller: controller,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  FilteringTextInputFormatter.allow(RegExp(r"[0-9.]")),
                  TextInputFormatter.withFunction((oldValue, newValue) {
                    try {
                      final text = newValue.text;
                      if (text.isNotEmpty) double.parse(text);
                      return newValue;
                    } catch (e) {
                      // ignore catch
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
                  prefixIcon: Icon(Icons.account_box, color: Colors.white),
                  hintText: 'Mitgliednummer eingeben',
                  hintStyle: kHintTextStyle,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class PasswordInput extends StatefulWidget {
  final TextEditingController controller;

  const PasswordInput({super.key, required this.controller});

  @override
  State<PasswordInput> createState() => _PasswordInputState();
}

class _PasswordInputState extends State<PasswordInput> {
  bool _isPasswordVisible = false;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LoginBloc, LoginState>(
      builder: (context, state) {
        final hasError =
            state is LoginFailure &&
            state.errorType == LoginErrorType.wrongCredentials;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text('Password', style: kLabelStyle),
            const SizedBox(height: 10.0),
            Container(
              alignment: Alignment.centerLeft,
              decoration: BoxDecoration(
                color: const Color(0xFF6CA8F1),
                borderRadius: BorderRadius.circular(10.0),
                border: hasError
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
                controller: widget.controller,
                onSubmitted: (_) => _submitLogin(),
                obscureText: !_isPasswordVisible,
                autofillHints: const [AutofillHints.password],
                style: const TextStyle(
                  color: Colors.white,
                  fontFamily: 'OpenSans',
                ),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.only(top: 14.0),
                  prefixIcon: const Icon(Icons.lock, color: Colors.white),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _isPasswordVisible
                          ? Icons.visibility
                          : Icons.visibility_off,
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
      },
    );
  }

  void _submitLogin() {
    // This would need access to mitgliedsnummer and remember me state
    // Will be handled by the parent form
  }
}

class ForgotPasswordButton extends StatelessWidget {
  const ForgotPasswordButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.centerRight,
      child: TextButton(
        onPressed: () => launchUrl(
          Uri.parse('https://nami.dpsg.de/ica/pages/access/forgotPassword.jsp'),
        ),
        child: const Text('Passwort vergessen?', style: kLabelStyle),
      ),
    );
  }
}

class RememberMeCheckbox extends StatefulWidget {
  final ValueChanged<bool> onChanged;
  final bool value;

  const RememberMeCheckbox({
    super.key,
    required this.onChanged,
    required this.value,
  });

  @override
  State<RememberMeCheckbox> createState() => _RememberMeCheckboxState();
}

class _RememberMeCheckboxState extends State<RememberMeCheckbox> {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 20.0,
      child: Row(
        children: <Widget>[
          Theme(
            data: ThemeData(unselectedWidgetColor: Colors.white),
            child: Checkbox(
              value: widget.value,
              checkColor: Colors.green,
              activeColor: Colors.white,
              onChanged: (value) {
                widget.onChanged(value ?? false);
              },
            ),
          ),
          const Text("Daten speichern", style: kLabelStyle),
        ],
      ),
    );
  }
}

class LoginButton extends StatelessWidget {
  final TextEditingController mitgliedsnummerCtrl;
  final TextEditingController passwordCtrl;
  final bool rememberMe;

  const LoginButton({
    super.key,
    required this.mitgliedsnummerCtrl,
    required this.passwordCtrl,
    required this.rememberMe,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LoginBloc, LoginState>(
      builder: (context, state) {
        final isLoading = state is LoginLoading;
        final hasError = state is LoginFailure;

        return Container(
          padding: const EdgeInsets.symmetric(vertical: 25.0),
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: hasError ? Colors.red : Colors.white,
            ),
            onPressed: isLoading ? null : () => _submitLogin(context),
            child: Text(
              'ANMELDEN',
              style: TextStyle(
                color: hasError ? Colors.white : const Color(0xFF527DAA),
                letterSpacing: 1.5,
                fontSize: 18.0,
                fontWeight: FontWeight.bold,
                fontFamily: 'OpenSans',
              ),
            ),
          ),
        );
      },
    );
  }

  void _submitLogin(BuildContext context) {
    final mitgliedsnummer = int.tryParse(mitgliedsnummerCtrl.text);
    if (mitgliedsnummer == null) return;

    context.read<LoginBloc>().add(
      LoginSubmitted(mitgliedsnummer, passwordCtrl.text, rememberMe),
    );
  }
}

class ErrorDisplay extends StatelessWidget {
  const ErrorDisplay({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LoginBloc, LoginState>(
      builder: (context, state) {
        if (state is LoginFailure) {
          return Container(
            alignment: Alignment.center,
            child: Text(
              state.error,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.normal,
                fontFamily: 'OpenSans',
              ),
            ),
          );
        }
        return Container();
      },
    );
  }
}

class LoadingSpinner extends StatelessWidget {
  const LoadingSpinner({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LoginBloc, LoginState>(
      builder: (context, state) {
        if (state is LoginLoading) {
          return Container(
            alignment: Alignment.center,
            child: const SpinKitRotatingCircle(color: Colors.white, size: 50.0),
          );
        }
        return Container();
      },
    );
  }
}

class SignupButton extends StatelessWidget {
  const SignupButton({super.key});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        launchUrl(Uri.parse('https://nami.dpsg.de/ica/pages/requestLogin.jsp'));
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
}

class TestAppButton extends StatelessWidget {
  const TestAppButton({super.key});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        context.read<LoginBloc>().add(TestLoginRequested());
      },
      child: RichText(
        text: const TextSpan(
          children: [
            TextSpan(
              text: 'Reinschnuppern',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 18.0,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
