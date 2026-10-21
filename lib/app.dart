import 'package:flutter/material.dart';

import 'screens/home_screen.dart';

class XFastSignalApp extends StatelessWidget {
  const XFastSignalApp({super.key});

  // Синій Signal.
  static const _seed = Color(0xFF3A76F0);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'xFastSignal',
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: _seed)),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: _seed, brightness: Brightness.dark),
      ),
      home: const HomeScreen(),
    );
  }
}
