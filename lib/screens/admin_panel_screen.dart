import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../services/api_service.dart';

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {
  final _searchController = TextEditingController();

  bool _loading = true;
  String _error = '';
  List<Map<String, dynamic>> _users = [];

  ApiService get _api => context.read<ApiService>();

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    if (!auth.isAdmin) {
      return const Scaffold(
        body: Center(child: Text('Admin access required.')),
      );
    }

    final filtered = _users.where((u) {
      final q = _searchController.text.toLowerCase();
      if (q.isEmpty) {
        return true;
      }
      return (u['name']?.toString().toLowerCase().contains(q) ?? false) ||
          (u['email']?.toString().toLowerCase().contains(q) ?? false) ||
          (u['id']?.toString().toLowerCase().contains(q) ?? false);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Panel'),
        actions: [
          IconButton(
            onPressed: _loadUsers,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Search users',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: () => setState(() {}),
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            if (_error.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  border: Border.all(color: Colors.red.withOpacity(0.4)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(_error, style: const TextStyle(color: Colors.redAccent)),
              ),
            const SizedBox(height: 12),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final user = filtered[index];
                        final role = (user['role'] as String?) ?? 'Viewer';
                        return Card(
                          child: ListTile(
                            title: Text(user['name']?.toString() ?? 'Unknown'),
                            subtitle: Text(
                              '${user['email'] ?? 'No email'}\nRole: $role',
                            ),
                            isThreeLine: true,
                            onTap: () => _showSessionHistory(user),
                            trailing: PopupMenuButton<String>(
                              onSelected: (value) async {
                                if (value == 'edit') {
                                  await _showEditDialog(user);
                                }
                                if (value == 'delete') {
                                  await _deleteUser(user['id']?.toString() ?? '');
                                }
                              },
                              itemBuilder: (ctx) => const [
                                PopupMenuItem(value: 'edit', child: Text('Edit')),
                                PopupMenuItem(value: 'delete', child: Text('Delete')),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadUsers() async {
    setState(() {
      _loading = true;
      _error = '';
    });

    try {
      final users = await _api.getUsers();
      if (!mounted) {
        return;
      }
      setState(() {
        _users = users;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = 'Failed to fetch users: $e';
        _loading = false;
      });
    }
  }

  Future<void> _showEditDialog(Map<String, dynamic> user) async {
    final nameController = TextEditingController(text: user['name']?.toString() ?? '');
    final emailController = TextEditingController(text: user['email']?.toString() ?? '');
    final passwordController = TextEditingController();
    String role = (user['role'] as String?) ?? 'Viewer';

    final save = await showDialog<bool>(
          context: context,
          builder: (ctx) {
            return StatefulBuilder(
              builder: (ctx, setModalState) => AlertDialog(
                title: const Text('Edit User'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: nameController,
                        decoration: const InputDecoration(labelText: 'Name'),
                      ),
                      TextField(
                        controller: emailController,
                        decoration: const InputDecoration(labelText: 'Email'),
                      ),
                      DropdownButtonFormField<String>(
                        value: role,
                        decoration: const InputDecoration(labelText: 'Role'),
                        items: const [
                          DropdownMenuItem(value: 'Admin', child: Text('Admin')),
                          DropdownMenuItem(value: 'Operator', child: Text('Operator')),
                          DropdownMenuItem(value: 'Viewer', child: Text('Viewer')),
                        ],
                        onChanged: (value) {
                          setModalState(() {
                            role = value ?? role;
                          });
                        },
                      ),
                      TextField(
                        controller: passwordController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'New Password (optional)',
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
                  ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Save')),
                ],
              ),
            );
          },
        ) ??
        false;

    if (!save) {
      return;
    }

    try {
      await _api.updateUser(
        id: user['id']?.toString() ?? '',
        name: nameController.text.trim(),
        email: emailController.text.trim(),
        role: role,
        password: passwordController.text.trim(),
      );
      if (!mounted) {
        return;
      }
      await _loadUsers();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User updated')),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update user: $e')),
      );
    }
  }

  Future<void> _deleteUser(String id) async {
    if (id.isEmpty) {
      return;
    }

    final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Delete User'),
            content: const Text('This action cannot be undone. Delete this user?'),
            actions: [
              TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
              ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Delete')),
            ],
          ),
        ) ??
        false;

    if (!confirmed) {
      return;
    }

    try {
      await _api.deleteUser(id);
      if (!mounted) {
        return;
      }
      await _loadUsers();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User deleted')),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete user: $e')),
      );
    }
  }

  Future<void> _showSessionHistory(Map<String, dynamic> user) async {
    final userId = user['id']?.toString() ?? '';
    if (userId.isEmpty) {
      return;
    }

    showDialog<void>(
      context: context,
      builder: (ctx) {
        return Dialog(
          child: SizedBox(
            width: 900,
            height: 560,
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _api.getUserSessions(userId),
              builder: (ctx, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Failed to load sessions: ${snapshot.error}'));
                }

                final sessions = snapshot.data ?? const [];
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Session History - ${user['name'] ?? ''}',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(ctx).pop(),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: sessions.isEmpty
                            ? const Center(child: Text('No session history available.'))
                            : ListView.separated(
                                itemCount: sessions.length,
                                separatorBuilder: (_, __) => const Divider(height: 1),
                                itemBuilder: (ctx, index) {
                                  final s = sessions[index];
                                  final created = s['created_at']?.toString() ?? '';
                                  final ip = s['ip_address']?.toString() ?? 'unknown';
                                  final userAgent = s['user_agent']?.toString() ?? 'unknown';
                                  return ExpansionTile(
                                    title: Text(created),
                                    subtitle: Text('IP: $ip'),
                                    children: [
                                      ListTile(
                                        title: const Text('Browser/User Agent'),
                                        subtitle: Text(userAgent),
                                      ),
                                      ListTile(
                                        title: const Text('Fingerprint Data'),
                                        subtitle: Text((s['fingerprint_data'] ?? {}).toString()),
                                      ),
                                    ],
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}
