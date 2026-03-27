import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'theme/app_theme.dart';
import 'providers/auth_provider.dart';
import 'providers/robot_control_provider.dart';
import 'providers/diary_provider.dart';
import 'services/api_service.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/diary_screen.dart';
import 'screens/queue_control_screen.dart';
import 'screens/admin_panel_screen.dart';

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
    // Create a single ApiService instance to share across providers
    final apiService = ApiService();
    
    return MultiProvider(
      providers: [
        Provider<ApiService>.value(value: apiService),
        ChangeNotifierProvider(create: (_) => AuthProvider(prefs, apiService)),
        ChangeNotifierProvider(create: (_) => RobotControlProvider(apiService)),
        ChangeNotifierProvider(create: (_) => DiaryProvider(apiService)),
      ],
      child: Consumer<AuthProvider>(
        builder: (context, authProvider, _) {
          final GoRouter router = GoRouter(
            initialLocation: authProvider.isAuthenticated ? '/dashboard' : '/login',
            routes: [
              GoRoute(
                path: '/login',
                builder: (context, state) => const LoginScreen(),
              ),
              GoRoute(
                path: '/register',
                builder: (context, state) => const RegisterScreen(),
              ),
              GoRoute(
                path: '/home',
                builder: (context, state) => const DashboardScreen(),
              ),
              GoRoute(
                path: '/dashboard',
                builder: (context, state) => const DashboardScreen(),
              ),
              GoRoute(
                path: '/diary',
                builder: (context, state) => const DiaryScreen(),
              ),
              GoRoute(
                path: '/queue',
                builder: (context, state) => const QueueControlScreen(),
              ),
              GoRoute(
                path: '/admin',
                builder: (context, state) => const AdminPanelScreen(),
              ),
            ],
            redirect: (context, state) {
              final isAuthenticated = authProvider.isAuthenticated;
              final isAdmin = authProvider.isAdmin;
              final isLoginRoute = state.matchedLocation == '/login';
              final isRegisterRoute = state.matchedLocation == '/register';
              final isAdminRoute = state.matchedLocation == '/admin';
              final isQueueRoute = state.matchedLocation == '/queue';
              
              if (!isAuthenticated && !isLoginRoute && !isRegisterRoute) {
                return '/login';
              }
              if (isAuthenticated && (isLoginRoute || isRegisterRoute)) {
                return '/dashboard';
              }
              if ((isAdminRoute || isQueueRoute) && !isAdmin) {
                return '/dashboard';
              }
              return null;
            },
          );

          return MaterialApp.router(
            title: 'TeleTable',
            theme: AppTheme.darkTheme,
            routerConfig: router,
            debugShowCheckedModeBanner: false,
          );
        },
      ),
    );
  }
}