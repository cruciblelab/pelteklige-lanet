import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'services/progress.dart';
import 'services/settings.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Settings.instance.load();
  await Progress.instance.load();
  runApp(const PeltekApp());
}

class PeltekApp extends StatelessWidget {
  const PeltekApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF00897B);
    return MaterialApp(
      title: 'Peltekliğe Lanet',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: seed),
        useMaterial3: true,
        cardTheme: const CardThemeData(clipBehavior: Clip.antiAlias),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: seed,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        cardTheme: const CardThemeData(clipBehavior: Clip.antiAlias),
      ),
      home: const HomeScreen(),
    );
  }
}
