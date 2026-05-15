import 'package:flutter/material.dart';
import 'screens/config_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  static const Color liveAccent = Color(0xFFE53935);

  @override
  Widget build(BuildContext context) {
    final base = ThemeData.dark();
    return MaterialApp(
      title: 'rtmp_camera',
      theme: base.copyWith(
        colorScheme: base.colorScheme.copyWith(
          primary: liveAccent,
          secondary: liveAccent,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: liveAccent,
            foregroundColor: Colors.white,
          ),
        ),
      ),
      home: const ConfigScreen(),
    );
  }
}
