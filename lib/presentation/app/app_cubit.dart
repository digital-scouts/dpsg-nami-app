import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nami/domain/repositories/auth_repository.dart';

enum AppStatus { loading, authenticated, unauthenticated }

class AppCubit extends Cubit<AppStatus> {
  final AuthRepository authRepository;

  AppCubit(this.authRepository) : super(AppStatus.loading) {
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    final loggedIn = await authRepository.isLoggedIn();
    emit(loggedIn ? AppStatus.authenticated : AppStatus.unauthenticated);
  }

  void loginSuccess() => emit(AppStatus.authenticated);

  Future<void> logout() async {
    try {
      // Führe den tatsächlichen Logout durch
      await authRepository.logout();
      // Setze den State auf unauthenticated
      emit(AppStatus.unauthenticated);
    } catch (e) {
      // Falls Logout fehlschlägt, logge den Fehler aber setze trotzdem unauthenticated
      // da wir den User sowieso ausloggen wollen
      emit(AppStatus.unauthenticated);
      rethrow; // Werfe den Fehler weiter für potentielle UI-Behandlung
    }
  }

  Future<void> refresh() async {
    emit(AppStatus.loading);
    await _checkAuth();
  }
}
