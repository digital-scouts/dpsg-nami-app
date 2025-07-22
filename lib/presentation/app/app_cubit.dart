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
  void logout() => emit(AppStatus.unauthenticated);
}
