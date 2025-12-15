import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'theme/app_theme.dart';
import 'providers/auth_provider.dart';
import 'providers/robot_control_provider.dart';
import 'providers/diary_provider.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/control_screen.dart';
import 'screens/route_planning_screen.dart';
import 'screens/diary_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  
  runApp(TeleTableApp(prefs: prefs));
}

class TeleTableApp extends StatelessWidget {
  final SharedPreferences prefs;

  const TeleTableApp({super.key, required this.prefs});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider(prefs)),
        ChangeNotifierProvider(create: (_) => RobotControlProvider()),
        ChangeNotifierProvider(create: (_) => DiaryProvider()),
      ],
      child: Consumer<AuthProvider>(
        builder: (context, authProvider, _) {
          final GoRouter router = GoRouter(
            initialLocation: authProvider.isAuthenticated ? '/home' : '/login',
            routes: [
              GoRoute(
                path: '/login',
                builder: (context, state) => const LoginScreen(),
              ),
              GoRoute(
                path: '/home',
                builder: (context, state) => const HomeScreen(),
              ),
              GoRoute(
                path: '/control',
                builder: (context, state) => const ControlScreen(),
              ),
              GoRoute(
                path: '/route-planning',
                builder: (context, state) => const RoutePlanningScreen(),
              ),
              GoRoute(
                path: '/diary',
                builder: (context, state) => const DiaryScreen(),
              ),
            ],
            redirect: (context, state) {
              final isAuthenticated = authProvider.isAuthenticated;
              final isLoginRoute = state.matchedLocation == '/login';
              
              if (!isAuthenticated && !isLoginRoute) {
                return '/login';
              }
              if (isAuthenticated && isLoginRoute) {
                return '/home';
              }
              return null;
            },
          );

          return MaterialApp.router(
            title: 'TeleTable Robot Control',
            theme: AppTheme.darkTheme,
            routerConfig: router,
            debugShowCheckedModeBanner: false,
          );
        },
      ),
    );
  }
}