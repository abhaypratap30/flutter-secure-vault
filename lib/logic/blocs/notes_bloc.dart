import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vault/data/models/vault_note.dart';
import 'package:vault/data/services/vault_service.dart';

// --- Notes Events ---

/// Base abstract event for secure note management.
abstract class VaultNotesEvent {}

/// Event to load notes from encrypted vault storage.
class LoadNotesEvent extends VaultNotesEvent {}

/// Event to add a new secure note.
class AddNoteEvent extends VaultNotesEvent {
  final String title;
  final String content;
  AddNoteEvent({required this.title, required this.content});
}

/// Event to update an existing secure note.
class UpdateNoteEvent extends VaultNotesEvent {
  final String id;
  final String title;
  final String content;
  UpdateNoteEvent({required this.id, required this.title, required this.content});
}

/// Event to delete a secure note.
class DeleteNoteEvent extends VaultNotesEvent {
  final String id;
  DeleteNoteEvent(this.id);
}

// --- Notes States ---

/// Base abstract state for secure notes.
abstract class VaultNotesState {
  final List<VaultNote> notes;
  VaultNotesState({required this.notes});
}

/// Initial uninitialized notes state.
class VaultNotesInitial extends VaultNotesState {
  VaultNotesInitial() : super(notes: []);
}

/// State indicating an active notes operation.
class VaultNotesLoading extends VaultNotesState {
  VaultNotesLoading({required List<VaultNote> notes}) : super(notes: notes);
}

/// State representing loaded notes list.
class VaultNotesLoaded extends VaultNotesState {
  VaultNotesLoaded({required List<VaultNote> notes}) : super(notes: notes);
}

/// State representing a successful notes operation.
class VaultNotesOperationSuccess extends VaultNotesState {
  final String message;
  VaultNotesOperationSuccess({required this.message, required List<VaultNote> notes}) : super(notes: notes);
}

/// State representing a notes operation error.
class VaultNotesError extends VaultNotesState {
  final String error;
  VaultNotesError({required this.error, required List<VaultNote> notes}) : super(notes: notes);
}

// --- Notes Bloc ---

/// BLoC handling secure encrypted notes CRUD operations.
class VaultNotesBloc extends Bloc<VaultNotesEvent, VaultNotesState> {
  final VaultService vaultService;

  VaultNotesBloc(this.vaultService) : super(VaultNotesInitial()) {
    on<LoadNotesEvent>((event, emit) {
      emit(VaultNotesLoading(notes: state.notes));
      emit(VaultNotesLoaded(notes: List.from(vaultService.notes)));
    });

    on<AddNoteEvent>((event, emit) async {
      emit(VaultNotesLoading(notes: state.notes));
      try {
        await vaultService.addNote(event.title, event.content);
        emit(VaultNotesOperationSuccess(message: 'Note created successfully.', notes: List.from(vaultService.notes)));
      } catch (e) {
        emit(VaultNotesError(error: e.toString(), notes: state.notes));
      }
    });

    on<UpdateNoteEvent>((event, emit) async {
      emit(VaultNotesLoading(notes: state.notes));
      try {
        await vaultService.updateNote(event.id, event.title, event.content);
        emit(VaultNotesOperationSuccess(message: 'Note updated successfully.', notes: List.from(vaultService.notes)));
      } catch (e) {
        emit(VaultNotesError(error: e.toString(), notes: state.notes));
      }
    });

    on<DeleteNoteEvent>((event, emit) async {
      emit(VaultNotesLoading(notes: state.notes));
      try {
        await vaultService.deleteNote(event.id);
        emit(VaultNotesOperationSuccess(message: 'Note deleted successfully.', notes: List.from(vaultService.notes)));
      } catch (e) {
        emit(VaultNotesError(error: e.toString(), notes: state.notes));
      }
    });
  }
}
