import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../services/api_service.dart';

class QueueControlScreen extends StatefulWidget {
  const QueueControlScreen({super.key});

  @override
  State<QueueControlScreen> createState() => _QueueControlScreenState();
}

class _QueueControlScreenState extends State<QueueControlScreen> {
  bool _loading = true;
  bool _optimizing = false;
  String _error = '';
  String _success = '';
  List<Map<String, dynamic>> _routes = [];
  Timer? _refreshTimer;

  ApiService get _api => context.read<ApiService>();

  @override
  void initState() {
    super.initState();
    _loadRoutes();
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _loadRoutes(silent: true);
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Queue Control'),
        actions: [
          IconButton(
            onPressed: _loadRoutes,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: (!auth.isAdmin || _optimizing || _routes.length < 2)
                        ? null
                        : _optimizeRoutes,
                    icon: _optimizing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.auto_graph),
                    label: Text(_optimizing ? 'Optimizing...' : 'Optimize Queue'),
                  ),
                ),
              ],
            ),
            if (_error.isNotEmpty) ...[
              const SizedBox(height: 12),
              _MessageBox(message: _error, color: Colors.redAccent),
            ],
            if (_success.isNotEmpty) ...[
              const SizedBox(height: 12),
              _MessageBox(message: _success, color: Colors.green),
            ],
            const SizedBox(height: 12),
            Expanded(child: _buildContent(auth)),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(AuthProvider auth) {
    if (_loading && _routes.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_routes.isEmpty) {
      return const Center(child: Text('No routes in queue.'));
    }

    return ListView.separated(
      itemCount: _routes.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final route = _routes[index];
        final start = (route['start'] ?? route['startNode'] ?? route['start_node'])?.toString() ?? '-';
        final destination =
            (route['destination'] ?? route['endNode'] ?? route['destination_node'])?.toString() ?? '-';
        final addedBy = (route['added_by'] ?? route['addedBy'])?.toString() ?? 'Unknown';
        final addedAtRaw = (route['added_at'] ?? route['addedAt'])?.toString();
        final addedAt = addedAtRaw == null ? null : DateTime.tryParse(addedAtRaw);

        return Card(
          child: ListTile(
            leading: CircleAvatar(child: Text('${index + 1}')),
            title: Text('$start -> $destination'),
            subtitle: Text(
              'Added by: $addedBy'
              '${addedAt != null ? '\n${addedAt.toLocal()}' : ''}',
            ),
            isThreeLine: addedAt != null,
            trailing: auth.isAdmin
                ? IconButton(
                    onPressed: () => _deleteRoute(route['id']?.toString() ?? ''),
                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                  )
                : null,
          ),
        );
      },
    );
  }

  Future<void> _loadRoutes({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = '';
      });
    }

    try {
      final routes = await _api.getRoutes();
      if (!mounted) {
        return;
      }
      setState(() {
        _routes = routes;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = 'Failed to load routes: $e';
        _loading = false;
      });
    }
  }

  Future<void> _deleteRoute(String id) async {
    if (id.isEmpty) {
      return;
    }

    final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Delete Route'),
            content: const Text('Delete this route from the queue?'),
            actions: [
              TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
              ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Delete')),
            ],
          ),
        ) ??
        false;

    if (!ok) {
      return;
    }

    try {
      await _api.deleteRoute(id);
      if (!mounted) {
        return;
      }
      setState(() {
        _success = 'Route deleted';
      });
      await _loadRoutes(silent: true);
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = 'Failed to delete route: $e';
      });
    }
  }

  Future<void> _optimizeRoutes() async {
    setState(() {
      _optimizing = true;
      _error = '';
      _success = '';
    });

    try {
      final response = await _api.optimizeRoutes();
      if (!mounted) {
        return;
      }
      setState(() {
        _success = response['message']?.toString() ?? 'Optimization triggered';
      });
      await _loadRoutes(silent: true);
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = 'Failed to optimize routes: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _optimizing = false;
        });
      }
    }
  }
}

class _MessageBox extends StatelessWidget {
  final String message;
  final Color color;

  const _MessageBox({required this.message, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(message, style: TextStyle(color: color)),
    );
  }
}
