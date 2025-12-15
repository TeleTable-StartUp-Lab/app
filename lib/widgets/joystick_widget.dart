import 'package:flutter/material.dart';
import 'dart:math' as math;

class JoystickWidget extends StatefulWidget {
  final Function(double x, double y) onChanged;
  final double size;
  final Color backgroundColor;
  final Color knobColor;

  const JoystickWidget({
    super.key,
    required this.onChanged,
    this.size = 200,
    this.backgroundColor = Colors.grey,
    this.knobColor = Colors.blue,
  });

  @override
  State<JoystickWidget> createState() => _JoystickWidgetState();
}

class _JoystickWidgetState extends State<JoystickWidget> {
  double _knobX = 0.0;
  double _knobY = 0.0;
  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final knobColor = theme.colorScheme.primary;
    final backgroundColor = theme.colorScheme.surface;
    
    return Center(
      child: Container(
        width: widget.size,
        height: widget.size,
        child: GestureDetector(
          onPanStart: (details) {
            _isDragging = true;
            _updateKnobPosition(details.localPosition);
          },
          onPanUpdate: (details) {
            if (_isDragging) {
              _updateKnobPosition(details.localPosition);
            }
          },
          onPanEnd: (details) {
            _isDragging = false;
            setState(() {
              _knobX = 0.0;
              _knobY = 0.0;
            });
            widget.onChanged(0.0, 0.0);
          },
          child: CustomPaint(
            size: Size(widget.size, widget.size),
            painter: JoystickPainter(
              knobX: _knobX,
              knobY: _knobY,
              backgroundColor: backgroundColor,
              knobColor: knobColor,
              borderColor: knobColor.withOpacity(0.5),
            ),
          ),
        ),
      ),
    );
  }

  void _updateKnobPosition(Offset position) {
    final center = widget.size / 2;
    final radius = center - 20; // Leave some margin

    double deltaX = position.dx - center;
    double deltaY = position.dy - center;

    final distance = math.sqrt(deltaX * deltaX + deltaY * deltaY);

    if (distance <= radius) {
      _knobX = deltaX / radius;
      _knobY = deltaY / radius;
    } else {
      final angle = math.atan2(deltaY, deltaX);
      _knobX = math.cos(angle);
      _knobY = math.sin(angle);
    }

    setState(() {});
    widget.onChanged(_knobX, -_knobY); // Invert Y for natural movement
  }
}

class JoystickPainter extends CustomPainter {
  final double knobX;
  final double knobY;
  final Color backgroundColor;
  final Color knobColor;
  final Color borderColor;

  JoystickPainter({
    required this.knobX,
    required this.knobY,
    required this.backgroundColor,
    required this.knobColor,
    required this.borderColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 20;

    // Draw outer circle (background)
    final backgroundPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, radius + 15, backgroundPaint);

    // Draw border
    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    canvas.drawCircle(center, radius + 15, borderPaint);

    // Draw directional indicators
    _drawDirectionalIndicators(canvas, center, radius + 5);

    // Draw knob
    final knobPosition = Offset(
      center.dx + knobX * radius,
      center.dy + knobY * radius,
    );

    final knobPaint = Paint()
      ..color = knobColor
      ..style = PaintingStyle.fill;

    final knobShadowPaint = Paint()
      ..color = Colors.black26
      ..style = PaintingStyle.fill;

    // Draw shadow
    canvas.drawCircle(knobPosition + const Offset(2, 2), 15, knobShadowPaint);
    
    // Draw knob
    canvas.drawCircle(knobPosition, 15, knobPaint);

    // Draw knob border
    final knobBorderPaint = Paint()
      ..color = knobColor.withOpacity(0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawCircle(knobPosition, 15, knobBorderPaint);
  }

  void _drawDirectionalIndicators(Canvas canvas, Offset center, double radius) {
    final indicatorPaint = Paint()
      ..color = borderColor.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    // Draw cross lines
    canvas.drawLine(
      Offset(center.dx - radius, center.dy),
      Offset(center.dx + radius, center.dy),
      indicatorPaint,
    );
    
    canvas.drawLine(
      Offset(center.dx, center.dy - radius),
      Offset(center.dx, center.dy + radius),
      indicatorPaint,
    );

    // Draw directional labels
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );

    _drawDirectionLabel(canvas, textPainter, 'F', center.dx, center.dy - radius - 25);
    _drawDirectionLabel(canvas, textPainter, 'B', center.dx, center.dy + radius + 15);
    _drawDirectionLabel(canvas, textPainter, 'L', center.dx - radius - 15, center.dy);
    _drawDirectionLabel(canvas, textPainter, 'R', center.dx + radius + 8, center.dy);
  }

  void _drawDirectionLabel(Canvas canvas, TextPainter textPainter, String text, double x, double y) {
    textPainter.text = TextSpan(
      text: text,
      style: TextStyle(
        color: borderColor,
        fontSize: 12,
        fontWeight: FontWeight.bold,
      ),
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(x - textPainter.width / 2, y - textPainter.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}