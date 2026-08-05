import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vault/data/models/vault_item.dart';
import 'package:vault/data/services/vault_service.dart';

// --- Media Events ---

/// Base abstract event for media management.
abstract class VaultMediaEvent {}

/// Event to load media items from vault storage.
class LoadMediaEvent extends VaultMediaEvent {}

/// Event to restore selected media items to gallery.
class RestoreMediaEvent extends VaultMediaEvent {
  final List<VaultItem> items;
  RestoreMediaEvent(this.items);
}

/// Event to permanently delete selected media items.
class DeleteMediaEvent extends VaultMediaEvent {
  final List<VaultItem> items;
  DeleteMediaEvent(this.items);
}

/// Event to toggle item selection state for multi-select operations.
class ToggleMediaSelectionEvent extends VaultMediaEvent {
  final VaultItem item;
  ToggleMediaSelectionEvent(this.item);
}

/// Event to clear active selection mode.
class ClearMediaSelectionEvent extends VaultMediaEvent {}

// --- Media States ---

/// Base abstract state for vault media.
abstract class VaultMediaState {
  final List<VaultItem> items;
  final List<VaultItem> selectedItems;
  final bool isSelectionMode;
  VaultMediaState({
    required this.items,
    required this.selectedItems,
    required this.isSelectionMode,
  });
}

/// Initial uninitialized media state.
class VaultMediaInitial extends VaultMediaState {
  VaultMediaInitial() : super(items: [], selectedItems: [], isSelectionMode: false);
}

/// State indicating an active media loading or file action.
class VaultMediaLoading extends VaultMediaState {
  final String? message;
  VaultMediaLoading({
    this.message,
    required List<VaultItem> items,
    required List<VaultItem> selectedItems,
    required bool isSelectionMode,
  }) : super(items: items, selectedItems: selectedItems, isSelectionMode: isSelectionMode);
}

/// State representing loaded media list and active selections.
class VaultMediaLoaded extends VaultMediaState {
  VaultMediaLoaded({
    required List<VaultItem> items,
    required List<VaultItem> selectedItems,
    required bool isSelectionMode,
  }) : super(items: items, selectedItems: selectedItems, isSelectionMode: isSelectionMode);
}

/// State representing a successful media operation.
class VaultMediaOperationSuccess extends VaultMediaState {
  final String message;
  VaultMediaOperationSuccess({
    required this.message,
    required List<VaultItem> items,
    required List<VaultItem> selectedItems,
    required bool isSelectionMode,
  }) : super(items: items, selectedItems: selectedItems, isSelectionMode: isSelectionMode);
}

/// State representing a media operation error.
class VaultMediaOperationError extends VaultMediaState {
  final String error;
  VaultMediaOperationError({
    required this.error,
    required List<VaultItem> items,
    required List<VaultItem> selectedItems,
    required bool isSelectionMode,
  }) : super(items: items, selectedItems: selectedItems, isSelectionMode: isSelectionMode);
}

// --- Media Bloc ---

/// BLoC handling vault media encryption list, selection mode, restoration, and deletion.
class VaultMediaBloc extends Bloc<VaultMediaEvent, VaultMediaState> {
  final VaultService vaultService;

  VaultMediaBloc(this.vaultService) : super(VaultMediaInitial()) {
    on<LoadMediaEvent>((event, emit) {
      emit(VaultMediaLoading(
        message: 'Loading media...',
        items: state.items,
        selectedItems: state.selectedItems,
        isSelectionMode: state.isSelectionMode,
      ));
      emit(VaultMediaLoaded(
        items: List.from(vaultService.items),
        selectedItems: const [],
        isSelectionMode: false,
      ));
    });

    on<ToggleMediaSelectionEvent>((event, emit) {
      final selected = List<VaultItem>.from(state.selectedItems);
      if (selected.contains(event.item)) {
        selected.remove(event.item);
      } else {
        selected.add(event.item);
      }
      final isSel = selected.isNotEmpty;
      emit(VaultMediaLoaded(items: state.items, selectedItems: selected, isSelectionMode: isSel));
    });

    on<ClearMediaSelectionEvent>((event, emit) {
      emit(VaultMediaLoaded(items: state.items, selectedItems: const [], isSelectionMode: false));
    });

    on<RestoreMediaEvent>((event, emit) async {
      emit(VaultMediaLoading(
        message: 'Restoring selected media...',
        items: state.items,
        selectedItems: state.selectedItems,
        isSelectionMode: state.isSelectionMode,
      ));
      int restored = 0;
      for (var item in event.items) {
        final success = await vaultService.restoreItem(item);
        if (success) restored++;
      }
      emit(VaultMediaOperationSuccess(
        message: 'Successfully restored $restored items.',
        items: List.from(vaultService.items),
        selectedItems: const [],
        isSelectionMode: false,
      ));
    });

    on<DeleteMediaEvent>((event, emit) async {
      emit(VaultMediaLoading(
        message: 'Deleting selected media...',
        items: state.items,
        selectedItems: state.selectedItems,
        isSelectionMode: state.isSelectionMode,
      ));
      int deleted = 0;
      for (var item in event.items) {
        final success = await vaultService.deleteItem(item);
        if (success) deleted++;
      }
      emit(VaultMediaOperationSuccess(
        message: 'Permanently deleted $deleted items.',
        items: List.from(vaultService.items),
        selectedItems: const [],
        isSelectionMode: false,
      ));
    });
  }
}
