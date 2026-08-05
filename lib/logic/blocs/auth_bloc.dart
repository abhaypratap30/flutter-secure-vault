import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vault/data/services/vault_service.dart';

// --- Auth Events ---

/// Base abstract event for authentication actions.
abstract class VaultAuthEvent {}

/// Event triggered on application startup to check if a PIN is set.
class CheckPinSetupEvent extends VaultAuthEvent {}

/// Event to verify entered PIN against Master or Decoy hashes.
class VerifyPinEvent extends VaultAuthEvent {
  final String pin;
  VerifyPinEvent(this.pin);
}

/// Event to set up initial Master PIN.
class SetupPinEvent extends VaultAuthEvent {
  final String pin;
  SetupPinEvent(this.pin);
}

/// Event to trigger biometric authentication (Fingerprint / Face ID).
class AuthenticateBiometricEvent extends VaultAuthEvent {
  final bool swipeDecoy;
  AuthenticateBiometricEvent({this.swipeDecoy = false});
}

/// Event to lock the vault and purge keys from memory.
class LockVaultEvent extends VaultAuthEvent {}

// --- Auth States ---

/// Base abstract state for authentication flow.
abstract class VaultAuthState {}

/// Initial uninitialized state.
class VaultAuthInitial extends VaultAuthState {}

/// State indicating the vault is locked.
class VaultAuthLockedState extends VaultAuthState {
  final bool isPinSet;
  VaultAuthLockedState(this.isPinSet);
}

/// State indicating user is confirming their new passcode during setup.
class VaultAuthSetupConfirmState extends VaultAuthState {
  final String firstPin;
  VaultAuthSetupConfirmState(this.firstPin);
}

/// State indicating the vault is unlocked.
class VaultAuthUnlockedState extends VaultAuthState {
  final bool isDecoy;
  VaultAuthUnlockedState({required this.isDecoy});
}

/// State for reporting authentication error messages.
class VaultAuthErrorState extends VaultAuthState {
  final String message;
  VaultAuthErrorState(this.message);
}

/// State triggered when fake crash PIN is entered.
class VaultAuthFakeCrashState extends VaultAuthState {}

/// State indicating authentication is processing.
class VaultAuthProcessing extends VaultAuthState {}

// --- Auth Bloc ---

/// BLoC responsible for managing authentication, PIN setup, biometric unlock, and stealth features.
class VaultAuthBloc extends Bloc<VaultAuthEvent, VaultAuthState> {
  final VaultService vaultService;

  VaultAuthBloc(this.vaultService) : super(VaultAuthInitial()) {
    on<CheckPinSetupEvent>((event, emit) {
      emit(VaultAuthLockedState(vaultService.isPinSet));
    });

    on<VerifyPinEvent>((event, emit) async {
      emit(VaultAuthProcessing());

      // Fake Crash PIN Check
      if (vaultService.fakeCrashPin.isNotEmpty && event.pin == vaultService.fakeCrashPin) {
        emit(VaultAuthFakeCrashState());
        return;
      }

      // Bluetooth Smart Key Verification
      if (vaultService.isBluetoothKeyEnabled) {
        final keyName = vaultService.bluetoothKeyDeviceName.toLowerCase();
        await Future.delayed(const Duration(milliseconds: 1000));
        if (keyName.contains('fail') || keyName.contains('error')) {
          emit(VaultAuthErrorState('Bluetooth Smart Key not found.'));
          emit(VaultAuthLockedState(vaultService.isPinSet));
          return;
        }
      }

      final success = await vaultService.verifyAndUnlock(event.pin);
      if (success) {
        emit(VaultAuthUnlockedState(isDecoy: vaultService.isDecoySession));
      } else {
        emit(VaultAuthErrorState('Incorrect Passcode'));
        emit(VaultAuthLockedState(vaultService.isPinSet));
      }
    });

    on<SetupPinEvent>((event, emit) async {
      emit(VaultAuthProcessing());
      final success = await vaultService.setPin(event.pin);
      if (success) {
        emit(VaultAuthUnlockedState(isDecoy: false));
      } else {
        emit(VaultAuthErrorState('Failed to save master passcode.'));
        emit(VaultAuthLockedState(vaultService.isPinSet));
      }
    });

    on<AuthenticateBiometricEvent>((event, emit) async {
      emit(VaultAuthProcessing());
      bool success = false;
      if (event.swipeDecoy && vaultService.isBiometricGestureDecoyEnabled) {
        success = await vaultService.authenticateDecoyWithBiometrics();
      } else {
        success = await vaultService.authenticateWithBiometrics();
      }

      if (success) {
        emit(VaultAuthUnlockedState(isDecoy: vaultService.isDecoySession));
      } else {
        emit(VaultAuthErrorState('Biometric authentication failed.'));
        emit(VaultAuthLockedState(vaultService.isPinSet));
      }
    });

    on<LockVaultEvent>((event, emit) {
      vaultService.lock();
      emit(VaultAuthLockedState(vaultService.isPinSet));
    });
  }
}
