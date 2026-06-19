import 'package:flutter/material.dart';

import 'app_controller.dart';
import 'screens/setup_screen.dart';
import 'screens/studio_screen.dart';

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
  Widget build(BuildContext context) => MaterialApp(
        title: 'StarryNote',
        debugShowCheckedModeBanner: false,
        themeMode: ThemeMode.system,
        theme: _theme(Brightness.light),
        darkTheme: _theme(Brightness.dark),
        home: AnimatedBuilder(
          animation: controller,
          builder: (context, _) => controller.hasRepository
              ? StudioScreen(controller: controller)
              : SetupScreen(controller: controller),
        ),
      );

  ThemeData _theme(Brightness brightness) {
    const seed = Color(0xff7567e8);
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
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
