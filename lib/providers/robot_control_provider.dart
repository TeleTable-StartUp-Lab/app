import 'package:flutter/foundation.dart';

enum RobotMode { manual, automatic }

class RobotControlProvider with ChangeNotifier {
  RobotMode _currentMode = RobotMode.manual;
  bool _isConnected = false;
  double _joystickX = 0.0;
  double _joystickY = 0.0;
  double _speed = 50.0;
  
  // Getters
  RobotMode get currentMode => _currentMode;
  bool get isConnected => _isConnected;
  double get joystickX => _joystickX;
  double get joystickY => _joystickY;
  double get speed => _speed;
  
  // Mode switching
  void switchMode(RobotMode mode) {
    if (_currentMode != mode) {
      _currentMode = mode;
      notifyListeners();
      // TODO: Send mode change command to robot
      _sendModeCommand(mode);
    }
  }
  
  void toggleMode() {
    switchMode(_currentMode == RobotMode.manual 
        ? RobotMode.automatic 
        : RobotMode.manual);
  }
  
  // Joystick control
  void updateJoystick(double x, double y) {
    _joystickX = x;
    _joystickY = y;
    notifyListeners();
    
    if (_currentMode == RobotMode.manual) {
      // TODO: Send joystick commands to robot
      _sendMovementCommand(x, y);
    }
  }
  
  // Speed control
  void updateSpeed(double newSpeed) {
    _speed = newSpeed.clamp(0.0, 100.0);
    notifyListeners();
    // TODO: Send speed command to robot
    _sendSpeedCommand(_speed);
  }
  
  // Connection management
  void connect() {
    // TODO: Implement actual robot connection
    _isConnected = true;
    notifyListeners();
  }
  
  void disconnect() {
    _isConnected = false;
    _joystickX = 0.0;
    _joystickY = 0.0;
    notifyListeners();
  }
  
  // Emergency stop
  void emergencyStop() {
    _joystickX = 0.0;
    _joystickY = 0.0;
    notifyListeners();
    // TODO: Send emergency stop command to robot
    _sendEmergencyStopCommand();
  }
  
  // Private methods for robot communication
  void _sendModeCommand(RobotMode mode) {
    debugPrint('Sending mode command: ${mode.name}');
    // TODO: Implement actual robot communication
  }
  
  void _sendMovementCommand(double x, double y) {
    debugPrint('Sending movement command: x=$x, y=$y');
    // TODO: Implement actual robot communication
  }
  
  void _sendSpeedCommand(double speed) {
    debugPrint('Sending speed command: $speed');
    // TODO: Implement actual robot communication
  }
  
  void _sendEmergencyStopCommand() {
    debugPrint('Sending emergency stop command');
    // TODO: Implement actual robot communication
  }
}