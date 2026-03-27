import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/robot_control_provider.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _manualStepController = TextEditingController(text: '0.5');
  final _beepHzController = TextEditingController(text: '880');
  final _beepMsController = TextEditingController(text: '150');

  String _startNode = '';
  String _destinationNode = '';
  double _volume = 0.3;
  double _brightness = 40;
  bool _ledEnabled = true;
  Color _ledColor = const Color(0xFFFFB450);
  Timer? _clearFeedbackTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final robot = context.read<RobotControlProvider>();
      await robot.initialize();
      unawaited(robot.getNodes());
    });
  }

  @override
  void dispose() {
    _manualStepController.dispose();
    _beepHzController.dispose();
    _beepMsController.dispose();
    _clearFeedbackTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final robot = context.watch<RobotControlProvider>();
    final status = robot.statusData;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            SvgPicture.asset(
              'assets/branding/favicon.svg',
              width: 24,
              height: 24,
            ),
            const SizedBox(width: 8),
            RichText(
              text: TextSpan(
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                children: [
                  const TextSpan(text: 'Tele', style: TextStyle(color: Colors.white)),
                  TextSpan(
                    text: 'Table',
                    style: TextStyle(color: Theme.of(context).colorScheme.primary),
                  ),
                  const TextSpan(text: ' Dashboard', style: TextStyle(color: Colors.white)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Notifications',
            onPressed: () => _openNotifications(context, robot),
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.notifications_outlined),
                if (robot.notifications.isNotEmpty)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      width: 9,
                      height: 9,
                      decoration: const BoxDecoration(
                        color: Colors.redAccent,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Logout',
            onPressed: () async {
              await auth.logout();
              if (context.mounted) {
                context.go('/login');
              }
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await robot.getNodes();
          await robot.loadNotificationHistory();
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _TelemetryCard(
              health: status.systemHealth,
              batteryLevel: status.batteryLevel,
              driveMode: status.driveMode,
              cargoStatus: status.cargoStatus,
              position: status.position,
              robotConnected: status.robotConnected,
              eventsWsStatus: robot.eventsWsStatus,
              manualLockHolderName: status.manualLockHolderName,
              lastRoute: status.lastRoute,
            ),
            const SizedBox(height: 16),
            if (!auth.canOperate)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Read-only access: manual and route controls are disabled for Viewer accounts.',
                  ),
                ),
              ),
            if (auth.canOperate) ...[
              _buildManualControlCard(robot),
              const SizedBox(height: 16),
              _buildAutoControlCard(auth, robot),
              const SizedBox(height: 16),
              if (auth.isAdmin) _buildPeripheralCard(robot),
              if (auth.isAdmin) const SizedBox(height: 16),
            ],
            if (auth.isAdmin) _buildAdminActions(context),
          ],
        ),
      ),
    );
  }

  Widget _buildManualControlCard(RobotControlProvider robot) {
    final isConnected = robot.manualWsStatus == 'connected';
    final step = double.tryParse(_manualStepController.text) ?? 0.5;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.sports_esports),
                const SizedBox(width: 8),
                const Text('Manual Control', style: TextStyle(fontWeight: FontWeight.bold)),
                const Spacer(),
                _StatusChip(label: 'WS: ${robot.manualWsStatus}'),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: isConnected
                        ? null
                        : () async {
                            try {
                              final result = await robot.acquireLock();
                              robot.connectManualWs();
                              _setFeedback(result['message']?.toString() ?? 'Lock acquired');
                            } catch (e) {
                              _setFeedback('Failed to acquire lock: $e', isError: true);
                            }
                          },
                    icon: const Icon(Icons.link),
                    label: const Text('Connect'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      robot.disconnectManualWs();
                      try {
                        final result = await robot.releaseLock();
                        _setFeedback(result['message']?.toString() ?? 'Lock released');
                      } catch (e) {
                        _setFeedback('Failed to release lock: $e', isError: true);
                      }
                    },
                    icon: const Icon(Icons.power_settings_new),
                    label: const Text('Disconnect'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _manualStepController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Linear speed step',
                helperText: 'Suggested: 0.2 to 1.0',
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _DriveButton(
                  icon: Icons.arrow_upward,
                  onPressed: isConnected
                      ? () => _sendDrive(robot, linear: step, angular: 0)
                      : null,
                ),
                _DriveButton(
                  icon: Icons.arrow_back,
                  onPressed: isConnected
                      ? () => _sendDrive(robot, linear: 0, angular: step)
                      : null,
                ),
                _DriveButton(
                  icon: Icons.stop,
                  onPressed: isConnected ? () => _sendDrive(robot, linear: 0, angular: 0) : null,
                ),
                _DriveButton(
                  icon: Icons.arrow_forward,
                  onPressed: isConnected
                      ? () => _sendDrive(robot, linear: 0, angular: -step)
                      : null,
                ),
                _DriveButton(
                  icon: Icons.arrow_downward,
                  onPressed: isConnected
                      ? () => _sendDrive(robot, linear: -step, angular: 0)
                      : null,
                ),
              ],
            ),
            if (robot.manualWsError.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(robot.manualWsError, style: const TextStyle(color: Colors.redAccent)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAutoControlCard(AuthProvider auth, RobotControlProvider robot) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.route),
                const SizedBox(width: 8),
                const Text('Autonomous Navigation', style: TextStyle(fontWeight: FontWeight.bold)),
                const Spacer(),
                IconButton(
                  onPressed: () => robot.getNodes(),
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _startNode.isEmpty ? null : _startNode,
              hint: const Text('Start node'),
              items: robot.nodes
                  .map((node) => DropdownMenuItem(value: node, child: Text(node)))
                  .toList(),
              onChanged: (value) => setState(() => _startNode = value ?? ''),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _destinationNode.isEmpty ? null : _destinationNode,
              hint: const Text('Destination node'),
              items: robot.nodes
                  .map((node) => DropdownMenuItem(value: node, child: Text(node)))
                  .toList(),
              onChanged: (value) => setState(() => _destinationNode = value ?? ''),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  onPressed: (_startNode.isEmpty || _destinationNode.isEmpty)
                      ? null
                      : () async {
                          try {
                            final response = await robot.selectRoute(_startNode, _destinationNode);
                            _setFeedback(response['message']?.toString() ?? 'Route queued');
                          } catch (e) {
                            _setFeedback('Route selection failed: $e', isError: true);
                          }
                        },
                  icon: const Icon(Icons.send),
                  label: const Text('Select Route (HTTP)'),
                ),
                if (auth.isAdmin)
                  OutlinedButton.icon(
                    onPressed: (_startNode.isEmpty || _destinationNode.isEmpty)
                        ? null
                        : () {
                            final ok = robot.sendCommand({
                              'command': 'NAVIGATE',
                              'start': _startNode,
                              'destination': _destinationNode,
                            });
                            if (!ok) {
                              _setFeedback('WebSocket not connected', isError: true);
                              return;
                            }
                            _setFeedback('Navigate command sent');
                          },
                    icon: const Icon(Icons.navigation),
                    label: const Text('Navigate (WS)'),
                  ),
                if (auth.isAdmin)
                  OutlinedButton.icon(
                    onPressed: () {
                      final ok = robot.sendCommand({'command': 'CANCEL'});
                      if (!ok) {
                        _setFeedback('WebSocket not connected', isError: true);
                        return;
                      }
                      _setFeedback('Cancel command sent');
                    },
                    icon: const Icon(Icons.cancel),
                    label: const Text('Cancel (WS)'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPeripheralCard(RobotControlProvider robot) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.tune),
                SizedBox(width: 8),
                Text('Peripherals', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              title: const Text('LED Enabled'),
              value: _ledEnabled,
              onChanged: (value) => setState(() => _ledEnabled = value),
              contentPadding: EdgeInsets.zero,
            ),
            const Text('LED Color'),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: [
                _ColorDot(
                  color: Colors.redAccent,
                  selected: _ledColor == Colors.redAccent,
                  onTap: () => setState(() => _ledColor = Colors.redAccent),
                ),
                _ColorDot(
                  color: Colors.amber,
                  selected: _ledColor == Colors.amber,
                  onTap: () => setState(() => _ledColor = Colors.amber),
                ),
                _ColorDot(
                  color: Colors.blueAccent,
                  selected: _ledColor == Colors.blueAccent,
                  onTap: () => setState(() => _ledColor = Colors.blueAccent),
                ),
                _ColorDot(
                  color: Colors.greenAccent,
                  selected: _ledColor == Colors.greenAccent,
                  onTap: () => setState(() => _ledColor = Colors.greenAccent),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Slider(
              value: _brightness,
              min: 0,
              max: 100,
              divisions: 100,
              label: '${_brightness.round()}%',
              onChanged: (value) => setState(() => _brightness = value),
            ),
            OutlinedButton(
              onPressed: () {
                final ok = robot.sendCommand({
                  'command': 'LED',
                  'enabled': _ledEnabled,
                  'r': _ledColor.red,
                  'g': _ledColor.green,
                  'b': _ledColor.blue,
                  'brightness': _brightness.round(),
                });
                _setFeedback(ok ? 'LED command sent' : 'WebSocket not connected', isError: !ok);
              },
              child: const Text('Apply LED'),
            ),
            const SizedBox(height: 12),
            const Text('Audio Volume'),
            Slider(
              value: _volume,
              min: 0,
              max: 1,
              divisions: 20,
              label: '${(_volume * 100).round()}%',
              onChanged: (value) => setState(() => _volume = value),
            ),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton(
                  onPressed: () {
                    final ok = robot.sendCommand({
                      'command': 'AUDIO_VOLUME',
                      'value': _volume,
                    });
                    _setFeedback(
                      ok ? 'Volume command sent' : 'WebSocket not connected',
                      isError: !ok,
                    );
                  },
                  child: const Text('Set Volume'),
                ),
                SizedBox(
                  width: 110,
                  child: TextField(
                    controller: _beepHzController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Hz'),
                  ),
                ),
                SizedBox(
                  width: 110,
                  child: TextField(
                    controller: _beepMsController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'ms'),
                  ),
                ),
                OutlinedButton(
                  onPressed: () {
                    final hz = int.tryParse(_beepHzController.text) ?? 880;
                    final ms = int.tryParse(_beepMsController.text) ?? 150;
                    final ok = robot.sendCommand({
                      'command': 'AUDIO_BEEP',
                      'hz': hz,
                      'ms': ms,
                    });
                    _setFeedback(ok ? 'Beep command sent' : 'WebSocket not connected', isError: !ok);
                  },
                  child: const Text('Play Beep'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdminActions(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ElevatedButton.icon(
              onPressed: () => context.push('/queue'),
              icon: const Icon(Icons.list_alt),
              label: const Text('Queue Control'),
            ),
            OutlinedButton.icon(
              onPressed: () => context.push('/admin'),
              icon: const Icon(Icons.admin_panel_settings),
              label: const Text('Admin Panel'),
            ),
          ],
        ),
      ),
    );
  }

  void _sendDrive(RobotControlProvider robot, {required double linear, required double angular}) {
    final ok = robot.sendCommand({
      'command': 'DRIVE_COMMAND',
      'linear_velocity': linear,
      'angular_velocity': angular,
    });

    if (!ok) {
      _setFeedback('WebSocket not connected', isError: true);
    }
  }

  void _setFeedback(String message, {bool isError = false}) {
    _clearFeedbackTimer?.cancel();
    _clearFeedbackTimer = Timer(const Duration(seconds: 4), () {
      if (!mounted) {
        return;
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  void _openNotifications(BuildContext context, RobotControlProvider robot) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Robot Notifications', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                SizedBox(
                  height: 420,
                  child: robot.notifications.isEmpty
                      ? const Center(child: Text('No notifications yet.'))
                      : ListView.separated(
                          itemCount: robot.notifications.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (ctx, index) {
                            final n = robot.notifications[index];
                            return ListTile(
                              leading: _priorityIcon(n.priority),
                              title: Text(n.message),
                              subtitle: Text(
                                '${n.priority} • ${n.receivedAt.toLocal()}',
                                style: const TextStyle(fontSize: 12),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _priorityIcon(String priority) {
    switch (priority) {
      case 'ERROR':
        return const Icon(Icons.error, color: Colors.redAccent);
      case 'WARN':
        return const Icon(Icons.warning_amber, color: Colors.amber);
      default:
        return const Icon(Icons.info, color: Colors.lightBlueAccent);
    }
  }
}

class _TelemetryCard extends StatelessWidget {
  final String health;
  final int batteryLevel;
  final String driveMode;
  final String cargoStatus;
  final String position;
  final bool robotConnected;
  final String eventsWsStatus;
  final String? manualLockHolderName;
  final Map<String, dynamic>? lastRoute;

  const _TelemetryCard({
    required this.health,
    required this.batteryLevel,
    required this.driveMode,
    required this.cargoStatus,
    required this.position,
    required this.robotConnected,
    required this.eventsWsStatus,
    required this.manualLockHolderName,
    required this.lastRoute,
  });

  @override
  Widget build(BuildContext context) {
    final start = (lastRoute?['startNode'] ?? lastRoute?['start_node'])?.toString() ?? '-';
    final end = (lastRoute?['endNode'] ?? lastRoute?['end_node'])?.toString() ?? '-';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.monitor_heart),
                const SizedBox(width: 8),
                const Text('Telemetry', style: TextStyle(fontWeight: FontWeight.bold)),
                const Spacer(),
                _StatusChip(label: 'WS: $eventsWsStatus'),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _StatTile(label: 'System', value: health),
                _StatTile(label: 'Battery', value: '$batteryLevel%'),
                _StatTile(label: 'Mode', value: driveMode),
                _StatTile(label: 'Cargo', value: cargoStatus),
                _StatTile(label: 'Position', value: position),
                _StatTile(label: 'Robot', value: robotConnected ? 'Connected' : 'Disconnected'),
                _StatTile(label: 'Lock Holder', value: manualLockHolderName ?? 'None'),
                _StatTile(label: 'Last Route', value: '$start -> $end'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;

  const _StatTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: Colors.white.withOpacity(0.03),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;

  const _StatusChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.blueGrey.withOpacity(0.2),
        border: Border.all(color: Colors.blueGrey),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 11),
      ),
    );
  }
}

class _DriveButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;

  const _DriveButton({required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 56,
      height: 56,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(padding: EdgeInsets.zero),
        child: Icon(icon),
      ),
    );
  }
}

class _ColorDot extends StatelessWidget {
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _ColorDot({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? Colors.white : Colors.transparent,
            width: 2,
          ),
        ),
      ),
    );
  }
}
