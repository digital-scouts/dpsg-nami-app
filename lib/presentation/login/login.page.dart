import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nami/domain/repositories/auth_repository.dart';
import 'package:nami/presentation/app/app_cubit.dart';

import 'login.bloc.dart';
import 'login.widgets.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    final authRepo = context.read<AuthRepository>();

    return BlocProvider(
      create: (_) => LoginBloc(authRepo),
      child: const Scaffold(body: _LoginScreenBody()),
    );
  }
}

class _LoginScreenBody extends StatelessWidget {
  const _LoginScreenBody();

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Stack(
          children: <Widget>[
            Container(
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
            const SizedBox(
              height: double.infinity,
              child: SingleChildScrollView(
                physics: AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.symmetric(
                  horizontal: 40.0,
                  vertical: 120.0,
                ),
                child: _LoginForm(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoginForm extends StatefulWidget {
  const _LoginForm();

  @override
  State<_LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<_LoginForm> {
  final mitgliedsnummerCtrl = TextEditingController();
  final passwordCtrl = TextEditingController();
  bool rememberMe = false;

  @override
  void initState() {
    super.initState();

    // Lade gespeicherte LoginId und fülle das Feld vor
    final authRepo = context.read<AuthRepository>();
    final savedLoginId = authRepo.getSavedLoginId();
    if (savedLoginId != null) {
      mitgliedsnummerCtrl.text = savedLoginId.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<LoginBloc, LoginState>(
      listener: (context, state) {
        if (state is LoginSuccess) {
          context.read<AppCubit>().loginSuccess();
        }
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Image.asset('assets/images/dpsg_logo.png', cacheHeight: 444),
          const SizedBox(height: 30.0),
          AutofillGroup(
            child: Column(
              children: [
                MitgliedsnummerInput(controller: mitgliedsnummerCtrl),
                const SizedBox(height: 30.0),
                PasswordInput(controller: passwordCtrl),
              ],
            ),
          ),
          const ForgotPasswordButton(),
          RememberMeCheckbox(
            value: rememberMe,
            onChanged: (value) {
              setState(() {
                rememberMe = value;
              });
            },
          ),
          LoginButton(
            mitgliedsnummerCtrl: mitgliedsnummerCtrl,
            passwordCtrl: passwordCtrl,
            rememberMe: rememberMe,
          ),
          const ErrorDisplay(),
          const SignupButton(),
          const SizedBox(height: 30.0),
          const TestAppButton(),
          const LoadingSpinner(),
        ],
      ),
    );
  }

  @override
  void dispose() {
    mitgliedsnummerCtrl.dispose();
    passwordCtrl.dispose();
    super.dispose();
  }
}
