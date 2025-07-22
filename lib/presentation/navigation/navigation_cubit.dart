import 'package:flutter_bloc/flutter_bloc.dart';

enum NavigationTab { meineStufe, mitglieder, stats, settings, profil }

class NavigationCubit extends Cubit<NavigationTab> {
  NavigationCubit() : super(NavigationTab.mitglieder);

  void switchTo(NavigationTab tab) => emit(tab);
}
