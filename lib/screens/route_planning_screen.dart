import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

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

class RoutePlanningScreen extends StatefulWidget {
  const RoutePlanningScreen({super.key});

  @override
  State<RoutePlanningScreen> createState() => _RoutePlanningScreenState();
}

class _RoutePlanningScreenState extends State<RoutePlanningScreen> {
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Route Planning'),
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
        actions: [
          IconButton(
            icon: const Icon(Icons.add_location),
            onPressed: () {
              setState(() {
                _isAddingPoint = !_isAddingPoint;
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.play_arrow),
            onPressed: _routePoints.isNotEmpty
                ? () {
                    _executeRoute();
                  }
                : null,
          ),
        ],
      ),
      body: Column(
        children: [
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
                            onPressed: _routePoints.isNotEmpty
                                ? () {
                                    _clearAllPoints();
                                  }
                                : null,
                          ),
                          IconButton(
                            icon: const Icon(Icons.save),
                            onPressed: _routePoints.isNotEmpty
                                ? () {
                                    _saveRoute();
                                  }
                                : null,
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
                                      onPressed: () {
                                        _editRoutePoint(index);
                                      },
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete, size: 20),
                                      onPressed: () {
                                        _deleteRoutePoint(index);
                                      },
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
      ),
    );
  }

  void _addRoutePoint(TapDownDetails details) {
    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final localPosition = renderBox.globalToLocal(details.globalPosition);
    
    // Calculate relative position (you'll need to adjust this based on your actual map area)
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
            decoration: InputDecoration(
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
    // TODO: Implement route saving
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Route saved successfully!'),
      ),
    );
  }

  void _executeRoute() {
    // TODO: Send route to robot for execution
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
                // TODO: Send route execution command to robot
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