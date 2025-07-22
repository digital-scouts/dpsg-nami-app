import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

// Events
abstract class StufeEvent extends Equatable {
  const StufeEvent();

  @override
  List<Object> get props => [];
}

class LoadStufen extends StufeEvent {}

class SelectStufe extends StufeEvent {
  final String stufeId;

  const SelectStufe(this.stufeId);

  @override
  List<Object> get props => [stufeId];
}

class FilterStufenByType extends StufeEvent {
  final String type;

  const FilterStufenByType(this.type);

  @override
  List<Object> get props => [type];
}

// States
abstract class StufeState extends Equatable {
  const StufeState();

  @override
  List<Object> get props => [];
}

class StufeInitial extends StufeState {}

class StufeLoading extends StufeState {}

class StufeLoaded extends StufeState {
  final List<Stufe> stufen;
  final Stufe? selectedStufe;
  final String? filter;

  const StufeLoaded({required this.stufen, this.selectedStufe, this.filter});

  @override
  List<Object> get props => [stufen, selectedStufe ?? '', filter ?? ''];

  StufeLoaded copyWith({
    List<Stufe>? stufen,
    Stufe? selectedStufe,
    String? filter,
  }) {
    return StufeLoaded(
      stufen: stufen ?? this.stufen,
      selectedStufe: selectedStufe ?? this.selectedStufe,
      filter: filter ?? this.filter,
    );
  }
}

class StufeError extends StufeState {
  final String message;

  const StufeError(this.message);

  @override
  List<Object> get props => [message];
}

// Stufe Model
class Stufe extends Equatable {
  final String id;
  final String name;
  final String type; // biber, woe, jufi, pfadi, rover
  final String description;
  final int memberCount;
  final String? imageUrl;

  const Stufe({
    required this.id,
    required this.name,
    required this.type,
    required this.description,
    required this.memberCount,
    this.imageUrl,
  });

  @override
  List<Object> get props => [
    id,
    name,
    type,
    description,
    memberCount,
    imageUrl ?? '',
  ];
}

// Bloc
class StufeBloc extends Bloc<StufeEvent, StufeState> {
  StufeBloc() : super(StufeInitial()) {
    on<LoadStufen>(_onLoadStufen);
    on<SelectStufe>(_onSelectStufe);
    on<FilterStufenByType>(_onFilterStufenByType);
  }

  void _onLoadStufen(LoadStufen event, Emitter<StufeState> emit) async {
    emit(StufeLoading());

    try {
      // Mock data - in real app würde hier ein Repository aufgerufen werden
      await Future.delayed(const Duration(milliseconds: 500));

      final stufen = [
        const Stufe(
          id: '1',
          name: 'Biber',
          type: 'biber',
          description: 'Für die Kleinsten (4-7 Jahre)',
          memberCount: 12,
        ),
        const Stufe(
          id: '2',
          name: 'Wölflinge',
          type: 'woe',
          description: 'Für Kinder von 7-10 Jahren',
          memberCount: 18,
        ),
        const Stufe(
          id: '3',
          name: 'Jungpfadfinder',
          type: 'jufi',
          description: 'Für Kinder von 10-13 Jahren',
          memberCount: 15,
        ),
        const Stufe(
          id: '4',
          name: 'Pfadfinder',
          type: 'pfadi',
          description: 'Für Jugendliche von 13-16 Jahren',
          memberCount: 22,
        ),
        const Stufe(
          id: '5',
          name: 'Rover',
          type: 'rover',
          description: 'Für junge Erwachsene von 16-20 Jahren',
          memberCount: 8,
        ),
      ];

      emit(StufeLoaded(stufen: stufen));
    } catch (e) {
      emit(StufeError('Fehler beim Laden der Stufen: $e'));
    }
  }

  void _onSelectStufe(SelectStufe event, Emitter<StufeState> emit) {
    if (state is StufeLoaded) {
      final currentState = state as StufeLoaded;
      final selectedStufe = currentState.stufen.firstWhere(
        (stufe) => stufe.id == event.stufeId,
        orElse: () => currentState.stufen.first,
      );

      emit(currentState.copyWith(selectedStufe: selectedStufe));
    }
  }

  void _onFilterStufenByType(
    FilterStufenByType event,
    Emitter<StufeState> emit,
  ) {
    if (state is StufeLoaded) {
      final currentState = state as StufeLoaded;
      emit(currentState.copyWith(filter: event.type));
    }
  }
}
