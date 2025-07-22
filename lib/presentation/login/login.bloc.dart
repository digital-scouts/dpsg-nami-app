import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nami/core/exceptions/app_exception.dart';
import 'package:nami/domain/repositories/auth_repository.dart';
import 'package:nami/utilities/hive/hive.handler.dart';
import 'package:nami/utilities/hive/settings.dart';
import 'package:nami/utilities/logger.dart';

// EVENTS
abstract class LoginEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class LoginSubmitted extends LoginEvent {
  final int mitgliedsnummer;
  final String password;
  final bool rememberMe;

  LoginSubmitted(this.mitgliedsnummer, this.password, this.rememberMe);

  @override
  List<Object?> get props => [mitgliedsnummer, password, rememberMe];
}

class TestLoginRequested extends LoginEvent {}

// STATES
abstract class LoginState extends Equatable {
  @override
  List<Object?> get props => [];
}

class LoginInitial extends LoginState {}

class LoginLoading extends LoginState {}

class LoginSuccess extends LoginState {
  final bool differentUser;
  final bool isRelogin;

  LoginSuccess({this.differentUser = false, this.isRelogin = false});

  @override
  List<Object?> get props => [differentUser, isRelogin];
}

class LoginFailure extends LoginState {
  final String error;
  final LoginErrorType errorType;

  LoginFailure(this.error, {this.errorType = LoginErrorType.general});

  @override
  List<Object?> get props => [error, errorType];
}

enum LoginErrorType { wrongCredentials, networkError, general }

// BLOC
class LoginBloc extends Bloc<LoginEvent, LoginState> {
  final AuthRepository authRepository;

  LoginBloc(this.authRepository) : super(LoginInitial()) {
    on<LoginSubmitted>(_onLoginSubmitted);
    on<TestLoginRequested>(_onTestLoginRequested);
  }

  Future<void> _onLoginSubmitted(
    LoginSubmitted event,
    Emitter<LoginState> emit,
  ) async {
    emit(LoginLoading());

    try {
      final differentUser =
          event.mitgliedsnummer !=
          getNamiLoginId(); // evtl. über userData laden
      if (differentUser) {
        logout(); // ggf. via Repo oder Service
      }

      await authRepository.login(
        event.mitgliedsnummer,
        event.password,
        rememberMe: event.rememberMe,
      );

      if (event.rememberMe) {
        setNamiPassword(event.password);
      } else {
        deleteNamiPassword();
      }

      emit(LoginSuccess(differentUser: differentUser));
    } on LoginFailedException catch (e) {
      emit(LoginFailure(e.message, errorType: LoginErrorType.wrongCredentials));
    } on NetworkException catch (e) {
      emit(LoginFailure(e.message, errorType: LoginErrorType.networkError));
    } catch (e) {
      sensLog.e('Login failed: $e');
      emit(LoginFailure('Unbekannter Fehler beim Login.'));
    }
  }

  Future<void> _onTestLoginRequested(
    TestLoginRequested event,
    Emitter<LoginState> emit,
  ) async {
    emit(LoginLoading());

    try {
      await authRepository.testLogin();
      emit(LoginSuccess());
    } on Exception catch (_) {
      emit(LoginFailure('Test-Login nicht verfügbar'));
    }
  }
}
