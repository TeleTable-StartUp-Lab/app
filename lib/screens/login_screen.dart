import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/diary_provider.dart';
import '../providers/robot_control_provider.dart';

class LoginScreen extends StatefulWidget {
  final bool allowBackToDashboard;

  const LoginScreen({
    super.key,
    this.allowBackToDashboard = false,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.login(
      _emailController.text.trim(),
      _passwordController.text,
    );

    if (!mounted) {
      return;
    }

    setState(() => _isLoading = false);

    if (success) {
      await _handleAuthenticatedNavigation();
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(authProvider.errorMessage ?? 'Login failed. Please check your credentials.'),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Future<void> _switchSavedUser(SavedUserSession session) async {
    if (_isLoading) {
      return;
    }

    setState(() => _isLoading = true);
    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.switchToSavedUser(session.userId);

    if (!mounted) {
      return;
    }

    setState(() => _isLoading = false);

    if (success) {
      await _handleAuthenticatedNavigation();
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(authProvider.errorMessage ?? 'Failed to switch account.'),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Future<void> _handleAuthenticatedNavigation() async {
    final robot = context.read<RobotControlProvider>();
    final diary = context.read<DiaryProvider>();

    robot.resetSession();
    diary.clearEntries();

    await robot.initialize();
    unawaited(diary.loadEntries());

    if (!mounted) {
      return;
    }

    context.go('/dashboard');
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final savedUsers = auth.savedUsers;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                bottom: MediaQuery.viewInsetsOf(context).bottom + 24,
                top: 24,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight - 48),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (widget.allowBackToDashboard && auth.isAuthenticated)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () => context.go('/dashboard'),
                          icon: const Icon(Icons.arrow_back),
                          label: const Text('Back to dashboard'),
                        ),
                      ),
                    SvgPicture.asset(
                      'assets/branding/favicon.svg',
                      width: 88,
                      height: 88,
                    ),
                    const SizedBox(height: 24),
                    Center(
                      child: RichText(
                        text: TextSpan(
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                          children: [
                            const TextSpan(text: 'Tele', style: TextStyle(color: Colors.white)),
                            TextSpan(
                              text: 'Table',
                              style: TextStyle(color: Theme.of(context).colorScheme.primary),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      savedUsers.isEmpty ? 'Welcome Back' : 'Choose a saved account or sign in',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Colors.grey,
                          ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    if (savedUsers.isNotEmpty) ...[
                      _SavedUsersCard(
                        savedUsers: savedUsers,
                        activeUserId: auth.activeUserId,
                        isLoading: _isLoading,
                        onSelect: _switchSavedUser,
                      ),
                      const SizedBox(height: 24),
                    ],
                    Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _emailController,
                            decoration: const InputDecoration(
                              labelText: 'Email',
                              prefixIcon: Icon(Icons.email),
                            ),
                            keyboardType: TextInputType.emailAddress,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your email';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            decoration: InputDecoration(
                              labelText: 'Password',
                              prefixIcon: const Icon(Icons.lock),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword ? Icons.visibility : Icons.visibility_off,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your password';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _login,
                              child: _isLoading
                                  ? const CircularProgressIndicator()
                                  : Text(savedUsers.isEmpty ? 'Sign in' : 'Add account'),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!widget.allowBackToDashboard) ...[
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () {
                              if (mounted) {
                                context.push('/register');
                              }
                            },
                            child: const Text('Create account'),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SavedUsersCard extends StatelessWidget {
  final List<SavedUserSession> savedUsers;
  final String? activeUserId;
  final bool isLoading;
  final ValueChanged<SavedUserSession> onSelect;

  const _SavedUsersCard({
    required this.savedUsers,
    required this.activeUserId,
    required this.isLoading,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Saved users',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            for (final user in savedUsers)
              ListTile(
                contentPadding: EdgeInsets.zero,
                enabled: !isLoading,
                onTap: () => onSelect(user),
                leading: CircleAvatar(
                  child: Text(
                    _initialsFor(user),
                  ),
                ),
                title: Text(user.name ?? user.email ?? 'Unknown user'),
                subtitle: Text(user.email ?? user.role),
                trailing: user.userId == activeUserId
                    ? const Icon(Icons.check_circle, color: Colors.green)
                    : const Icon(Icons.swap_horiz),
              ),
          ],
        ),
      ),
    );
  }

  String _initialsFor(SavedUserSession user) {
    final source = (user.name ?? user.email ?? '').trim();
    if (source.isEmpty) {
      return '?';
    }
    final parts = source.split(RegExp(r'\s+'));
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'.toUpperCase();
  }
}
