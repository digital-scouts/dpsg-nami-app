import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nami/services/member_service.dart';
import 'package:nami/utilities/hive/mitglied.dart';

// Events
abstract class MitgliederEvent extends Equatable {
  const MitgliederEvent();

  @override
  List<Object?> get props => [];
}

class LoadMitglieder extends MitgliederEvent {}

class UpdateSearchString extends MitgliederEvent {
  final String searchString;

  const UpdateSearchString(this.searchString);

  @override
  List<Object?> get props => [searchString];
}

class ToggleFavorite extends MitgliederEvent {
  final int mitgliedsNummer;

  const ToggleFavorite(this.mitgliedsNummer);

  @override
  List<Object?> get props => [mitgliedsNummer];
}

class UpdateFilter extends MitgliederEvent {
  final String? filter;

  const UpdateFilter(this.filter);

  @override
  List<Object?> get props => [filter];
}

// States
abstract class MitgliederState extends Equatable {
  const MitgliederState();

  @override
  List<Object?> get props => [];
}

class MitgliederInitial extends MitgliederState {}

class MitgliederLoading extends MitgliederState {}

class MitgliederLoaded extends MitgliederState {
  final List<Mitglied> mitglieder;
  final String searchString;
  final String? filter;

  const MitgliederLoaded({
    required this.mitglieder,
    this.searchString = '',
    this.filter,
  });

  @override
  List<Object?> get props => [mitglieder, searchString, filter];
}

class MitgliederError extends MitgliederState {
  final String message;

  const MitgliederError(this.message);

  @override
  List<Object?> get props => [message];
}

// Bloc
class MitgliederBloc extends Bloc<MitgliederEvent, MitgliederState> {
  final MemberService _memberService;

  MitgliederBloc(this._memberService) : super(MitgliederInitial()) {
    on<LoadMitglieder>(_onLoadMitglieder);
    on<UpdateSearchString>(_onUpdateSearchString);
    on<ToggleFavorite>(_onToggleFavorite);
    on<UpdateFilter>(_onUpdateFilter);

    // Listen to member service changes
    _memberService.addListener(() {
      add(LoadMitglieder());
    });
  }

  void _onLoadMitglieder(LoadMitglieder event, Emitter<MitgliederState> emit) {
    try {
      emit(MitgliederLoading());
      final mitglieder = _memberService.getAllMembers();
      emit(
        MitgliederLoaded(
          mitglieder: mitglieder,
          searchString: state is MitgliederLoaded
              ? (state as MitgliederLoaded).searchString
              : '',
          filter: state is MitgliederLoaded
              ? (state as MitgliederLoaded).filter
              : null,
        ),
      );
    } catch (e) {
      emit(MitgliederError('Fehler beim Laden der Mitglieder: $e'));
    }
  }

  void _onUpdateSearchString(
    UpdateSearchString event,
    Emitter<MitgliederState> emit,
  ) {
    if (state is MitgliederLoaded) {
      final currentState = state as MitgliederLoaded;
      emit(
        MitgliederLoaded(
          mitglieder: currentState.mitglieder,
          searchString: event.searchString,
          filter: currentState.filter,
        ),
      );
    }
  }

  void _onToggleFavorite(ToggleFavorite event, Emitter<MitgliederState> emit) {
    try {
      if (_memberService.isFavorite(event.mitgliedsNummer)) {
        _memberService.removeFromFavorites(event.mitgliedsNummer);
      } else {
        _memberService.addToFavorites(event.mitgliedsNummer);
      }
    } catch (e) {
      emit(MitgliederError('Fehler beim Verwalten der Favoriten: $e'));
    }
  }

  void _onUpdateFilter(UpdateFilter event, Emitter<MitgliederState> emit) {
    if (state is MitgliederLoaded) {
      final currentState = state as MitgliederLoaded;
      emit(
        MitgliederLoaded(
          mitglieder: currentState.mitglieder,
          searchString: currentState.searchString,
          filter: event.filter,
        ),
      );
    }
  }
}
