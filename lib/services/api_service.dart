import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  // Backend URL - IMPORTANT: 
  // - iOS Simulator: Use 'http://localhost:3003'
  // - Android Emulator: Use 'http://10.0.2.2:3003'
  // - Physical Device: Use your computer's IP (e.g., 'http://192.168.1.100:3003')
  static const String baseUrl = 'http://localhost:3003';
  
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
  
  // Auth endpoints
  
  /// Register a new user
  /// POST /register
  /// Body: { "name": string, "email": string, "password": string }
  /// Returns: { "id": uuid, "name": string, "email": string, "role": string }
  Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'name': name,
        'email': email,
        'password': password,
      }),
    );
    
    if (response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['error'] ?? 'Registration failed');
    }
  }
  
  /// Login with email and password
  /// POST /login
  /// Body: { "email": string, "password": string }
  /// Returns: { "token": string }
  Future<String> login({
    required String email,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
      }),
    );
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final token = data['token'] as String;
      setToken(token);
      return token;
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['error'] ?? 'Login failed');
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
      return jsonDecode(response.body);
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['error'] ?? 'Failed to get user info');
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
      final data = jsonDecode(response.body) as List;
      return data.cast<Map<String, dynamic>>();
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['error'] ?? 'Failed to get diary entries');
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
      return jsonDecode(response.body);
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['error'] ?? 'Failed to create diary entry');
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
      return jsonDecode(response.body);
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['error'] ?? 'Failed to update diary entry');
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
      final error = jsonDecode(response.body);
      throw Exception(error['error'] ?? 'Failed to delete diary entry');
    }
  }
  
  // Robot control endpoints (for future implementation)
  
  /// Get robot status
  /// GET /status
  /// Returns: Robot telemetry and status
  Future<Map<String, dynamic>> getRobotStatus() async {
    final response = await http.get(
      Uri.parse('$baseUrl/status'),
      headers: {'Content-Type': 'application/json'},
    );
    
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to get robot status');
    }
  }
  
  /// Get available nodes for navigation
  /// GET /nodes
  /// Returns: { "nodes": [string] }
  Future<List<String>> getNodes() async {
    final response = await http.get(
      Uri.parse('$baseUrl/nodes'),
      headers: _headers,
    );
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return (data['nodes'] as List).cast<String>();
    } else {
      return [];
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
      return jsonDecode(response.body);
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['message'] ?? 'Failed to select route');
    }
  }
}
