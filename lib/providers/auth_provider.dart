import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_service.dart';

class SavedUserSession {
  final String userId;
  final String? name;
  final String? email;
  final String role;
  final String token;
  final DateTime? createdAt;
  final DateTime? lastSignOn;
  final DateTime lastUsedAt;

  const SavedUserSession({
    required this.userId,
    required this.name,
    required this.email,
    required this.role,
    required this.token,
    required this.createdAt,
    required this.lastSignOn,
    required this.lastUsedAt,
  });

  SavedUserSession copyWith({
    String? userId,
    String? name,
    String? email,
    String? role,
    String? token,
    DateTime? createdAt,
    DateTime? lastSignOn,
    DateTime? lastUsedAt,
  }) {
    return SavedUserSession(
      userId: userId ?? this.userId,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      token: token ?? this.token,
      createdAt: createdAt ?? this.createdAt,
      lastSignOn: lastSignOn ?? this.lastSignOn,
      lastUsedAt: lastUsedAt ?? this.lastUsedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'name': name,
      'email': email,
      'role': role,
      'token': token,
      'createdAt': createdAt?.toIso8601String(),
      'lastSignOn': lastSignOn?.toIso8601String(),
      'lastUsedAt': lastUsedAt.toIso8601String(),
    };
  }

  factory SavedUserSession.fromJson(Map<String, dynamic> json) {
    return SavedUserSession(
      userId: (json['userId'] as String?) ?? '',
      name: json['name'] as String?,
      email: json['email'] as String?,
      role: (json['role'] as String?) ?? 'Viewer',
      token: (json['token'] as String?) ?? '',
      createdAt: _parseDate(json['createdAt']),
      lastSignOn: _parseDate(json['lastSignOn']),
      lastUsedAt: _parseDate(json['lastUsedAt']) ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value is! String || value.isEmpty) {
      return null;
    }
    return DateTime.tryParse(value);
  }
}

class AuthProvider with ChangeNotifier {
  static const String _savedUsersKey = 'saved_users';
  static const String _activeUserIdKey = 'active_user_id';

  final SharedPreferences _prefs;
  final ApiService _apiService;

  bool _isAuthenticated = false;
  String? _username;
  String? _email;
  String? _userId;
  String? _token;
  String _role = 'Viewer';
  DateTime? _createdAt;
  DateTime? _lastSignOn;
  String? _errorMessage;
  String? _activeUserId;
  List<SavedUserSession> _savedUsers = [];

  AuthProvider(this._prefs, this._apiService) {
    _loadAuthState();
  }

  bool get isAuthenticated => _isAuthenticated;
  String? get username => _username;
  String? get email => _email;
  String? get userId => _userId;
  String? get token => _token;
  String get role => _role;
  bool get isAdmin => _role == 'Admin';
  bool get canOperate => _role == 'Admin' || _role == 'Operator';
  DateTime? get createdAt => _createdAt;
  DateTime? get lastSignOn => _lastSignOn;
  String? get errorMessage => _errorMessage;
  List<SavedUserSession> get savedUsers => List.unmodifiable(_savedUsers);
  String? get activeUserId => _activeUserId;
  SavedUserSession? get activeSavedUser {
    if (_activeUserId == null) {
      return null;
    }
    for (final user in _savedUsers) {
      if (user.userId == _activeUserId) {
        return user;
      }
    }
    return null;
  }

  Future<void> _loadAuthState() async {
    _savedUsers = _readSavedUsers();
    _activeUserId = _prefs.getString(_activeUserIdKey);

    final candidates = _buildRestoreCandidates();
    for (final candidate in candidates) {
      final restored = await _restoreSavedSession(candidate);
      if (restored) {
        notifyListeners();
        return;
      }
    }

    await _clearActiveSession(persist: true);
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

      final token = await _apiService.login(
        email: email,
        password: password,
      );
      final userInfo = await _apiService.getMe();

      await _applyAuthenticatedSession(
        token: token,
        userInfo: userInfo,
      );

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
    _errorMessage = null;
    await _clearActiveSession(persist: true);
    notifyListeners();
  }

  Future<bool> switchToSavedUser(String userId) async {
    SavedUserSession? target;
    SavedUserSession? previous;

    for (final user in _savedUsers) {
      if (user.userId == userId) {
        target = user;
      }
      if (user.userId == _activeUserId) {
        previous = user;
      }
    }

    if (target == null) {
      _errorMessage = 'Saved account not found';
      notifyListeners();
      return false;
    }

    if (_isAuthenticated && target.userId == _activeUserId) {
      return true;
    }

    try {
      _errorMessage = null;
      await _apiService.setToken(target.token);
      final userInfo = await _apiService.getMe();

      await _applyAuthenticatedSession(
        token: target.token,
        userInfo: userInfo,
        preferredUserId: target.userId,
      );

      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Saved account switch failed: $e');
      await _removeSavedUserInternal(userId);
      _errorMessage = e.toString().replaceAll('Exception: ', '');

      if (previous != null && previous.userId != userId) {
        await _applySavedUserSnapshot(previous, persistActive: true);
      } else {
        await _clearActiveSession(persist: true);
      }

      notifyListeners();
      return false;
    }
  }

  Future<void> removeSavedUser(String userId) async {
    final removingActive = userId == _activeUserId;
    await _removeSavedUserInternal(userId);

    if (removingActive) {
      await _clearActiveSession(persist: true);
    }

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

      await _apiService.register(
        name: name,
        email: email,
        password: password,
      );

      return await login(email, password);
    } catch (e) {
      debugPrint('Register error: $e');
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> _applyAuthenticatedSession({
    required String token,
    required Map<String, dynamic> userInfo,
    String? preferredUserId,
  }) async {
    _token = token;
    _isAuthenticated = true;
    _applyUserInfo(userInfo);

    final resolvedUserId = (_userId == null || _userId!.isEmpty) ? preferredUserId : _userId;
    final session = SavedUserSession(
      userId: resolvedUserId ?? '',
      name: _username,
      email: _email,
      role: _role,
      token: token,
      createdAt: _createdAt,
      lastSignOn: _lastSignOn,
      lastUsedAt: DateTime.now(),
    );

    if (session.userId.isNotEmpty) {
      _upsertSavedUser(session);
      _activeUserId = session.userId;
      await _prefs.setString(_activeUserIdKey, session.userId);
      await _persistSavedUsers();
    }
  }

  Future<bool> _restoreSavedSession(SavedUserSession session) async {
    if (session.userId.isEmpty || session.token.isEmpty) {
      await _removeSavedUserInternal(session.userId);
      return false;
    }

    try {
      await _apiService.setToken(session.token);
      final userInfo = await _apiService.getMe();

      await _applyAuthenticatedSession(
        token: session.token,
        userInfo: userInfo,
        preferredUserId: session.userId,
      );

      return true;
    } catch (e) {
      debugPrint('Saved session invalid for ${session.email ?? session.userId}: $e');
      await _removeSavedUserInternal(session.userId);
      return false;
    }
  }

  Future<void> _applySavedUserSnapshot(
    SavedUserSession session, {
    required bool persistActive,
  }) async {
    _isAuthenticated = true;
    _token = session.token;
    _username = session.name;
    _email = session.email;
    _userId = session.userId;
    _role = session.role;
    _createdAt = session.createdAt;
    _lastSignOn = session.lastSignOn;
    _activeUserId = session.userId;
    await _apiService.setToken(session.token);

    if (persistActive) {
      await _prefs.setString(_activeUserIdKey, session.userId);
    }
  }

  Future<void> _clearActiveSession({required bool persist}) async {
    _isAuthenticated = false;
    _username = null;
    _email = null;
    _userId = null;
    _token = null;
    _role = 'Viewer';
    _createdAt = null;
    _lastSignOn = null;
    _activeUserId = null;

    await _apiService.clearToken();

    if (persist) {
      await _prefs.remove(_activeUserIdKey);
    }
  }

  List<SavedUserSession> _buildRestoreCandidates() {
    if (_savedUsers.isEmpty) {
      return const [];
    }

    final ordered = [..._savedUsers];
    ordered.sort((a, b) => b.lastUsedAt.compareTo(a.lastUsedAt));

    if (_activeUserId == null) {
      return ordered;
    }

    final activeMatches = <SavedUserSession>[];
    final rest = <SavedUserSession>[];
    for (final user in ordered) {
      if (user.userId == _activeUserId) {
        activeMatches.add(user);
      } else {
        rest.add(user);
      }
    }
    return [...activeMatches, ...rest];
  }

  List<SavedUserSession> _readSavedUsers() {
    final raw = _prefs.getString(_savedUsersKey);
    if (raw == null || raw.isEmpty) {
      return [];
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return [];
      }

      return decoded
          .whereType<Map<String, dynamic>>()
          .map(SavedUserSession.fromJson)
          .where((user) => user.userId.isNotEmpty && user.token.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _persistSavedUsers() async {
    final encoded = jsonEncode(_savedUsers.map((user) => user.toJson()).toList());
    await _prefs.setString(_savedUsersKey, encoded);
  }

  void _upsertSavedUser(SavedUserSession session) {
    _savedUsers = [
      session,
      for (final existing in _savedUsers)
        if (existing.userId != session.userId) existing,
    ];
    _savedUsers.sort((a, b) => b.lastUsedAt.compareTo(a.lastUsedAt));
  }

  Future<void> _removeSavedUserInternal(String userId) async {
    _savedUsers = _savedUsers.where((user) => user.userId != userId).toList();
    await _persistSavedUsers();
  }

  void _applyUserInfo(Map<String, dynamic> userInfo) {
    _username = userInfo['name'] as String?;
    _email = userInfo['email'] as String?;
    _userId = userInfo['id'] as String?;
    _role = (userInfo['role'] as String?) ?? 'Viewer';

    final createdAtRaw = userInfo['created_at'] as String?;
    final lastSignOnRaw = userInfo['last_sign_on'] as String?;
    _createdAt = createdAtRaw != null ? DateTime.tryParse(createdAtRaw) : null;
    _lastSignOn = lastSignOnRaw != null ? DateTime.tryParse(lastSignOnRaw) : null;
  }
}
