import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  // Override with: flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3003
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://teletable.net/api',
  );
  
  static const String _tokenKey = 'auth_token';
  String? _token;
  
  // Initialize and load token from storage
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(_tokenKey);
  }
  
  // Set the JWT token after login
  Future<void> setToken(String token) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }
  
  // Clear the token on logout
  Future<void> clearToken() async {
    _token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }
  
  // Check if user is logged in
  bool get isLoggedIn => _token != null;
  String? get token => _token;
  
  // Get authorization headers
  Map<String, String> get _headers {
    final headers = {
      'Content-Type': 'application/json',
    };
    
    if (_token != null) {
      headers['Authorization'] = 'Bearer $_token';
    }
    
    return headers;
  }

  dynamic _parseBody(http.Response response) {
    if (response.body.isEmpty) {
      return null;
    }
    try {
      return jsonDecode(response.body);
    } catch (_) {
      return null;
    }
  }

  Exception _buildException(http.Response response, String fallback) {
    final parsed = _parseBody(response);
    if (parsed is Map<String, dynamic>) {
      final error = parsed['error'] ?? parsed['message'];
      if (error is String && error.isNotEmpty) {
        return Exception(error);
      }
    }
    return Exception(fallback);
  }
  
  // Auth endpoints
  
  /// Register a new user
  /// POST /register
  /// Body: { "name": string, "email": string, "password": string }
  /// Returns: { "id": uuid, "name": string, "email": string, "role": string }
  Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String password,
    Map<String, dynamic>? fingerprintData,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'name': name,
        'email': email,
        'password': password,
        if (fingerprintData != null) 'fingerprintData': fingerprintData,
      }),
    );
    
    if (response.statusCode == 201) {
      return (_parseBody(response) as Map<String, dynamic>? ?? <String, dynamic>{});
    } else {
      throw _buildException(response, 'Registration failed');
    }
  }
  
  /// Login with email and password
  /// POST /login
  /// Body: { "email": string, "password": string }
  /// Returns: { "token": string }
  Future<String> login({
    required String email,
    required String password,
    Map<String, dynamic>? fingerprintData,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
        if (fingerprintData != null) 'fingerprintData': fingerprintData,
      }),
    );
    
    if (response.statusCode == 200) {
      final data = _parseBody(response) as Map<String, dynamic>? ?? <String, dynamic>{};
      final token = data['token'] as String;
      setToken(token);
      return token;
    } else {
      throw _buildException(response, 'Login failed');
    }
  }
  
  /// Get current user info
  /// GET /me
  /// Returns: { "id": uuid, "name": string, "email": string, "role": string }
  Future<Map<String, dynamic>> getMe() async {
    final response = await http.get(
      Uri.parse('$baseUrl/me'),
      headers: _headers,
    );
    
    if (response.statusCode == 200) {
      return (_parseBody(response) as Map<String, dynamic>? ?? <String, dynamic>{});
    } else {
      throw _buildException(response, 'Failed to get user info');
    }
  }
  
  // Diary endpoints
  
  /// Get all diary entries for the authenticated user
  /// GET /diary
  /// Returns: Array of diary entries
  Future<List<Map<String, dynamic>>> getDiaryEntries() async {
    final response = await http.get(
      Uri.parse('$baseUrl/diary'),
      headers: _headers,
    );
    
    if (response.statusCode == 200) {
      final data = (_parseBody(response) as List? ?? <dynamic>[]);
      return data.cast<Map<String, dynamic>>();
    } else {
      throw _buildException(response, 'Failed to get diary entries');
    }
  }
  
  /// Create a new diary entry
  /// POST /diary
  /// Body: { "working_minutes": int, "text": string }
  /// Returns: Created diary entry
  Future<Map<String, dynamic>> createDiaryEntry({
    required int workingMinutes,
    required String text,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/diary'),
      headers: _headers,
      body: jsonEncode({
        'working_minutes': workingMinutes,
        'text': text,
      }),
    );
    
    if (response.statusCode == 201) {
      return (_parseBody(response) as Map<String, dynamic>? ?? <String, dynamic>{});
    } else {
      throw _buildException(response, 'Failed to create diary entry');
    }
  }
  
  /// Update an existing diary entry
  /// POST /diary
  /// Body: { "id": uuid, "working_minutes": int, "text": string }
  /// Returns: Updated diary entry
  Future<Map<String, dynamic>> updateDiaryEntry({
    required String id,
    required int workingMinutes,
    required String text,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/diary'),
      headers: _headers,
      body: jsonEncode({
        'id': id,
        'working_minutes': workingMinutes,
        'text': text,
      }),
    );
    
    if (response.statusCode == 200) {
      return (_parseBody(response) as Map<String, dynamic>? ?? <String, dynamic>{});
    } else {
      throw _buildException(response, 'Failed to update diary entry');
    }
  }
  
  /// Delete a diary entry
  /// DELETE /diary
  /// Body: { "id": uuid }
  Future<void> deleteDiaryEntry(String id) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/diary'),
      headers: _headers,
      body: jsonEncode({
        'id': id,
      }),
    );
    
    if (response.statusCode != 204) {
      throw _buildException(response, 'Failed to delete diary entry');
    }
  }
  
  // Robot control endpoints
  
  /// Get available nodes for navigation
  /// GET /nodes
  /// Returns: { "nodes": [string] }
  Future<List<String>> getNodes() async {
    final response = await http.get(
      Uri.parse('$baseUrl/nodes'),
      headers: _headers,
    );
    
    if (response.statusCode == 200) {
      final data = _parseBody(response) as Map<String, dynamic>? ?? <String, dynamic>{};
      return (data['nodes'] as List).cast<String>();
    } else {
      throw _buildException(response, 'Failed to get nodes');
    }
  }
  
  /// Select a route for robot navigation
  /// POST /routes/select
  /// Body: { "start": string, "destination": string }
  Future<Map<String, dynamic>> selectRoute({
    required String start,
    required String destination,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/routes/select'),
      headers: _headers,
      body: jsonEncode({
        'start': start,
        'destination': destination,
      }),
    );
    
    if (response.statusCode == 200) {
      return (_parseBody(response) as Map<String, dynamic>? ?? <String, dynamic>{});
    } else {
      throw _buildException(response, 'Failed to select route');
    }
  }

  Future<Map<String, dynamic>> acquireDriveLock() async {
    final response = await http.post(
      Uri.parse('$baseUrl/drive/lock'),
      headers: _headers,
    );
    if (response.statusCode == 200) {
      return (_parseBody(response) as Map<String, dynamic>? ?? <String, dynamic>{});
    }
    throw _buildException(response, 'Failed to acquire drive lock');
  }

  Future<Map<String, dynamic>> releaseDriveLock() async {
    final response = await http.delete(
      Uri.parse('$baseUrl/drive/lock'),
      headers: _headers,
    );
    if (response.statusCode == 200) {
      return (_parseBody(response) as Map<String, dynamic>? ?? <String, dynamic>{});
    }
    throw _buildException(response, 'Failed to release drive lock');
  }

  Future<Map<String, dynamic>> checkRobotConnection() async {
    final response = await http.get(
      Uri.parse('$baseUrl/robot/check'),
      headers: _headers,
    );
    if (response.statusCode == 200) {
      return (_parseBody(response) as Map<String, dynamic>? ?? <String, dynamic>{});
    }
    throw _buildException(response, 'Failed to check robot connection');
  }

  Future<List<Map<String, dynamic>>> getRobotNotifications({
    int limit = 100,
    int offset = 0,
  }) async {
    final response = await http.get(
      Uri.parse('$baseUrl/robot/notifications?limit=$limit&offset=$offset'),
      headers: _headers,
    );
    if (response.statusCode == 200) {
      final data = _parseBody(response) as List? ?? <dynamic>[];
      return data.cast<Map<String, dynamic>>();
    }
    throw _buildException(response, 'Failed to load robot notifications');
  }

  // Queue endpoints

  Future<List<Map<String, dynamic>>> getRoutes() async {
    final response = await http.get(
      Uri.parse('$baseUrl/routes'),
      headers: _headers,
    );
    if (response.statusCode == 200) {
      final data = _parseBody(response) as List? ?? <dynamic>[];
      return data.cast<Map<String, dynamic>>();
    }
    throw _buildException(response, 'Failed to load routes');
  }

  Future<void> deleteRoute(String id) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/routes/$id'),
      headers: _headers,
    );
    if (response.statusCode != 200 && response.statusCode != 204) {
      throw _buildException(response, 'Failed to delete route');
    }
  }

  Future<Map<String, dynamic>> optimizeRoutes() async {
    final response = await http.post(
      Uri.parse('$baseUrl/routes/optimize'),
      headers: _headers,
    );
    if (response.statusCode == 200) {
      return (_parseBody(response) as Map<String, dynamic>? ?? <String, dynamic>{});
    }
    throw _buildException(response, 'Failed to optimize routes');
  }

  // Admin endpoints

  Future<List<Map<String, dynamic>>> getUsers() async {
    final response = await http.get(
      Uri.parse('$baseUrl/users'),
      headers: _headers,
    );
    if (response.statusCode == 200) {
      final data = _parseBody(response) as List? ?? <dynamic>[];
      return data.cast<Map<String, dynamic>>();
    }
    throw _buildException(response, 'Failed to load users');
  }

  Future<Map<String, dynamic>> updateUser({
    required String id,
    String? name,
    String? email,
    String? role,
    String? password,
  }) async {
    final payload = <String, dynamic>{'id': id};
    if (name != null) payload['name'] = name;
    if (email != null) payload['email'] = email;
    if (role != null) payload['role'] = role;
    if (password != null && password.isNotEmpty) payload['password'] = password;

    final response = await http.post(
      Uri.parse('$baseUrl/user'),
      headers: _headers,
      body: jsonEncode(payload),
    );
    if (response.statusCode == 200) {
      return (_parseBody(response) as Map<String, dynamic>? ?? <String, dynamic>{});
    }
    throw _buildException(response, 'Failed to update user');
  }

  Future<void> deleteUser(String id) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/user'),
      headers: _headers,
      body: jsonEncode({'id': id}),
    );
    if (response.statusCode != 200 && response.statusCode != 204) {
      throw _buildException(response, 'Failed to delete user');
    }
  }

  Future<List<Map<String, dynamic>>> getUserSessions(String userId) async {
    final primary = await http.get(
      Uri.parse('$baseUrl/users/$userId/sessions'),
      headers: _headers,
    );

    if (primary.statusCode == 200) {
      final data = _parseBody(primary) as List? ?? <dynamic>[];
      return data.cast<Map<String, dynamic>>();
    }

    final fallback = await http.get(
      Uri.parse('$baseUrl/user/$userId/sessions'),
      headers: _headers,
    );

    if (fallback.statusCode == 200) {
      final data = _parseBody(fallback) as List? ?? <dynamic>[];
      return data.cast<Map<String, dynamic>>();
    }

    throw _buildException(fallback, 'Failed to load sessions');
  }
}
