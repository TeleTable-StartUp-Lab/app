import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class AuthProvider with ChangeNotifier {
  final SharedPreferences _prefs;
  bool _isAuthenticated = false;
  String? _username;
  String? _token;

  AuthProvider(this._prefs) {
    _loadAuthState();
  }

  bool get isAuthenticated => _isAuthenticated;
  String? get username => _username;
  String? get token => _token;

  Future<void> _loadAuthState() async {
    _isAuthenticated = _prefs.getBool('isAuthenticated') ?? false;
    _username = _prefs.getString('username');
    _token = _prefs.getString('token');
    notifyListeners();
  }

  // Get all registered users
  Map<String, dynamic> _getRegisteredUsers() {
    final usersJson = _prefs.getString('registered_users');
    if (usersJson == null) return {};
    try {
      return Map<String, dynamic>.from(json.decode(usersJson));
    } catch (e) {
      return {};
    }
  }

  // Save registered users
  Future<void> _saveRegisteredUsers(Map<String, dynamic> users) async {
    await _prefs.setString('registered_users', json.encode(users));
  }

  Future<bool> login(String username, String password) async {
    try {
      if (username.isEmpty || password.isEmpty) {
        return false;
      }

      // Check if user is registered
      final registeredUsers = _getRegisteredUsers();
      
      if (!registeredUsers.containsKey(username)) {
        debugPrint('Login failed: User not registered');
        return false;
      }

      // Verify password
      final userData = registeredUsers[username] as Map<String, dynamic>;
      if (userData['password'] != password) {
        debugPrint('Login failed: Invalid password');
        return false;
      }

      // Successful login
      _isAuthenticated = true;
      _username = username;
      _token = 'token_${DateTime.now().millisecondsSinceEpoch}';
      
      await _prefs.setBool('isAuthenticated', true);
      await _prefs.setString('username', username);
      await _prefs.setString('token', _token!);
      
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Login error: $e');
      return false;
    }
  }

  Future<void> logout() async {
    _isAuthenticated = false;
    _username = null;
    _token = null;
    
    await _prefs.remove('isAuthenticated');
    await _prefs.remove('username');
    await _prefs.remove('token');
    
    notifyListeners();
  }

  Future<bool> register(String username, String email, String password) async {
    try {
      if (username.isEmpty || password.isEmpty) {
        debugPrint('Registration failed: Username and password required');
        return false;
      }

      // Check if user already exists
      final registeredUsers = _getRegisteredUsers();
      
      if (registeredUsers.containsKey(username)) {
        debugPrint('Registration failed: Username already exists');
        return false;
      }

      // Register new user
      registeredUsers[username] = {
        'email': email,
        'password': password,
        'registeredAt': DateTime.now().toIso8601String(),
      };

      await _saveRegisteredUsers(registeredUsers);

      // Automatically log in after successful registration
      _isAuthenticated = true;
      _username = username;
      _token = 'token_${DateTime.now().millisecondsSinceEpoch}';

      await _prefs.setBool('isAuthenticated', true);
      await _prefs.setString('username', username);
      await _prefs.setString('token', _token!);

      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Register error: $e');
      return false;
    }
  }
}