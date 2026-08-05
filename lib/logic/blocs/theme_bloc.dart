import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

// --- Theme Events ---

/// Base abstract event for dynamic theme switching.
abstract class VaultThemeEvent {}

/// Event to update active theme key ('purple', 'cyan', 'emerald', 'sakura').
class ChangeThemeEvent extends VaultThemeEvent {
  final String themeKey;
  ChangeThemeEvent(this.themeKey);
}

// --- Theme States ---

/// State carrying active theme palette key.
class VaultThemeState {
  final String themeKey;
  VaultThemeState(this.themeKey);
}

// --- Theme Bloc ---

/// BLoC responsible for persisting and broadcasting theme changes across the UI.
class VaultThemeBloc extends Bloc<VaultThemeEvent, VaultThemeState> {
  VaultThemeBloc(String initialTheme) : super(VaultThemeState(initialTheme)) {
    on<ChangeThemeEvent>((event, emit) async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('vault_theme', event.themeKey);
      emit(VaultThemeState(event.themeKey));
    });
  }
}
