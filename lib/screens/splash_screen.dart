import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'config_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (context) => const ConfigScreen(),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.surface,
      body: Center(
        child: SvgPicture.asset(
          'assets/svg/logo-visor.svg',
          width: 168,
          height: 168,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}
