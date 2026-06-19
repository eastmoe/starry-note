import 'package:flutter/material.dart';

import 'app_controller.dart';
import 'screens/setup_screen.dart';
import 'screens/studio_screen.dart';
import 'screens/welcome_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final controller = AppController();
  await controller.initialize();
  runApp(StarryNoteApp(controller: controller));
}

class StarryNoteApp extends StatelessWidget {
  const StarryNoteApp({super.key, required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
      animation: controller,
      builder: (context, _) => MaterialApp(
            title: 'StarryNote',
            debugShowCheckedModeBanner: false,
            themeMode: controller.settings.followSystemTheme
                ? ThemeMode.system
                : controller.settings.darkMode
                    ? ThemeMode.dark
                    : ThemeMode.light,
            theme: _theme(Brightness.light),
            darkTheme: _theme(Brightness.dark),
            home: !controller.settings.onboardingCompleted
                ? WelcomeScreen(controller: controller)
                : controller.hasRepository
                    ? StudioScreen(controller: controller)
                    : SetupScreen(controller: controller),
          ));

  ThemeData _theme(Brightness brightness) {
    final seed = Color(controller.settings.primaryColorValue);
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
    );
    final pureBlack =
        brightness == Brightness.dark && controller.settings.pureBlackMode;
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: pureBlack ? Colors.black : scheme.surface,
      canvasColor: pureBlack ? Colors.black : scheme.surface,
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
        filled: true,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
    );
  }
}
