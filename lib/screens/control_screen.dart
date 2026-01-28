import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../providers/robot_control_provider.dart';
import '../widgets/joystick_widget.dart';

class ControlScreen extends StatefulWidget {
  const ControlScreen({super.key});

  @override
  State<ControlScreen> createState() => _ControlScreenState();
}

class _ControlScreenState extends State<ControlScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Robot Control'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/home');
            }
          },
        ),
      ),
      body: Consumer<RobotControlProvider>(
        builder: (context, robotProvider, child) {
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // Connection Status Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        Icon(
                          robotProvider.isConnected
                              ? Icons.check_circle
                              : Icons.error,
                          color: robotProvider.isConnected
                              ? Colors.green
                              : Colors.red,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          robotProvider.isConnected
                              ? 'Robot Connected'
                              : 'Robot Disconnected',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const Spacer(),
                        ElevatedButton(
                          onPressed: () {
                            if (robotProvider.isConnected) {
                              robotProvider.disconnect();
                            } else {
                              robotProvider.connect();
                            }
                          },
                          child: Text(
                            robotProvider.isConnected ? 'Disconnect' : 'Connect',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),

                // Mode Switch Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Control Mode',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            Switch(
                              value: robotProvider.currentMode == RobotMode.automatic,
                              onChanged: (value) {
                                robotProvider.switchMode(
                                  value ? RobotMode.automatic : RobotMode.manual,
                                );
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Manual',
                              style: TextStyle(
                                color: robotProvider.currentMode == RobotMode.manual
                                    ? Theme.of(context).colorScheme.primary
                                    : Colors.grey,
                                fontWeight: robotProvider.currentMode == RobotMode.manual
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                            Text(
                              'Automatic',
                              style: TextStyle(
                                color: robotProvider.currentMode == RobotMode.automatic
                                    ? Theme.of(context).colorScheme.primary
                                    : Colors.grey,
                                fontWeight: robotProvider.currentMode == RobotMode.automatic
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Speed Control Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Speed',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            Text(
                              '${robotProvider.speed.round()}%',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                        Slider(
                          value: robotProvider.speed,
                          min: 0,
                          max: 100,
                          divisions: 10,
                          onChanged: (value) {
                            robotProvider.updateSpeed(value);
                          },
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Joystick Control (only show in manual mode)
                if (robotProvider.currentMode == RobotMode.manual)
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          'Manual Control',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 16),
                        Expanded(
                          child: JoystickWidget(
                            onChanged: (x, y) {
                              robotProvider.updateJoystick(x, y);
                            },
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  // Automatic mode display
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.auto_mode,
                          size: 100,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Automatic Mode',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Robot is running in automatic mode',
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Colors.grey,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}