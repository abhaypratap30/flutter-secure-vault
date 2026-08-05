import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vault/data/services/vault_service.dart';
import 'package:vault/logic/blocs/auth_bloc.dart';
import 'package:vault/logic/blocs/backup_bloc.dart';
import 'package:vault/logic/blocs/media_bloc.dart';
import 'package:vault/logic/blocs/notes_bloc.dart';
import 'package:vault/logic/blocs/theme_bloc.dart';
import 'package:vault/presentation/screens/passcode_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize core vault service
  final vaultService = VaultService();
  await vaultService.init();

  // Load last saved theme key
  final prefs = await SharedPreferences.getInstance();
  final initialTheme = prefs.getString('vault_theme') ?? 'purple';

  runApp(
    MultiBlocProvider(
      providers: [
        BlocProvider<VaultThemeBloc>(
          create: (context) => VaultThemeBloc(initialTheme),
        ),
        BlocProvider<VaultAuthBloc>(
          create: (context) => VaultAuthBloc(vaultService)..add(CheckPinSetupEvent()),
        ),
        BlocProvider<VaultNotesBloc>(
          create: (context) => VaultNotesBloc(vaultService)..add(LoadNotesEvent()),
        ),
        BlocProvider<VaultMediaBloc>(
          create: (context) => VaultMediaBloc(vaultService)..add(LoadMediaEvent()),
        ),
        BlocProvider<VaultBackupBloc>(
          create: (context) => VaultBackupBloc(vaultService)..add(LoadBackupStatusEvent()),
        ),
      ],
      child: const MyApp(),
    ),
  );
}

/// Root application widget configuring dynamic ThemeData and initial entry route.
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  ThemeData _buildThemeData(String themeKey) {
    Color primaryColor;
    switch (themeKey) {
      case 'cyan':
        primaryColor = const Color(0xFF00E5FF);
        break;
      case 'emerald':
        primaryColor = const Color(0xFF00E676);
        break;
      case 'sakura':
        primaryColor = const Color(0xFFFF4081);
        break;
      case 'purple':
      default:
        primaryColor = const Color(0xFF9E8CF4);
        break;
    }

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: primaryColor,
      scaffoldBackgroundColor: const Color(0xFF0C091A),
      colorScheme: ColorScheme.dark(
        primary: primaryColor,
        secondary: primaryColor,
        surface: const Color(0xFF130E29),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        iconTheme: IconThemeData(color: Colors.white),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<VaultThemeBloc, VaultThemeState>(
      builder: (context, state) {
        return MaterialApp(
          title: 'Vault',
          theme: _buildThemeData(state.themeKey),
          home: const PasscodeScreen(),
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}