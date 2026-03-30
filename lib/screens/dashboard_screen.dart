import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/robot_control_provider.dart';
import '../widgets/joystick_widget.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _tabIndex = 0;
  String _startNode = '';
  String _destinationNode = '';
  double _volume = 0.3;
  double _brightness = 40;
  bool _ledEnabled = true;
  Color _ledColor = const Color(0xFFFFB450);
  Timer? _lastDriveThrottle;

  final _beepHzController = TextEditingController(text: '880');
  final _beepMsController = TextEditingController(text: '150');

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
    _beepHzController.dispose();
    _beepMsController.dispose();
    _lastDriveThrottle?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final robot = context.watch<RobotControlProvider>();
    final status = robot.statusData;

    final destinations = [
      const NavigationDestination(icon: Icon(Icons.dashboard_outlined), label: 'Overview'),
      const NavigationDestination(icon: Icon(Icons.gamepad_outlined), label: 'Drive'),
      const NavigationDestination(icon: Icon(Icons.route_outlined), label: 'Routes'),
      if (auth.isAdmin) const NavigationDestination(icon: Icon(Icons.tune), label: 'More'),
    ];

    final tabs = [
      _OverviewTab(status: status, eventsWsStatus: robot.eventsWsStatus),
      _DriveTab(
        canOperate: auth.canOperate,
        manualWsStatus: robot.manualWsStatus,
        manualWsError: robot.manualWsError,
        onConnect: () async {
          try {
            final result = await robot.acquireLock();
            robot.connectManualWs();
            if (!mounted) return;
            _showFeedback(result['message']?.toString() ?? 'Drive lock acquired');
          } catch (e) {
            if (!mounted) return;
            _showFeedback('Failed to acquire lock: $e', isError: true);
          }
        },
        onDisconnect: () async {
          robot.disconnectManualWs();
          try {
            final result = await robot.releaseLock();
            if (!mounted) return;
            _showFeedback(result['message']?.toString() ?? 'Drive lock released');
          } catch (e) {
            if (!mounted) return;
            _showFeedback('Failed to release lock: $e', isError: true);
          }
        },
        onJoystickChanged: (x, y) => _sendDriveFromJoystick(robot, x, y),
        onEmergencyStop: () {
          final ok = robot.sendCommand({
            'command': 'DRIVE_COMMAND',
            'linear_velocity': 0,
            'angular_velocity': 0,
          });
          if (!ok) {
            _showFeedback('Manual WebSocket is not connected', isError: true);
          }
        },
      ),
      _RoutesTab(
        canOperate: auth.canOperate,
        isAdmin: auth.isAdmin,
        nodes: robot.nodes,
        startNode: _startNode,
        destinationNode: _destinationNode,
        onStartChanged: (value) => setState(() => _startNode = value ?? ''),
        onDestinationChanged: (value) => setState(() => _destinationNode = value ?? ''),
        onRefreshNodes: () => robot.getNodes(),
        onSelectRoute: () async {
          if (_startNode.isEmpty || _destinationNode.isEmpty) return;
          try {
            final response = await robot.selectRoute(_startNode, _destinationNode);
            if (!mounted) return;
            _showFeedback(response['message']?.toString() ?? 'Route queued');
          } catch (e) {
            if (!mounted) return;
            _showFeedback('Failed to select route: $e', isError: true);
          }
        },
        onNavigateWs: () {
          final ok = robot.sendCommand({
            'command': 'NAVIGATE',
            'start': _startNode,
            'destination': _destinationNode,
          });
          _showFeedback(ok ? 'Navigate command sent' : 'Manual WebSocket not connected', isError: !ok);
        },
        onCancelWs: () {
          final ok = robot.sendCommand({'command': 'CANCEL'});
          _showFeedback(ok ? 'Cancel command sent' : 'Manual WebSocket not connected', isError: !ok);
        },
      ),
      if (auth.isAdmin)
        _MoreTab(
          isAdmin: auth.isAdmin,
          ledEnabled: _ledEnabled,
          brightness: _brightness,
          volume: _volume,
          ledColor: _ledColor,
          beepHzController: _beepHzController,
          beepMsController: _beepMsController,
          onLedEnabledChanged: (value) => setState(() => _ledEnabled = value),
          onBrightnessChanged: (value) => setState(() => _brightness = value),
          onVolumeChanged: (value) => setState(() => _volume = value),
          onLedColorChanged: (value) => setState(() => _ledColor = value),
          onApplyLed: () {
            final ok = robot.sendCommand({
              'command': 'LED',
              'enabled': _ledEnabled,
              'r': (_ledColor.red * 255).round().clamp(0, 255),
              'g': (_ledColor.green * 255).round().clamp(0, 255),
              'b': (_ledColor.blue * 255).round().clamp(0, 255),
              'brightness': _brightness.round(),
            });
            _showFeedback(ok ? 'LED command sent' : 'Manual WebSocket not connected', isError: !ok);
          },
          onApplyVolume: () {
            final ok = robot.sendCommand({
              'command': 'AUDIO_VOLUME',
              'value': _volume,
            });
            _showFeedback(ok ? 'Volume command sent' : 'Manual WebSocket not connected', isError: !ok);
          },
          onPlayBeep: () {
            final hz = int.tryParse(_beepHzController.text) ?? 880;
            final ms = int.tryParse(_beepMsController.text) ?? 150;
            final ok = robot.sendCommand({
              'command': 'AUDIO_BEEP',
              'hz': hz,
              'ms': ms,
            });
            _showFeedback(ok ? 'Beep command sent' : 'Manual WebSocket not connected', isError: !ok);
          },
        ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            SvgPicture.asset(
              'assets/branding/favicon.svg',
              width: 22,
              height: 22,
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
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'All alerts',
            onPressed: () => _openNotifications(context, robot),
            icon: const Icon(Icons.notifications_outlined),
          ),
          IconButton(
            tooltip: 'Diary',
            onPressed: () => context.push('/diary'),
            icon: const Icon(Icons.book_outlined),
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
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: () async {
              await robot.getNodes();
              await robot.loadNotificationHistory();
            },
            child: IndexedStack(
              index: _tabIndex,
              children: tabs,
            ),
          ),
          _ToastOverlay(
            toasts: robot.toasts,
            onDismiss: (toastId) => robot.dismissToast(toastId),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: (index) {
          setState(() {
            _tabIndex = index;
          });
        },
        destinations: destinations,
      ),
    );
  }

  void _sendDriveFromJoystick(RobotControlProvider robot, double x, double y) {
    if (robot.manualWsStatus != 'connected') {
      return;
    }

    if (_lastDriveThrottle?.isActive ?? false) {
      return;
    }

    final speedFactor = (robot.speed / 100).clamp(0.1, 1.0);
    final linear = y * speedFactor;
    final angular = -x * 2.0 * speedFactor;

    robot.sendCommand({
      'command': 'DRIVE_COMMAND',
      'linear_velocity': linear,
      'angular_velocity': angular,
    });

    _lastDriveThrottle = Timer(const Duration(milliseconds: 60), () {});
  }

  void _showFeedback(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  void _openNotifications(BuildContext context, RobotControlProvider robot) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Alerts'),
            ),
            body: robot.notifications.isEmpty
                ? const Center(child: Text('No alerts recorded yet.'))
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
          );
        },
      ),
    );
  }

  Widget _priorityIcon(String priority) {
    switch (priority) {
      case 'ERROR':
        return const Icon(Icons.error_outline, color: Colors.redAccent);
      case 'WARN':
        return const Icon(Icons.warning_amber_rounded, color: Colors.amber);
      default:
        return const Icon(Icons.info_outline, color: Colors.lightBlueAccent);
    }
  }
}

class _OverviewTab extends StatelessWidget {
  final RobotStatusData status;
  final String eventsWsStatus;

  const _OverviewTab({
    required this.status,
    required this.eventsWsStatus,
  });

  @override
  Widget build(BuildContext context) {
    final start = (status.lastRoute?['startNode'] ?? status.lastRoute?['start_node'])?.toString() ?? '-';
    final end = (status.lastRoute?['endNode'] ?? status.lastRoute?['end_node'])?.toString() ?? '-';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
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
                    _StatusChip(label: 'Events WS: $eventsWsStatus'),
                  ],
                ),
                const SizedBox(height: 12),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 2.4,
                  children: [
                    _StatTile(icon: Icons.health_and_safety_outlined, label: 'System Health', value: status.systemHealth),
                    _StatTile(icon: Icons.battery_charging_full, label: 'Battery', value: '${status.batteryLevel}%'),
                    _StatTile(icon: Icons.drive_eta_outlined, label: 'Drive Mode', value: status.driveMode),
                    _StatTile(icon: Icons.inventory_2_outlined, label: 'Cargo', value: status.cargoStatus),
                    _StatTile(icon: Icons.location_on_outlined, label: 'Position', value: status.position),
                    _StatTile(
                        icon: Icons.power_outlined,
                        label: 'Robot Connection',
                        value: status.robotConnected ? 'Connected' : 'Disconnected'),
                    _StatTile(icon: Icons.lock_open_outlined, label: 'Lock Holder', value: status.manualLockHolderName ?? 'None'),
                    _StatTile(icon: Icons.route_outlined, label: 'Last Route', value: '$start -> $end'),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _DriveTab extends StatelessWidget {
  final bool canOperate;
  final String manualWsStatus;
  final String manualWsError;
  final Future<void> Function() onConnect;
  final Future<void> Function() onDisconnect;
  final void Function(double x, double y) onJoystickChanged;
  final VoidCallback onEmergencyStop;

  const _DriveTab({
    required this.canOperate,
    required this.manualWsStatus,
    required this.manualWsError,
    required this.onConnect,
    required this.onDisconnect,
    required this.onJoystickChanged,
    required this.onEmergencyStop,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.gamepad),
                  const SizedBox(width: 8),
                  const Text('Manual Drive', style: TextStyle(fontWeight: FontWeight.bold)),
                  const Spacer(),
                  _StatusChip(label: 'Drive WS: $manualWsStatus'),
                ],
              ),
              const SizedBox(height: 12),
              if (!canOperate)
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Text('Viewer role has read-only access. Drive control is disabled.'),
                ),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: canOperate ? onConnect : null,
                      icon: const Icon(Icons.link),
                      label: const Text('Connect'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: canOperate ? onDisconnect : null,
                      icon: const Icon(Icons.power_settings_new),
                      label: const Text('Disconnect'),
                    ),
                  ),
                ],
              ),
              if (manualWsError.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(manualWsError, style: const TextStyle(color: Colors.redAccent)),
              ],
              const SizedBox(height: 20),
              Expanded(
                child: Center(
                  child: Opacity(
                    opacity: canOperate ? 1 : 0.5,
                    child: IgnorePointer(
                      ignoring: !canOperate,
                      child: JoystickWidget(
                        size: 260,
                        onChanged: onJoystickChanged,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Center(
                child: OutlinedButton.icon(
                  onPressed: canOperate ? onEmergencyStop : null,
                  icon: const Icon(Icons.stop_circle_outlined),
                  label: const Text('Emergency Stop'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoutesTab extends StatelessWidget {
  final bool canOperate;
  final bool isAdmin;
  final List<String> nodes;
  final String startNode;
  final String destinationNode;
  final ValueChanged<String?> onStartChanged;
  final ValueChanged<String?> onDestinationChanged;
  final Future<void> Function() onRefreshNodes;
  final Future<void> Function() onSelectRoute;
  final VoidCallback onNavigateWs;
  final VoidCallback onCancelWs;

  const _RoutesTab({
    required this.canOperate,
    required this.isAdmin,
    required this.nodes,
    required this.startNode,
    required this.destinationNode,
    required this.onStartChanged,
    required this.onDestinationChanged,
    required this.onRefreshNodes,
    required this.onSelectRoute,
    required this.onNavigateWs,
    required this.onCancelWs,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.route),
                    const SizedBox(width: 8),
                    const Text('Route Selection', style: TextStyle(fontWeight: FontWeight.bold)),
                    const Spacer(),
                    IconButton(onPressed: onRefreshNodes, icon: const Icon(Icons.refresh)),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: startNode.isEmpty ? null : startNode,
                  hint: const Text('Start node'),
                  items: nodes.map((node) => DropdownMenuItem(value: node, child: Text(node))).toList(),
                  onChanged: onStartChanged,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: destinationNode.isEmpty ? null : destinationNode,
                  hint: const Text('Destination node'),
                  items: nodes.map((node) => DropdownMenuItem(value: node, child: Text(node))).toList(),
                  onChanged: onDestinationChanged,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ElevatedButton.icon(
                      onPressed: canOperate && startNode.isNotEmpty && destinationNode.isNotEmpty
                          ? onSelectRoute
                          : null,
                      icon: const Icon(Icons.send),
                      label: const Text('Queue Route (HTTP)'),
                    ),
                    if (isAdmin)
                      OutlinedButton.icon(
                        onPressed: () => context.push('/queue'),
                        icon: const Icon(Icons.list_alt),
                        label: const Text('Queue Control'),
                      ),
                    if (isAdmin)
                      OutlinedButton.icon(
                        onPressed: startNode.isNotEmpty && destinationNode.isNotEmpty ? onNavigateWs : null,
                        icon: const Icon(Icons.navigation_outlined),
                        label: const Text('Navigate (WS)'),
                      ),
                    if (isAdmin)
                      OutlinedButton.icon(
                        onPressed: onCancelWs,
                        icon: const Icon(Icons.cancel_outlined),
                        label: const Text('Cancel (WS)'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MoreTab extends StatelessWidget {
  final bool isAdmin;
  final bool ledEnabled;
  final double brightness;
  final double volume;
  final Color ledColor;
  final TextEditingController beepHzController;
  final TextEditingController beepMsController;
  final ValueChanged<bool> onLedEnabledChanged;
  final ValueChanged<double> onBrightnessChanged;
  final ValueChanged<double> onVolumeChanged;
  final ValueChanged<Color> onLedColorChanged;
  final VoidCallback onApplyLed;
  final VoidCallback onApplyVolume;
  final VoidCallback onPlayBeep;

  const _MoreTab({
    required this.isAdmin,
    required this.ledEnabled,
    required this.brightness,
    required this.volume,
    required this.ledColor,
    required this.beepHzController,
    required this.beepMsController,
    required this.onLedEnabledChanged,
    required this.onBrightnessChanged,
    required this.onVolumeChanged,
    required this.onLedColorChanged,
    required this.onApplyLed,
    required this.onApplyVolume,
    required this.onPlayBeep,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (isAdmin)
                    OutlinedButton.icon(
                      onPressed: () => context.push('/admin'),
                      icon: const Icon(Icons.admin_panel_settings),
                      label: const Text('Admin Panel'),
                    ),
                ],
              ),
            ),
          ),
        ),
        if (isAdmin) ...[
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Peripherals', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    value: ledEnabled,
                    onChanged: onLedEnabledChanged,
                    title: const Text('LED enabled'),
                    contentPadding: EdgeInsets.zero,
                  ),
                  Wrap(
                    spacing: 8,
                    children: [
                      _ColorDot(
                        color: Colors.redAccent,
                        selected: ledColor == Colors.redAccent,
                        onTap: () => onLedColorChanged(Colors.redAccent),
                      ),
                      _ColorDot(
                        color: Colors.amber,
                        selected: ledColor == Colors.amber,
                        onTap: () => onLedColorChanged(Colors.amber),
                      ),
                      _ColorDot(
                        color: Colors.blueAccent,
                        selected: ledColor == Colors.blueAccent,
                        onTap: () => onLedColorChanged(Colors.blueAccent),
                      ),
                      _ColorDot(
                        color: Colors.greenAccent,
                        selected: ledColor == Colors.greenAccent,
                        onTap: () => onLedColorChanged(Colors.greenAccent),
                      ),
                    ],
                  ),
                  Slider(
                    value: brightness,
                    min: 0,
                    max: 100,
                    divisions: 100,
                    label: '${brightness.round()}%',
                    onChanged: onBrightnessChanged,
                  ),
                  OutlinedButton(onPressed: onApplyLed, child: const Text('Apply LED')),
                  const SizedBox(height: 8),
                  const Text('Audio'),
                  Slider(
                    value: volume,
                    min: 0,
                    max: 1,
                    divisions: 20,
                    label: '${(volume * 100).round()}%',
                    onChanged: onVolumeChanged,
                  ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton(onPressed: onApplyVolume, child: const Text('Set Volume')),
                      SizedBox(
                        width: 110,
                        child: TextField(
                          controller: beepHzController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Hz'),
                        ),
                      ),
                      SizedBox(
                        width: 110,
                        child: TextField(
                          controller: beepMsController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'ms'),
                        ),
                      ),
                      OutlinedButton(onPressed: onPlayBeep, child: const Text('Play Beep')),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _ToastOverlay extends StatelessWidget {
  final List<RobotToastItem> toasts;
  final ValueChanged<String> onDismiss;

  const _ToastOverlay({
    required this.toasts,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 12,
      right: 12,
      child: IgnorePointer(
        ignoring: false,
        child: SizedBox(
          width: 340,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: toasts
                .map(
                  (toast) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Material(
                      elevation: 8,
                      borderRadius: BorderRadius.circular(10),
                      color: _toastColor(toast.priority),
                      child: InkWell(
                        onTap: () => onDismiss(toast.toastId),
                        borderRadius: BorderRadius.circular(10),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          child: Row(
                            children: [
                              Icon(_toastIcon(toast.priority), color: Colors.white),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  toast.message,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(Icons.close, size: 18, color: Colors.white70),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
  }

  Color _toastColor(String priority) {
    switch (priority) {
      case 'ERROR':
        return Colors.redAccent;
      case 'WARN':
        return Colors.orangeAccent.shade700;
      default:
        return Colors.lightBlueAccent.shade700;
    }
  }

  IconData _toastIcon(String priority) {
    switch (priority) {
      case 'ERROR':
        return Icons.error_outline;
      case 'WARN':
        return Icons.warning_amber_rounded;
      default:
        return Icons.info_outline;
    }
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatTile({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Theme.of(context).colorScheme.surface.withAlpha(150),
        border: Border.all(color: Theme.of(context).colorScheme.surfaceVariant.withAlpha(100)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 28, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey.shade400),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
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
        color: Colors.blueGrey.withValues(alpha: 0.2),
        border: Border.all(color: Colors.blueGrey),
      ),
      child: Text(label, style: const TextStyle(fontSize: 11)),
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
