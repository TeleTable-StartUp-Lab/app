import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';

class AuthProvider with ChangeNotifier {
  final SharedPreferences _prefs;
  final ApiService _apiService;
  
  bool _isAuthenticated = false;
  String? _username;
  String? _email;
  String? _userId;
  String? _token;
  String? _errorMessage;

  AuthProvider(this._prefs, this._apiService) {
    _loadAuthState();
  }

  bool get isAuthenticated => _isAuthenticated;
  String? get username => _username;
  String? get email => _email;
  String? get userId => _userId;
  String? get token => _token;
  String? get errorMessage => _errorMessage;

  Future<void> _loadAuthState() async {
    _isAuthenticated = _prefs.getBool('isAuthenticated') ?? false;
    _username = _prefs.getString('username');
    _email = _prefs.getString('email');
    _userId = _prefs.getString('userId');
    _token = _prefs.getString('token');
    
    // Initialize API service and load token
    await _apiService.init();
    
    // Verify token is still valid by trying to get user info
    if (_isAuthenticated && _token != null) {
      try {
        final userInfo = await _apiService.getMe();
        _username = userInfo['name'] as String;
        _email = userInfo['email'] as String;
        _userId = userInfo['id'] as String;
      } catch (e) {
        debugPrint('Token invalid, logging out: $e');
        await logout();
      }
    }
    
    notifyListeners();
  }

  Future<bool> login(String email, String password) async {
    try {
      _errorMessage = null;
      
      if (email.isEmpty || password.isEmpty) {
        _errorMessage = 'Email and password are required';
        notifyListeners();
        return false;
      }

      // Call backend login endpoint
      final token = await _apiService.login(
        email: email,
        password: password,
      );

      // Get user info with the token
      final userInfo = await _apiService.getMe();

      // Save authentication state
      _isAuthenticated = true;
      _username = userInfo['name'] as String;
      _email = userInfo['email'] as String;
      _userId = userInfo['id'] as String;
      _token = token;
      
      await _prefs.setBool('isAuthenticated', true);
      await _prefs.setString('username', _username!);
      await _prefs.setString('email', _email!);
      await _prefs.setString('userId', _userId!);
      await _prefs.setString('token', token);
      
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Login error: $e');
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    _isAuthenticated = false;
    _username = null;
    _email = null;
    _userId = null;
    _token = null;
    _errorMessage = null;
    
    await _apiService.clearToken();
    
    await _prefs.remove('isAuthenticated');
    await _prefs.remove('username');
    await _prefs.remove('email');
    await _prefs.remove('userId');
    await _prefs.remove('token');
    
    notifyListeners();
  }

  Future<bool> register(String name, String email, String password) async {
    try {
      _errorMessage = null;
      
      if (name.isEmpty || email.isEmpty || password.isEmpty) {
        _errorMessage = 'All fields are required';
        notifyListeners();
        return false;
      }

      // Call backend register endpoint
      final userResponse = await _apiService.register(
        name: name,
        email: email,
        password: password,
      );

      debugPrint('Registration successful: $userResponse');

      // Automatically log in after successful registration
      return await login(email, password);
    } catch (e) {
      debugPrint('Register error: $e');
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  // Clear error message
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}