import 'package:flutter/material.dart';

import '../game_controller.dart';
import '../theme.dart';

/// Joystick secreto de desarrollador: mueve al personaje sin GPS.
/// Velocidad máxima ~12 m/s (en modo debug los filtros anti-vehículo
/// están desactivados, así que todo cuenta).
class DebugJoystick extends StatefulWidget {
  final GameController controller;

  const DebugJoystick({super.key, required this.controller});

  @override
  State<DebugJoystick> createState() => _DebugJoystickState();
}

class _DebugJoystickState extends State<DebugJoystick> {
  static const double _size = 140;
  static const double _maxThumb = 48;
  static const double _maxSpeed = 12; // m/s

  Offset _thumb = Offset.zero;

  void _update(Offset local) {
    final center = const Offset(_size / 2, _size / 2);
    var v = local - center;
    if (v.distance > _maxThumb) {
      v = v / v.distance * _maxThumb;
    }
    setState(() => _thumb = v);
    final vx = v.dx / _maxThumb * _maxSpeed;
    final vy = -v.dy / _maxThumb * _maxSpeed; // pantalla-Y invertida
    widget.controller.setJoystick(vx, vy);
  }

  void _release() {
    setState(() => _thumb = Offset.zero);
    widget.controller.setJoystick(0, 0);
  }

  @override
  void dispose() {
    widget.controller.setJoystick(0, 0);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final speed =
        (_thumb.distance / _maxThumb * _maxSpeed).toStringAsFixed(1);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: RN.danger.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '🐞 VUELO $speed m/s',
            style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.white),
          ),
        ),
        const SizedBox(height: 6),
        GestureDetector(
          onPanStart: (d) => _update(d.localPosition),
          onPanUpdate: (d) => _update(d.localPosition),
          onPanEnd: (_) => _release(),
          onPanCancel: _release,
          child: SizedBox(
            width: _size,
            height: _size,
            child: CustomPaint(
              painter: _JoyPainter(_thumb),
            ),
          ),
        ),
      ],
    );
  }
}

class _JoyPainter extends CustomPainter {
  final Offset thumb;

  _JoyPainter(this.thumb);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final base = Paint()
      ..color = RN.night.withValues(alpha: 0.75)
      ..isAntiAlias = true;
    final ring = Paint()
      ..color = RN.danger.withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..isAntiAlias = true;
    canvas.drawCircle(center, size.width / 2 - 4, base);
    canvas.drawCircle(center, size.width / 2 - 4, ring);

    // Cruceta sutil.
    final cross = Paint()
      ..color = Colors.white24
      ..strokeWidth = 1;
    canvas.drawLine(center - Offset(0, size.height / 2 - 12),
        center + Offset(0, size.height / 2 - 12), cross);
    canvas.drawLine(center - Offset(size.width / 2 - 12, 0),
        center + Offset(size.width / 2 - 12, 0), cross);

    // Palanca.
    final knob = Paint()
      ..color = RN.danger
      ..isAntiAlias = true;
    canvas.drawCircle(center + thumb, 22, knob);
    canvas.drawCircle(
        center + thumb,
        22,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..isAntiAlias = true);
    // Flechita de dirección.
    final dir = thumb.distance > 4 ? thumb / thumb.distance : Offset.zero;
    if (dir != Offset.zero) {
      canvas.drawCircle(center + thumb + dir * 12, 4,
          Paint()..color = Colors.white..isAntiAlias = true);
    }
  }

  @override
  bool shouldRepaint(covariant _JoyPainter old) => old.thumb != thumb;
}
