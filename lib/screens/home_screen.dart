import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../providers/robot_control_provider.dart';
import '../providers/diary_provider.dart';
import '../widgets/joystick_widget.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('TeleTable Control'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await authProvider.logout();
              if (mounted) {
                context.go('/login');
              }
            },
          ),
        ],
      ),
      body: _buildContent(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.gamepad),
            label: 'Control',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.route),
            label: 'Routes',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.book),
            label: 'Diary',
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    switch (_selectedIndex) {
      case 0:
        return _buildControlScreen();
      case 1:
        return _buildRoutePlanningScreen();
      case 2:
        return _buildDiaryScreen();
      default:
        return _buildControlScreen();
    }
  }

  Widget _buildControlScreen() {
    return Consumer<RobotControlProvider>(
      builder: (context, robotProvider, child) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
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
    );
  }

  Widget _buildRoutePlanningScreen() {
    return _RoutePlanningContent();
  }

  Widget _buildDiaryScreen() {
    return _DiaryContent();
  }
}

// Route Planning Content Widget
class _RoutePlanningContent extends StatefulWidget {
  @override
  State<_RoutePlanningContent> createState() => _RoutePlanningContentState();
}

class _RoutePlanningContentState extends State<_RoutePlanningContent> {
  List<RoutePoint> _routePoints = [];
  bool _isAddingPoint = false;

  @override
  void initState() {
    super.initState();
    // Add some sample route points
    _routePoints = [
      RoutePoint(x: 0.3, y: 0.3, name: 'Start Point', color: Colors.green),
      RoutePoint(x: 0.7, y: 0.5, name: 'Checkpoint A', color: Colors.orange),
      RoutePoint(x: 0.5, y: 0.8, name: 'End Point', color: Colors.red),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Action buttons bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                icon: Icon(
                  _isAddingPoint ? Icons.close : Icons.add_location,
                  color: Theme.of(context).colorScheme.primary,
                ),
                onPressed: () {
                  setState(() {
                    _isAddingPoint = !_isAddingPoint;
                  });
                },
              ),
              IconButton(
                icon: Icon(
                  Icons.play_arrow,
                  color: _routePoints.isNotEmpty 
                      ? Theme.of(context).colorScheme.primary 
                      : Colors.grey,
                ),
                onPressed: _routePoints.isNotEmpty ? () => _executeRoute() : null,
              ),
            ],
          ),
        ),
        
        // Instructions banner
        if (_isAddingPoint)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
            child: Text(
              'Tap on the map to add a new route point',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

        // Route map area
        Expanded(
          flex: 3,
          child: Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                width: 2,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: GestureDetector(
                onTapDown: _isAddingPoint
                    ? (details) {
                        _addRoutePoint(details);
                      }
                    : null,
                child: CustomPaint(
                  size: Size.infinite,
                  painter: RouteMapPainter(
                    routePoints: _routePoints,
                    backgroundColor: Theme.of(context).colorScheme.surface,
                    gridColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                  ),
                ),
              ),
            ),
          ),
        ),

        // Route points list
        Expanded(
          flex: 2,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Route Points (${_routePoints.length})',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.clear_all),
                          onPressed: _routePoints.isNotEmpty ? () => _clearAllPoints() : null,
                        ),
                        IconButton(
                          icon: const Icon(Icons.save),
                          onPressed: _routePoints.isNotEmpty ? () => _saveRoute() : null,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _routePoints.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.route,
                              size: 64,
                              color: Colors.grey,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No route points added yet',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Tap the + button to start adding points',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _routePoints.length,
                        itemBuilder: (context, index) {
                          final point = _routePoints[index];
                          return Card(
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: point.color,
                                child: Text(
                                  '${index + 1}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              title: Text(point.name),
                              subtitle: Text(
                                'Position: (${(point.x * 100).toInt()}%, ${(point.y * 100).toInt()}%)',
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit, size: 20),
                                    onPressed: () => _editRoutePoint(index),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete, size: 20),
                                    onPressed: () => _deleteRoutePoint(index),
                                  ),
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
      ],
    );
  }

  void _addRoutePoint(TapDownDetails details) {
    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final localPosition = renderBox.globalToLocal(details.globalPosition);
    
    final x = localPosition.dx / renderBox.size.width;
    final y = localPosition.dy / renderBox.size.height;
    
    if (x >= 0 && x <= 1 && y >= 0 && y <= 1) {
      _showAddPointDialog(x, y);
    }
  }

  void _showAddPointDialog(double x, double y) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        String pointName = 'Point ${_routePoints.length + 1}';
        return AlertDialog(
          title: const Text('Add Route Point'),
          content: TextField(
            onChanged: (value) {
              pointName = value;
            },
            decoration: const InputDecoration(
              labelText: 'Point Name',
              hintText: 'Enter point name',
              border: OutlineInputBorder(),
            ),
            controller: TextEditingController(text: pointName),
          ),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
                setState(() {
                  _isAddingPoint = false;
                });
              },
            ),
            ElevatedButton(
              child: const Text('Add'),
              onPressed: () {
                setState(() {
                  _routePoints.add(RoutePoint(
                    x: x,
                    y: y,
                    name: pointName.isNotEmpty ? pointName : 'Point ${_routePoints.length + 1}',
                    color: _getPointColor(_routePoints.length),
                  ));
                  _isAddingPoint = false;
                });
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _editRoutePoint(int index) {
    final point = _routePoints[index];
    String pointName = point.name;
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Edit Route Point'),
          content: TextField(
            onChanged: (value) {
              pointName = value;
            },
            decoration: const InputDecoration(
              labelText: 'Point Name',
              border: OutlineInputBorder(),
            ),
            controller: TextEditingController(text: pointName),
          ),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              child: const Text('Update'),
              onPressed: () {
                setState(() {
                  _routePoints[index] = RoutePoint(
                    x: point.x,
                    y: point.y,
                    name: pointName.isNotEmpty ? pointName : point.name,
                    color: point.color,
                  );
                });
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _deleteRoutePoint(int index) {
    setState(() {
      _routePoints.removeAt(index);
    });
  }

  void _clearAllPoints() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Clear All Points'),
          content: const Text('Are you sure you want to clear all route points?'),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Clear All'),
              onPressed: () {
                setState(() {
                  _routePoints.clear();
                });
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _saveRoute() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Route saved successfully!'),
      ),
    );
  }

  void _executeRoute() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Execute Route'),
          content: Text('Execute route with ${_routePoints.length} points?'),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              child: const Text('Execute'),
              onPressed: () {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Route execution started!'),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  Color _getPointColor(int index) {
    final colors = [
      Colors.green,
      Colors.blue,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.pink,
      Colors.indigo,
      Colors.brown,
    ];
    return colors[index % colors.length];
  }
}

// Diary Content Widget
class _DiaryContent extends StatefulWidget {
  @override
  State<_DiaryContent> createState() => _DiaryContentState();
}

class _DiaryContentState extends State<_DiaryContent> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<DiaryProvider>(context, listen: false).loadEntries();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<DiaryProvider>(
      builder: (context, diaryProvider, child) {
        if (diaryProvider.isLoading) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (diaryProvider.error != null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error,
                  size: 64,
                  color: Colors.red,
                ),
                const SizedBox(height: 16),
                Text(
                  'Error: ${diaryProvider.error}',
                  style: const TextStyle(color: Colors.red),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    diaryProvider.clearError();
                    diaryProvider.loadEntries();
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        if (diaryProvider.entries.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.book_outlined,
                  size: 64,
                  color: Colors.grey,
                ),
                const SizedBox(height: 16),
                Text(
                  'No diary entries yet',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Start by adding your first entry',
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () => _showAddEntryDialog(context),
                  icon: const Icon(Icons.add),
                  label: const Text('Add Entry'),
                ),
              ],
            ),
          );
        }

        return Column(
          children: [
            // Summary card
            Card(
              margin: const EdgeInsets.all(16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      Icons.book,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${diaryProvider.entries.length} Entries',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(
                          'Last updated: ${_formatDate(diaryProvider.entries.first.updatedAt)}',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => _showAddEntryDialog(context),
                      icon: const Icon(Icons.add),
                    ),
                  ],
                ),
              ),
            ),

            // Entries list
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: diaryProvider.entries.length,
                itemBuilder: (context, index) {
                  final entry = diaryProvider.entries[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      title: Text(
                        entry.title,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text(
                            entry.content,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(Icons.timer, size: 14, color: Colors.grey),
                              const SizedBox(width: 4),
                              Text(
                                '${entry.workingMinutes} min',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Text(
                                _formatDate(entry.createdAt),
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      trailing: PopupMenuButton(
                        onSelected: (value) {
                          switch (value) {
                            case 'edit':
                              _showEditEntryDialog(context, entry, index);
                              break;
                            case 'delete':
                              _showDeleteConfirmation(context, entry);
                              break;
                          }
                        },
                        itemBuilder: (BuildContext context) => [
                          const PopupMenuItem(
                            value: 'edit',
                            child: ListTile(
                              leading: Icon(Icons.edit, size: 20),
                              title: Text('Edit'),
                              dense: true,
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: ListTile(
                              leading: Icon(Icons.delete, size: 20),
                              title: Text('Delete'),
                              dense: true,
                            ),
                          ),
                        ],
                      ),
                      onTap: () {
                        _showEntryDetails(context, entry);
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}.${date.month}.${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  void _showAddEntryDialog(BuildContext context) {
    String title = '';
    String content = '';
    int workingMinutes = 60;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Add New Entry'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) => title = value,
                ),
                const SizedBox(height: 16),
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'Working Minutes',
                    border: OutlineInputBorder(),
                    hintText: '60',
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (value) => workingMinutes = int.tryParse(value) ?? 60,
                ),
                const SizedBox(height: 16),
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'Content',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 5,
                  onChanged: (value) => content = value,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (title.isNotEmpty && content.isNotEmpty) {
                  Provider.of<DiaryProvider>(context, listen: false)
                      .addEntry(title, content, workingMinutes);
                  Navigator.of(context).pop();
                }
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  void _showEditEntryDialog(BuildContext context, DiaryEntry entry, int index) {
    String title = entry.title;
    String content = entry.content;
    int workingMinutes = entry.workingMinutes;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Edit Entry'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    border: OutlineInputBorder(),
                  ),
                  controller: TextEditingController(text: title),
                  onChanged: (value) => title = value,
                ),
                const SizedBox(height: 16),
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'Working Minutes',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  controller: TextEditingController(text: workingMinutes.toString()),
                  onChanged: (value) => workingMinutes = int.tryParse(value) ?? workingMinutes,
                ),
                const SizedBox(height: 16),
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'Content',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 5,
                  controller: TextEditingController(text: content),
                  onChanged: (value) => content = value,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (title.isNotEmpty && content.isNotEmpty) {
                  final updatedEntry = entry.copyWith(
                    title: title,
                    content: content,
                    workingMinutes: workingMinutes,
                  );
                  
                  Provider.of<DiaryProvider>(context, listen: false)
                      .updateEntry(updatedEntry);
                  Navigator.of(context).pop();
                }
              },
              child: const Text('Update'),
            ),
          ],
        );
      },
    );
  }

  void _showDeleteConfirmation(BuildContext context, DiaryEntry entry) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Entry'),
          content: Text('Are you sure you want to delete "${entry.title}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () {
                Provider.of<DiaryProvider>(context, listen: false)
                    .deleteEntry(entry.id);
                Navigator.of(context).pop();
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  void _showEntryDetails(BuildContext context, DiaryEntry entry) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(entry.title),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(entry.content),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(Icons.timer, size: 16, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      'Working time: ${entry.workingMinutes} minutes',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Created: ${_formatDate(entry.createdAt)}',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
                if (entry.createdAt != entry.updatedAt)
                  Text(
                    'Updated: ${_formatDate(entry.updatedAt)}',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }
}

// Route Point class
class RoutePoint {
  final double x;
  final double y;
  final String name;
  final Color color;

  RoutePoint({
    required this.x,
    required this.y,
    required this.name,
    this.color = Colors.blue,
  });
}

// Route Map Painter
class RouteMapPainter extends CustomPainter {
  final List<RoutePoint> routePoints;
  final Color backgroundColor;
  final Color gridColor;

  RouteMapPainter({
    required this.routePoints,
    required this.backgroundColor,
    required this.gridColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw background
    final backgroundPaint = Paint()..color = backgroundColor;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), backgroundPaint);

    // Draw grid
    _drawGrid(canvas, size);

    // Draw route lines
    if (routePoints.length > 1) {
      _drawRouteLines(canvas, size);
    }

    // Draw route points
    for (int i = 0; i < routePoints.length; i++) {
      _drawRoutePoint(canvas, size, routePoints[i], i + 1);
    }
  }

  void _drawGrid(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;

    const gridSpacing = 50.0;

    // Vertical lines
    for (double x = 0; x <= size.width; x += gridSpacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }

    // Horizontal lines
    for (double y = 0; y <= size.height; y += gridSpacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
  }

  void _drawRouteLines(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = Colors.grey
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < routePoints.length - 1; i++) {
      final start = Offset(
        routePoints[i].x * size.width,
        routePoints[i].y * size.height,
      );
      final end = Offset(
        routePoints[i + 1].x * size.width,
        routePoints[i + 1].y * size.height,
      );
      canvas.drawLine(start, end, linePaint);
    }
  }

  void _drawRoutePoint(Canvas canvas, Size size, RoutePoint point, int number) {
    final position = Offset(point.x * size.width, point.y * size.height);

    // Draw point circle
    final pointPaint = Paint()..color = point.color;
    canvas.drawCircle(position, 15, pointPaint);

    // Draw border
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(position, 15, borderPaint);

    // Draw number
    final textPainter = TextPainter(
      text: TextSpan(
        text: number.toString(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        position.dx - textPainter.width / 2,
        position.dy - textPainter.height / 2,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}