import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../services/api_service.dart';

enum RobotMode { manual, automatic }

class RobotControlProvider with ChangeNotifier {
  final ApiService _apiService;

  RobotControlProvider(this._apiService);

  RobotMode _currentMode = RobotMode.manual;
  bool _isConnected = false;
  double _joystickX = 0.0;
  double _joystickY = 0.0;
  double _speed = 50.0;
  String? _error;
  Map<String, dynamic>? _status;
  String? _manualLockMessage;

  WebSocket? _manualSocket;
  StreamSubscription<dynamic>? _manualSocketSubscription;

  RobotMode get currentMode => _currentMode;
  bool get isConnected => _isConnected;
  double get joystickX => _joystickX;
  double get joystickY => _joystickY;
  double get speed => _speed;
  String? get error => _error;
  Map<String, dynamic>? get status => _status;
  String? get manualLockMessage => _manualLockMessage;

  Future<void> switchMode(RobotMode mode) async {
    if (_currentMode == mode) {
      return;
    }

    _currentMode = mode;
    notifyListeners();
    await _sendModeCommand(mode);
  }

  Future<void> toggleMode() async {
    await switchMode(
      _currentMode == RobotMode.manual ? RobotMode.automatic : RobotMode.manual,
    );
  }

  Future<void> updateJoystick(double x, double y) async {
    _joystickX = x;
    _joystickY = y;
    notifyListeners();

    if (_currentMode == RobotMode.manual) {
      await _sendMovementCommand(x, y);
    }
  }

  Future<void> updateSpeed(double newSpeed) async {
    _speed = newSpeed.clamp(0.0, 100.0);
    notifyListeners();
  }

  Future<void> loadStatus() async {
    try {
      _error = null;
      _status = await _apiService.getRobotStatus();
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
    }
    notifyListeners();
  }

  Future<void> connect() async {
    try {
      _error = null;

      final lockResult = await _apiService.acquireDriveLock();
      _manualLockMessage = lockResult['message'] as String?;
      if (lockResult['status'] != 'success') {
        _isConnected = false;
        notifyListeners();
        return;
      }

      _manualSocket = await _apiService.connectManualDriveWebSocket();
      _manualSocketSubscription = _manualSocket!.listen(
        (_) {},
        onError: (_) {
          _isConnected = false;
          notifyListeners();
        },
        onDone: () {
          _isConnected = false;
          notifyListeners();
        },
      );

      _isConnected = true;
      notifyListeners();
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      _isConnected = false;
      notifyListeners();
    }
  }

  Future<void> disconnect() async {
    try {
      _error = null;

      if (_manualSocket != null) {
        await _manualSocket!.close();
      }
      await _manualSocketSubscription?.cancel();
      _manualSocket = null;
      _manualSocketSubscription = null;

      await _apiService.releaseDriveLock();
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
    }

    _isConnected = false;
    _joystickX = 0.0;
    _joystickY = 0.0;
    notifyListeners();
  }

  Future<void> emergencyStop() async {
    _joystickX = 0.0;
    _joystickY = 0.0;
    notifyListeners();
    await _sendEmergencyStopCommand();
  }

  Future<void> _sendModeCommand(RobotMode mode) async {
    if (_manualSocket == null) {
      return;
    }

    final command = {
      'command': 'SET_MODE',
      'mode': mode == RobotMode.manual ? 'MANUAL' : 'AUTONOMOUS',
    };

    await _apiService.sendManualCommand(_manualSocket!, command);
  }

  Future<void> _sendMovementCommand(double x, double y) async {
    if (_manualSocket == null) {
      return;
    }

    final speedScale = _speed / 100.0;
    final command = {
      'command': 'DRIVE_COMMAND',
      'linear_velocity': y * speedScale,
      'angular_velocity': x * speedScale,
    };

    await _apiService.sendManualCommand(_manualSocket!, command);
  }

  Future<void> _sendEmergencyStopCommand() async {
    if (_manualSocket == null) {
      return;
    }

    final command = {
      'command': 'DRIVE_COMMAND',
      'linear_velocity': 0.0,
      'angular_velocity': 0.0,
    };

    await _apiService.sendManualCommand(_manualSocket!, command);
  }

  @override
  void dispose() {
    unawaited(disconnect());
    super.dispose();
  }
}
