import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../screens/splash_screen.dart';
import '../../screens/streaming_screen.dart';
import '../../theme/app_theme.dart';
import 'app_routes.dart';

GoRouter createAppRouter() {
  return GoRouter(
    initialLocation: AppRoutes.splash,
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.camera,
        builder: (context, state) => const StreamingScreen(),
      ),
    ],
  );
}

class VisionApp extends StatelessWidget {
  const VisionApp({super.key, required this.router});

  final GoRouter router;

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'rtmp_camera',
      themeMode: ThemeMode.system,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      routerConfig: router,
    );
  }
}
