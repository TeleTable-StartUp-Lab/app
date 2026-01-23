import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  Future<bool> login(String username, String password) async {
    try {
      // TODO: Implement actual authentication with backend
      // For now, we'll use a simple mock authentication
      if (username.isNotEmpty && password.isNotEmpty) {
        _isAuthenticated = true;
        _username = username;
        _token = 'mock_token_${DateTime.now().millisecondsSinceEpoch}';
        
        await _prefs.setBool('isAuthenticated', true);
        await _prefs.setString('username', username);
        await _prefs.setString('token', _token!);
        
        notifyListeners();
        return true;
      }
      return false;
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
      // TODO: Implement real registration with backend
      if (username.isEmpty || password.isEmpty) return false;

      // Mock: immediately authenticate after register
      _isAuthenticated = true;
      _username = username;
      _token = 'mock_token_${DateTime.now().millisecondsSinceEpoch}';

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