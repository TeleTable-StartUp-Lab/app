import 'dart:async';
import 'dart:convert';
import 'dart:io';

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

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(_tokenKey);
  }

  Future<void> setToken(String token) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  Future<void> clearToken() async {
    _token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }

  bool get isLoggedIn => _token != null;
  String? get token => _token;

  Map<String, String> get _headers {
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };

    if (_token != null) {
      headers['Authorization'] = 'Bearer $_token';
    }

    return headers;
  }

  Uri _uri(String path, [Map<String, dynamic>? queryParameters]) {
    final base = Uri.parse(baseUrl);
    return base.replace(
      path: path,
      queryParameters: queryParameters?.map(
        (key, value) => MapEntry(key, value?.toString()),
      ),
    );
  }

  dynamic _decodeJsonBody(http.Response response) {
    if (response.body.isEmpty) {
      return null;
    }
    return jsonDecode(response.body);
  }

  String _extractError(http.Response response, {String fallback = 'Request failed'}) {
    final data = _decodeJsonBody(response);
    if (data is Map<String, dynamic>) {
      if (data['error'] is String) {
        return data['error'] as String;
      }
      if (data['message'] is String) {
        return data['message'] as String;
      }
    }
    return fallback;
  }

  Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final response = await http.post(
      _uri('/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'name': name,
        'email': email,
        'password': password,
      }),
    );

    if (response.statusCode == 201) {
      return _decodeJsonBody(response) as Map<String, dynamic>;
    }

    throw Exception(_extractError(response, fallback: 'Registration failed'));
  }

  Future<String> login({
    required String email,
    required String password,
  }) async {
    final response = await http.post(
      _uri('/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
      }),
    );

    if (response.statusCode == 200) {
      final data = _decodeJsonBody(response) as Map<String, dynamic>;
      final token = data['token'] as String;
      await setToken(token);
      return token;
    }

    throw Exception(_extractError(response, fallback: 'Login failed'));
  }

  Future<Map<String, dynamic>> getMe() async {
    final response = await http.get(
      _uri('/me'),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      return _decodeJsonBody(response) as Map<String, dynamic>;
    }

    throw Exception(_extractError(response, fallback: 'Failed to get user info'));
  }

  // Admin user management
  Future<dynamic> getUser({String? id}) async {
    final response = await http.get(
      _uri('/user', id != null ? {'id': id} : null),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      return _decodeJsonBody(response);
    }

    throw Exception(_extractError(response, fallback: 'Failed to fetch user(s)'));
  }

  Future<Map<String, dynamic>> updateUser({
    required String id,
    String? name,
    String? email,
    String? role,
  }) async {
    final payload = <String, dynamic>{'id': id};
    if (name != null) {
      payload['name'] = name;
    }
    if (email != null) {
      payload['email'] = email;
    }
    if (role != null) {
      payload['role'] = role;
    }

    final response = await http.post(
      _uri('/user'),
      headers: _headers,
      body: jsonEncode(payload),
    );

    if (response.statusCode == 200) {
      return _decodeJsonBody(response) as Map<String, dynamic>;
    }

    throw Exception(_extractError(response, fallback: 'Failed to update user'));
  }

  Future<void> deleteUser(String id) async {
    final response = await http.delete(
      _uri('/user'),
      headers: _headers,
      body: jsonEncode({'id': id}),
    );

    if (response.statusCode == 204) {
      return;
    }

    throw Exception(_extractError(response, fallback: 'Failed to delete user'));
  }

  // Diary endpoints
  Future<List<Map<String, dynamic>>> getDiaryEntries({String? id}) async {
    final response = await http.get(
      _uri('/diary', id != null ? {'id': id} : null),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      final data = _decodeJsonBody(response);
      if (data is List) {
        return data.cast<Map<String, dynamic>>();
      }
      if (data is Map<String, dynamic>) {
        return [data];
      }
    }

    throw Exception(_extractError(response, fallback: 'Failed to get diary entries'));
  }

  Future<List<Map<String, dynamic>>> getAllDiaryEntries() async {
    final response = await http.get(
      _uri('/diary/all'),
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode == 200) {
      final data = _decodeJsonBody(response) as List;
      return data.cast<Map<String, dynamic>>();
    }

    throw Exception(_extractError(response, fallback: 'Failed to get all diary entries'));
  }

  Future<Map<String, dynamic>> createDiaryEntry({
    required int workingMinutes,
    required String text,
  }) async {
    final response = await http.post(
      _uri('/diary'),
      headers: _headers,
      body: jsonEncode({
        'working_minutes': workingMinutes,
        'text': text,
      }),
    );

    if (response.statusCode == 201) {
      return _decodeJsonBody(response) as Map<String, dynamic>;
    }

    throw Exception(_extractError(response, fallback: 'Failed to create diary entry'));
  }

  Future<Map<String, dynamic>> updateDiaryEntry({
    required String id,
    required int workingMinutes,
    required String text,
  }) async {
    final response = await http.post(
      _uri('/diary'),
      headers: _headers,
      body: jsonEncode({
        'id': id,
        'working_minutes': workingMinutes,
        'text': text,
      }),
    );

    if (response.statusCode == 200) {
      return _decodeJsonBody(response) as Map<String, dynamic>;
    }

    throw Exception(_extractError(response, fallback: 'Failed to update diary entry'));
  }

  Future<void> deleteDiaryEntry(String id) async {
    final response = await http.delete(
      _uri('/diary'),
      headers: _headers,
      body: jsonEncode({'id': id}),
    );

    if (response.statusCode == 204) {
      return;
    }

    throw Exception(_extractError(response, fallback: 'Failed to delete diary entry'));
  }

  // Robot HTTP endpoints
  Future<Map<String, dynamic>> getRobotStatus() async {
    final response = await http.get(
      _uri('/status'),
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode == 200) {
      return _decodeJsonBody(response) as Map<String, dynamic>;
    }

    throw Exception(_extractError(response, fallback: 'Failed to get robot status'));
  }

  Future<List<String>> getNodes() async {
    final response = await http.get(
      _uri('/nodes'),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      final data = _decodeJsonBody(response) as Map<String, dynamic>;
      return (data['nodes'] as List<dynamic>).cast<String>();
    }

    throw Exception(_extractError(response, fallback: 'Failed to get nodes'));
  }

  Future<List<Map<String, dynamic>>> getRoutes() async {
    final response = await http.get(
      _uri('/routes'),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      final data = _decodeJsonBody(response) as List;
      return data.cast<Map<String, dynamic>>();
    }

    throw Exception(_extractError(response, fallback: 'Failed to get routes'));
  }

  Future<Map<String, dynamic>> addRoute({
    required String start,
    required String destination,
  }) async {
    final response = await http.post(
      _uri('/routes'),
      headers: _headers,
      body: jsonEncode({
        'start': start,
        'destination': destination,
      }),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return _decodeJsonBody(response) as Map<String, dynamic>;
    }

    throw Exception(_extractError(response, fallback: 'Failed to add route'));
  }

  Future<void> deleteRoute(String id) async {
    final response = await http.delete(
      _uri('/routes/$id'),
      headers: _headers,
    );

    if (response.statusCode == 204 || response.statusCode == 200) {
      return;
    }

    throw Exception(_extractError(response, fallback: 'Failed to delete route'));
  }

  Future<Map<String, dynamic>> optimizeRoutes() async {
    final response = await http.post(
      _uri('/routes/optimize'),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      return _decodeJsonBody(response) as Map<String, dynamic>;
    }

    throw Exception(_extractError(response, fallback: 'Failed to optimize routes'));
  }

  Future<Map<String, dynamic>> selectRoute({
    required String start,
    required String destination,
  }) async {
    final response = await http.post(
      _uri('/routes/select'),
      headers: _headers,
      body: jsonEncode({
        'start': start,
        'destination': destination,
      }),
    );

    if (response.statusCode == 200) {
      return _decodeJsonBody(response) as Map<String, dynamic>;
    }

    throw Exception(_extractError(response, fallback: 'Failed to select route'));
  }

  Future<Map<String, dynamic>> acquireDriveLock() async {
    final response = await http.post(
      _uri('/drive/lock'),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      return _decodeJsonBody(response) as Map<String, dynamic>;
    }

    throw Exception(_extractError(response, fallback: 'Failed to acquire lock'));
  }

  Future<Map<String, dynamic>> releaseDriveLock() async {
    final response = await http.delete(
      _uri('/drive/lock'),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      return _decodeJsonBody(response) as Map<String, dynamic>;
    }

    throw Exception(_extractError(response, fallback: 'Failed to release lock'));
  }

  Future<Map<String, dynamic>> checkRobot() async {
    final response = await http.get(
      _uri('/robot/check'),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      return _decodeJsonBody(response) as Map<String, dynamic>;
    }

    throw Exception(_extractError(response, fallback: 'Failed to check robot'));
  }

  Future<WebSocket> connectRobotControlWebSocket() async {
    final wsUri = Uri.parse(baseUrl).replace(
      scheme: Uri.parse(baseUrl).scheme == 'https' ? 'wss' : 'ws',
      path: '/ws/robot/control',
    );
    return WebSocket.connect(wsUri.toString());
  }

  Future<WebSocket> connectManualDriveWebSocket() async {
    if (_token == null) {
      throw Exception('Authentication token is required');
    }

    final wsUri = Uri.parse(baseUrl).replace(
      scheme: Uri.parse(baseUrl).scheme == 'https' ? 'wss' : 'ws',
      path: '/ws/drive/manual',
      queryParameters: {'token': _token},
    );

    return WebSocket.connect(wsUri.toString());
  }

  Future<void> sendManualCommand(
    WebSocket socket,
    Map<String, dynamic> command,
  ) async {
    socket.add(jsonEncode(command));
  }
}
