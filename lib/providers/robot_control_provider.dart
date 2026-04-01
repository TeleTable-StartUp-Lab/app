import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../services/api_service.dart';

enum RobotMode { manual, automatic }

class RobotNotificationItem {
  final String id;
  final String priority;
  final String message;
  final DateTime receivedAt;

  RobotNotificationItem({
    required this.id,
    required this.priority,
    required this.message,
    required this.receivedAt,
  });

  factory RobotNotificationItem.fromJson(Map<String, dynamic> json) {
    final receivedRaw = (json['receivedAt'] ?? json['received_at']) as String?;
    return RobotNotificationItem(
      id: (json['id'] as String?) ?? '${DateTime.now().millisecondsSinceEpoch}',
      priority: ((json['priority'] as String?) ?? 'INFO').toUpperCase(),
      message: (json['message'] as String?) ?? '',
      receivedAt: DateTime.tryParse(receivedRaw ?? '') ?? DateTime.now(),
    );
  }
}

class RobotToastItem {
  final String toastId;
  final String priority;
  final String message;
  final DateTime receivedAt;
  final int durationMs;

  const RobotToastItem({
    required this.toastId,
    required this.priority,
    required this.message,
    required this.receivedAt,
    this.durationMs = 5000,
  });
}

class RobotStatusData {
  final String systemHealth;
  final int batteryLevel;
  final String driveMode;
  final String cargoStatus;
  final String position;
  final Map<String, dynamic>? lastRoute;
  final String? manualLockHolderName;
  final bool robotConnected;
  final List<String> nodes;

  const RobotStatusData({
    this.systemHealth = 'UNKNOWN',
    this.batteryLevel = 0,
    this.driveMode = 'UNKNOWN',
    this.cargoStatus = 'UNKNOWN',
    this.position = 'UNKNOWN',
    this.lastRoute,
    this.manualLockHolderName,
    this.robotConnected = false,
    this.nodes = const [],
  });

  RobotStatusData copyWith({
    String? systemHealth,
    int? batteryLevel,
    String? driveMode,
    String? cargoStatus,
    String? position,
    Map<String, dynamic>? lastRoute,
    String? manualLockHolderName,
    bool? robotConnected,
    List<String>? nodes,
  }) {
    return RobotStatusData(
      systemHealth: systemHealth ?? this.systemHealth,
      batteryLevel: batteryLevel ?? this.batteryLevel,
      driveMode: driveMode ?? this.driveMode,
      cargoStatus: cargoStatus ?? this.cargoStatus,
      position: position ?? this.position,
      lastRoute: lastRoute ?? this.lastRoute,
      manualLockHolderName: manualLockHolderName ?? this.manualLockHolderName,
      robotConnected: robotConnected ?? this.robotConnected,
      nodes: nodes ?? this.nodes,
    );
  }

  factory RobotStatusData.fromJson(Map<String, dynamic> json) {
    final nodesRaw = json['nodes'];
    return RobotStatusData(
      systemHealth: (json['systemHealth'] ?? json['system_health'] ?? 'UNKNOWN') as String,
      batteryLevel: (json['batteryLevel'] ?? json['battery_level'] ?? 0) as int,
      driveMode: (json['driveMode'] ?? json['drive_mode'] ?? 'UNKNOWN') as String,
      cargoStatus: (json['cargoStatus'] ?? json['cargo_status'] ?? 'UNKNOWN') as String,
      position: (json['position'] ?? 'UNKNOWN') as String,
      lastRoute: (json['lastRoute'] ?? json['last_route']) as Map<String, dynamic>?,
      manualLockHolderName:
          (json['manualLockHolderName'] ?? json['manual_lock_holder_name']) as String?,
      robotConnected: (json['robotConnected'] ?? json['robot_connected'] ?? false) as bool,
      nodes: nodesRaw is List ? nodesRaw.map((n) => n.toString()).toList() : const [],
    );
  }
}

class RobotControlProvider with ChangeNotifier {
  final ApiService _apiService;

  WebSocketChannel? _manualWs;
  WebSocketChannel? _eventsWs;
  StreamSubscription? _manualSub;
  StreamSubscription? _eventsSub;

  String _manualWsStatus = 'disconnected';
  String _eventsWsStatus = 'disconnected';
  String _manualWsError = '';
  String _eventsWsError = '';
  String _lastMessage = '';
  bool _hasLock = false;
  bool _isDisposed = false;
  bool _initialized = false;
  RobotMode _currentMode = RobotMode.manual;
  double _speed = 50;
  double _joystickX = 0;
  double _joystickY = 0;

  RobotStatusData _statusData = const RobotStatusData();
  final List<RobotNotificationItem> _notifications = [];
  final List<RobotToastItem> _toasts = [];
  final Map<String, Timer> _toastTimers = {};

  DateTime? _lastNodesFetch;
  final _nodesFetchThrottle = const Duration(seconds: 20);

  RobotControlProvider(this._apiService);

  String get manualWsStatus => _manualWsStatus;
  String get eventsWsStatus => _eventsWsStatus;
  String get manualWsError => _manualWsError;
  String get eventsWsError => _eventsWsError;
  String get lastMessage => _lastMessage;
  bool get hasLock => _hasLock;
  RobotMode get currentMode => _currentMode;
  double get speed => _speed;
  double get joystickX => _joystickX;
  double get joystickY => _joystickY;
  bool get isConnected => _manualWsStatus == 'connected';

  RobotStatusData get statusData => _statusData;
  List<String> get nodes => _statusData.nodes;
  List<RobotNotificationItem> get notifications => List.unmodifiable(_notifications);
  List<RobotToastItem> get toasts => List.unmodifiable(_toasts);

  String _toWsBaseUrl() {
    return ApiService.baseUrl.replaceFirst(RegExp(r'^http'), 'ws');
  }

  String? _tokenFromService() {
    return _apiService.token;
  }

  Future<void> initialize() async {
    if (_initialized) {
      if (_eventsWsStatus != 'connected' && _eventsWsStatus != 'connecting') {
        connectEventsWs();
      }
      return;
    }
    _initialized = true;
    await loadNotificationHistory();
    connectEventsWs();
  }

  Future<void> loadNotificationHistory() async {
    try {
      final data = await _apiService.getRobotNotifications(limit: 500, offset: 0);
      _notifications
        ..clear()
        ..addAll(data.map(RobotNotificationItem.fromJson));
      _safeNotify();
    } catch (_) {
      // Keep UI usable even if history call fails.
    }
  }

  void connectEventsWs() {
    if (_eventsWsStatus == 'connected' || _eventsWsStatus == 'connecting') {
      return;
    }

    final token = _tokenFromService();
    if (token == null || token.isEmpty) {
      _eventsWsStatus = 'error';
      _eventsWsError = 'Not logged in';
      _safeNotify();
      return;
    }

    disconnectEventsWs();

    _eventsWsStatus = 'connecting';
    _eventsWsError = '';
    _safeNotify();

    try {
      final wsUrl = '${_toWsBaseUrl()}/ws/robot/events?token=$token';
      _eventsWs = WebSocketChannel.connect(Uri.parse(wsUrl));
      _eventsWsStatus = 'connected';
      _safeNotify();

      _eventsSub = _eventsWs!.stream.listen(
        (message) {
          _handleWsMessage(message);
        },
        onError: (_) {
          _eventsWsStatus = 'error';
          _eventsWsError = 'WebSocket error';
          _safeNotify();
        },
        onDone: () {
          _eventsWsStatus = 'disconnected';
          _safeNotify();
        },
      );
    } catch (_) {
      _eventsWsStatus = 'error';
      _eventsWsError = 'Failed to connect';
      _safeNotify();
    }
  }

  void disconnectEventsWs() {
    _eventsSub?.cancel();
    _eventsSub = null;
    _eventsWs?.sink.close();
    _eventsWs = null;
    _eventsWsStatus = 'disconnected';
    _safeNotify();
  }

  Future<Map<String, dynamic>> acquireLock() async {
    final result = await _apiService.acquireDriveLock();
    _hasLock = result['status'] != 'error';
    _safeNotify();
    return result;
  }

  Future<Map<String, dynamic>> releaseLock() async {
    final result = await _apiService.releaseDriveLock();
    if (result['status'] != 'error') {
      _hasLock = false;
    }
    _safeNotify();
    return result;
  }

  void connectManualWs() {
    final token = _tokenFromService();
    if (token == null || token.isEmpty) {
      _manualWsStatus = 'error';
      _manualWsError = 'Not logged in';
      _safeNotify();
      return;
    }

    disconnectManualWs();

    _manualWsStatus = 'connecting';
    _manualWsError = '';
    _safeNotify();

    try {
      final wsUrl = '${_toWsBaseUrl()}/ws/drive/manual?token=$token';
      _manualWs = WebSocketChannel.connect(Uri.parse(wsUrl));
      _manualWsStatus = 'connected';
      _safeNotify();

      _manualSub = _manualWs!.stream.listen(
        (message) {
          _lastMessage = message.toString();
          _safeNotify();
        },
        onError: (_) {
          _manualWsStatus = 'error';
          _manualWsError = 'WebSocket error';
          _safeNotify();
        },
        onDone: () {
          _manualWsStatus = 'disconnected';
          _safeNotify();
        },
      );
    } catch (_) {
      _manualWsStatus = 'error';
      _manualWsError = 'Failed to connect';
      _safeNotify();
    }
  }

  void disconnectManualWs() {
    _manualSub?.cancel();
    _manualSub = null;
    _manualWs?.sink.close();
    _manualWs = null;
    _manualWsStatus = 'disconnected';
    _safeNotify();
  }

  bool sendCommand(Map<String, dynamic> command) {
    if (_manualWs == null || _manualWsStatus != 'connected') {
      return false;
    }

    try {
      _manualWs!.sink.add(jsonEncode(command));
      return true;
    } catch (_) {
      _manualWsStatus = 'error';
      _manualWsError = 'Failed to send command';
      _safeNotify();
      return false;
    }
  }

  Future<List<String>> getNodes() async {
    final now = DateTime.now();
    if (_lastNodesFetch != null && now.difference(_lastNodesFetch!) < _nodesFetchThrottle) {
      return nodes;
    }

    try {
      final nodes = await _apiService.getNodes();
      _statusData = _statusData.copyWith(nodes: nodes);
      _lastNodesFetch = now; // Update timestamp only on success
      _safeNotify();
      return nodes;
    } catch (e) {
      // Robot not yet connected, will retry later when robot is available
      if (kDebugMode) {
        print('Failed to get nodes: $e');
      }
      // Do not retry automatically here to avoid loops.
      // The UI should trigger retries (e.g., with a refresh button).
      return nodes; // Return existing nodes on failure
    }
  }

  Future<Map<String, dynamic>> selectRoute(String start, String destination) {
    return _apiService.selectRoute(start: start, destination: destination);
  }

  Future<Map<String, dynamic>> checkRobotConnection() {
    return _apiService.checkRobotConnection();
  }

  // Compatibility API used by legacy screens.
  void switchMode(RobotMode mode) {
    _currentMode = mode;
    _safeNotify();
  }

  void toggleMode() {
    _currentMode = _currentMode == RobotMode.manual ? RobotMode.automatic : RobotMode.manual;
    _safeNotify();
  }

  void updateSpeed(double value) {
    _speed = value.clamp(0, 100);
    _safeNotify();
  }

  void updateJoystick(double x, double y) {
    _joystickX = x;
    _joystickY = y;
    _safeNotify();
  }

  void connect() {
    connectManualWs();
  }

  void disconnect() {
    disconnectManualWs();
  }

  void resetSession() {
    disconnectManualWs();
    disconnectEventsWs();
    _initialized = false;
    _manualWsError = '';
    _eventsWsError = '';
    _lastMessage = '';
    _hasLock = false;
    _currentMode = RobotMode.manual;
    _speed = 50;
    _joystickX = 0;
    _joystickY = 0;
    _statusData = const RobotStatusData();
    _notifications.clear();
    for (final timer in _toastTimers.values) {
      timer.cancel();
    }
    _toastTimers.clear();
    _toasts.clear();
    _lastNodesFetch = null;
    _safeNotify();
  }

  void _handleWsMessage(dynamic message) {
    final raw = message.toString();
    _lastMessage = raw;

    try {
      final parsed = jsonDecode(raw) as Map<String, dynamic>;
      final event = parsed['event'] as String?;
      final data = parsed['data'];

      if (event == 'status_update' && data is Map<String, dynamic>) {
        _statusData = RobotStatusData.fromJson(data);
      } else if (event == 'robot_notification' && data is Map<String, dynamic>) {
        final item = RobotNotificationItem.fromJson(data);
        _notifications.removeWhere((n) => n.id == item.id);
        _notifications.insert(0, item);
        _pushToast(item);
      }
    } catch (_) {
      // Ignore parse errors and keep raw message as diagnostics.
    }

    _safeNotify();
  }

  void dismissToast(String toastId) {
    _toastTimers.remove(toastId)?.cancel();
    _toasts.removeWhere((t) => t.toastId == toastId);
    _safeNotify();
  }

  void _pushToast(RobotNotificationItem notification) {
    final toastId = '${notification.id}-${DateTime.now().millisecondsSinceEpoch}';
    final toast = RobotToastItem(
      toastId: toastId,
      priority: notification.priority,
      message: notification.message,
      receivedAt: notification.receivedAt,
      durationMs: 5000,
    );

    _toasts.insert(0, toast);
    if (_toasts.length > 5) {
      final removed = _toasts.removeLast();
      _toastTimers.remove(removed.toastId)?.cancel();
    }

    _toastTimers[toastId]?.cancel();
    _toastTimers[toastId] = Timer(Duration(milliseconds: toast.durationMs), () {
      dismissToast(toastId);
    });
  }

  void _safeNotify() {
    if (_isDisposed) {
      return;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    for (final timer in _toastTimers.values) {
      timer.cancel();
    }
    _toastTimers.clear();
    disconnectManualWs();
    disconnectEventsWs();
    super.dispose();
  }
}
