import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vault/data/services/vault_service.dart';

// --- Backup Events ---

/// Base abstract event for cloud backup actions.
abstract class VaultBackupEvent {}

/// Event to load current cloud backup statistics.
class LoadBackupStatusEvent extends VaultBackupEvent {}

/// Event to toggle automatic cloud backup.
class ToggleAutoBackupEvent extends VaultBackupEvent {
  final bool enabled;
  ToggleAutoBackupEvent(this.enabled);
}

/// Event to initiate manual cloud sync.
class SyncBackupEvent extends VaultBackupEvent {}

/// Event to initiate recovery of encrypted files from cloud.
class RecoverBackupEvent extends VaultBackupEvent {}

/// Event to simulate local device data loss.
class SimulateBackupDataLossEvent extends VaultBackupEvent {}

// --- Backup States ---

/// Base abstract state for backup status and actions.
abstract class VaultBackupState {
  final int totalLocal;
  final int backedUpCount;
  final bool isAutoBackup;
  VaultBackupState({
    required this.totalLocal,
    required this.backedUpCount,
    required this.isAutoBackup,
  });
}

/// Initial uninitialized backup state.
class VaultBackupInitial extends VaultBackupState {
  VaultBackupInitial() : super(totalLocal: 0, backedUpCount: 0, isAutoBackup: false);
}

/// State indicating an active backup or recovery operation.
class VaultBackupLoading extends VaultBackupState {
  final String? message;
  VaultBackupLoading({
    this.message,
    required int totalLocal,
    required int backedUpCount,
    required bool isAutoBackup,
  }) : super(totalLocal: totalLocal, backedUpCount: backedUpCount, isAutoBackup: isAutoBackup);
}

/// State representing loaded backup status.
class VaultBackupLoaded extends VaultBackupState {
  VaultBackupLoaded({
    required int totalLocal,
    required int backedUpCount,
    required bool isAutoBackup,
  }) : super(totalLocal: totalLocal, backedUpCount: backedUpCount, isAutoBackup: isAutoBackup);
}

/// State representing successful completion of a backup operation.
class VaultBackupOperationSuccess extends VaultBackupState {
  final String message;
  VaultBackupOperationSuccess({
    required this.message,
    required int totalLocal,
    required int backedUpCount,
    required bool isAutoBackup,
  }) : super(totalLocal: totalLocal, backedUpCount: backedUpCount, isAutoBackup: isAutoBackup);
}

/// State representing a backup error.
class VaultBackupError extends VaultBackupState {
  final String error;
  VaultBackupError({
    required this.error,
    required int totalLocal,
    required int backedUpCount,
    required bool isAutoBackup,
  }) : super(totalLocal: totalLocal, backedUpCount: backedUpCount, isAutoBackup: isAutoBackup);
}

// --- Backup Bloc ---

/// BLoC handling synchronization, cloud recovery, and backup settings.
class VaultBackupBloc extends Bloc<VaultBackupEvent, VaultBackupState> {
  final VaultService vaultService;

  VaultBackupBloc(this.vaultService) : super(VaultBackupInitial()) {
    on<LoadBackupStatusEvent>((event, emit) async {
      emit(VaultBackupLoading(
        message: 'Checking status...',
        totalLocal: state.totalLocal,
        backedUpCount: state.backedUpCount,
        isAutoBackup: state.isAutoBackup,
      ));
      final total = vaultService.items.length;
      int backedUp = 0;
      for (var item in vaultService.items) {
        if (vaultService.backupService.isBackedUp(item.id)) {
          backedUp++;
        }
      }
      final isAuto = vaultService.backupService.isAutoBackupEnabled;
      emit(VaultBackupLoaded(totalLocal: total, backedUpCount: backedUp, isAutoBackup: isAuto));
    });

    on<ToggleAutoBackupEvent>((event, emit) async {
      await vaultService.backupService.setAutoBackup(event.enabled);
      emit(VaultBackupLoaded(
        totalLocal: state.totalLocal,
        backedUpCount: state.backedUpCount,
        isAutoBackup: event.enabled,
      ));
    });

    on<SyncBackupEvent>((event, emit) async {
      emit(VaultBackupLoading(
        message: 'Syncing to cloud...',
        totalLocal: state.totalLocal,
        backedUpCount: state.backedUpCount,
        isAutoBackup: state.isAutoBackup,
      ));
      try {
        await vaultService.syncLocalToCloud();
        final total = vaultService.items.length;
        int backedUp = 0;
        for (var item in vaultService.items) {
          if (vaultService.backupService.isBackedUp(item.id)) {
            backedUp++;
          }
        }
        emit(VaultBackupOperationSuccess(
          message: 'Synchronization Complete.',
          totalLocal: total,
          backedUpCount: backedUp,
          isAutoBackup: state.isAutoBackup,
        ));
      } catch (e) {
        emit(VaultBackupError(
          error: e.toString(),
          totalLocal: state.totalLocal,
          backedUpCount: state.backedUpCount,
          isAutoBackup: state.isAutoBackup,
        ));
      }
    });

    on<RecoverBackupEvent>((event, emit) async {
      emit(VaultBackupLoading(
        message: 'Recovering from cloud...',
        totalLocal: state.totalLocal,
        backedUpCount: state.backedUpCount,
        isAutoBackup: state.isAutoBackup,
      ));
      try {
        final recovered = await vaultService.recoverFromCloud();
        final total = vaultService.items.length;
        int backedUp = 0;
        for (var item in vaultService.items) {
          if (vaultService.backupService.isBackedUp(item.id)) {
            backedUp++;
          }
        }
        emit(VaultBackupOperationSuccess(
          message: 'Recovered $recovered items successfully.',
          totalLocal: total,
          backedUpCount: backedUp,
          isAutoBackup: state.isAutoBackup,
        ));
      } catch (e) {
        emit(VaultBackupError(
          error: e.toString(),
          totalLocal: state.totalLocal,
          backedUpCount: state.backedUpCount,
          isAutoBackup: state.isAutoBackup,
        ));
      }
    });

    on<SimulateBackupDataLossEvent>((event, emit) async {
      emit(VaultBackupLoading(
        message: 'Simulating data loss...',
        totalLocal: state.totalLocal,
        backedUpCount: state.backedUpCount,
        isAutoBackup: state.isAutoBackup,
      ));
      try {
        await vaultService.simulateDeviceLoss();
        emit(VaultBackupOperationSuccess(
          message: 'Device loss simulated. Vault data wiped locally.',
          totalLocal: 0,
          backedUpCount: state.backedUpCount,
          isAutoBackup: state.isAutoBackup,
        ));
      } catch (e) {
        emit(VaultBackupError(
          error: e.toString(),
          totalLocal: state.totalLocal,
          backedUpCount: state.backedUpCount,
          isAutoBackup: state.isAutoBackup,
        ));
      }
    });
  }
}
