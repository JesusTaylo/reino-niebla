import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';

import '../game_controller.dart';
import '../models/outposts.dart';
import '../theme.dart';
import '../util/geo.dart';

/// Capa de puestos de avanzada: edificios 2.5D repartidos por el mundo.
/// Se calculan según lo que se ve en pantalla (generación determinista).
class OutpostLayer extends StatelessWidget {
  final GameController controller;

  const OutpostLayer({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final camera = MapCamera.of(context);
    if (camera.zoom < 13.5) return const SizedBox.shrink();

    final b = camera.visibleBounds;
    final outposts = outpostsInArea(b.south, b.west, b.north, b.east);

    return MarkerLayer(
      markers: [
        for (final o in outposts)
          Marker(
            point: o.pos,
            width: 46,
            height: 52,
            alignment: Alignment.topCenter,
            child: GestureDetector(
              onTap: () => _showSheet(context, o),
              child: OutpostBuilding(
                type: o.type,
                usedToday: controller.outpostUsedToday(o),
              ),
            ),
          ),
      ],
    );
  }

  void _showSheet(BuildContext context, Outpost o) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: RN.panel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => _OutpostSheet(controller: controller, outpost: o),
    );
  }
}

class _OutpostSheet extends StatefulWidget {
  final GameController controller;
  final Outpost outpost;

  const _OutpostSheet({required this.controller, required this.outpost});

  @override
  State<_OutpostSheet> createState() => _OutpostSheetState();
}

class _OutpostSheetState extends State<_OutpostSheet> {
  String? _message;
  bool _activated = false;

  @override
  Widget build(BuildContext context) {
    final game = widget.controller;
    final o = widget.outpost;
    final pos = game.position;
    final dist = pos == null ? null : haversineMeters(pos, o.pos);
    final usedToday = game.outpostUsedToday(o);

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 60,
            height: 68,
            child: OutpostBuilding(type: o.type, usedToday: usedToday),
          ),
          const SizedBox(height: 8),
          Text(o.name, style: fantasyTitle(19, color: RN.goldSoft)),
          Text(
            '${o.typeName}'
            '${dist != null ? ' · a ${formatKm(dist)}' : ''}',
            style: const TextStyle(color: RN.parchmentDim, fontSize: 12.5),
          ),
          const SizedBox(height: 10),
          Text(
            usedToday || _activated
                ? 'Su bendición ya es tuya por hoy. Los caminos se cuidan '
                    'volviendo a ellos.'
                : 'Llega a pie y recibe su bendición: experiencia, la niebla '
                    'cercana despejada y, con suerte, algo olvidado.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: RN.parchment, fontSize: 13),
          ),
          if (_message != null) ...[
            const SizedBox(height: 8),
            Text(_message!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: RN.teal, fontSize: 12.5)),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: usedToday || _activated
                  ? null
                  : () {
                      final error = game.activateOutpost(o);
                      HapticFeedback.mediumImpact();
                      setState(() {
                        if (error == null) {
                          _activated = true;
                          _message =
                              '✨ +40 XP · La niebla retrocede alrededor.';
                          HapticFeedback.heavyImpact();
                        } else {
                          _message = error;
                        }
                      });
                    },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(usedToday || _activated
                    ? 'Bendición recibida hoy ✓'
                    : '🙏 Recibir bendición'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Un edificio en estilo 2.5D (isométrico plano): cara iluminada, cara en
/// sombra y base con sombra proyectada, para que "se levante" del mapa.
class OutpostBuilding extends StatelessWidget {
  final int type;
  final bool usedToday;

  const OutpostBuilding({
    super.key,
    required this.type,
    required this.usedToday,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _BuildingPainter(type: type, usedToday: usedToday),
    );
  }
}

class _BuildingPainter extends CustomPainter {
  final int type;
  final bool usedToday;

  _BuildingPainter({required this.type, required this.usedToday});

  // Paleta según estado: dorado vivo (disponible) o piedra apagada (usado).
  Color get _lit =>
      usedToday ? const Color(0xFF8C93A3) : const Color(0xFFE8CE7A);
  Color get _mid =>
      usedToday ? const Color(0xFF6A7080) : const Color(0xFFD4AF37);
  Color get _dark =>
      usedToday ? const Color(0xFF4A4F5C) : const Color(0xFF8A6D1F);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;

    Paint fill(Color c) => Paint()
      ..color = c
      ..isAntiAlias = true;

    // Sombra en el suelo (elipse): el truco barato que vende el 3D.
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(cx, h * 0.94), width: w * 0.62, height: h * 0.10),
      fill(Colors.black.withValues(alpha: 0.35)),
    );

    // Halo cuando está disponible.
    if (!usedToday) {
      canvas.drawOval(
        Rect.fromCenter(
            center: Offset(cx, h * 0.92), width: w * 0.9, height: h * 0.16),
        fill(RN.gold.withValues(alpha: 0.22)),
      );
    }

    switch (type) {
      case 0: // Atalaya: torre con almenas
        _tower(canvas, size, fill);
        break;
      case 1: // Santuario: caseta con cúpula
        _shrine(canvas, size, fill);
        break;
      case 2: // Obelisco
        _obelisk(canvas, size, fill);
        break;
      default: // Puesto: tienda con estandarte
        _camp(canvas, size, fill);
    }
  }

  void _tower(Canvas c, Size s, Paint Function(Color) fill) {
    final w = s.width, h = s.height, cx = w / 2;
    // Cara iluminada (frente) y cara en sombra (lado derecho).
    final front = Path()
      ..moveTo(cx - w * 0.20, h * 0.30)
      ..lineTo(cx - w * 0.26, h * 0.90)
      ..lineTo(cx + w * 0.06, h * 0.90)
      ..lineTo(cx + w * 0.06, h * 0.30)
      ..close();
    final side = Path()
      ..moveTo(cx + w * 0.06, h * 0.30)
      ..lineTo(cx + w * 0.06, h * 0.90)
      ..lineTo(cx + w * 0.26, h * 0.82)
      ..lineTo(cx + w * 0.22, h * 0.28)
      ..close();
    c.drawPath(front, fill(_mid));
    c.drawPath(side, fill(_dark));
    // Almenas.
    for (var i = 0; i < 3; i++) {
      c.drawRect(
        Rect.fromLTWH(
            cx - w * 0.24 + i * w * 0.17, h * 0.22, w * 0.10, h * 0.10),
        fill(_lit),
      );
    }
    // Ventana.
    c.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromCenter(
              center: Offset(cx - w * 0.09, h * 0.55),
              width: w * 0.10,
              height: h * 0.14),
          Radius.circular(w * 0.05)),
      fill(const Color(0xFF0D1026)),
    );
  }

  void _shrine(Canvas c, Size s, Paint Function(Color) fill) {
    final w = s.width, h = s.height, cx = w / 2;
    // Cuerpo.
    c.drawRect(
        Rect.fromLTWH(cx - w * 0.24, h * 0.52, w * 0.36, h * 0.38),
        fill(_mid));
    c.drawPath(
      Path()
        ..moveTo(cx + w * 0.12, h * 0.52)
        ..lineTo(cx + w * 0.12, h * 0.90)
        ..lineTo(cx + w * 0.28, h * 0.83)
        ..lineTo(cx + w * 0.28, h * 0.48)
        ..close(),
      fill(_dark),
    );
    // Cúpula.
    c.drawArc(
      Rect.fromCenter(
          center: Offset(cx, h * 0.50), width: w * 0.6, height: h * 0.46),
      3.14159,
      3.14159,
      true,
      fill(_lit),
    );
    // Puerta.
    c.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromCenter(
              center: Offset(cx - w * 0.06, h * 0.76),
              width: w * 0.13,
              height: h * 0.22),
          Radius.circular(w * 0.06)),
      fill(const Color(0xFF0D1026)),
    );
  }

  void _obelisk(Canvas c, Size s, Paint Function(Color) fill) {
    final w = s.width, h = s.height, cx = w / 2;
    final front = Path()
      ..moveTo(cx, h * 0.10)
      ..lineTo(cx - w * 0.16, h * 0.88)
      ..lineTo(cx, h * 0.90)
      ..close();
    final side = Path()
      ..moveTo(cx, h * 0.10)
      ..lineTo(cx, h * 0.90)
      ..lineTo(cx + w * 0.16, h * 0.85)
      ..close();
    c.drawPath(front, fill(_mid));
    c.drawPath(side, fill(_dark));
    // Punta brillante.
    c.drawCircle(Offset(cx, h * 0.10), w * 0.07, fill(_lit));
    // Base.
    c.drawRect(
        Rect.fromLTWH(cx - w * 0.22, h * 0.86, w * 0.44, h * 0.06),
        fill(_dark));
  }

  void _camp(Canvas c, Size s, Paint Function(Color) fill) {
    final w = s.width, h = s.height, cx = w / 2;
    // Tienda (dos caras).
    c.drawPath(
      Path()
        ..moveTo(cx, h * 0.42)
        ..lineTo(cx - w * 0.30, h * 0.90)
        ..lineTo(cx + w * 0.02, h * 0.90)
        ..close(),
      fill(_mid),
    );
    c.drawPath(
      Path()
        ..moveTo(cx, h * 0.42)
        ..lineTo(cx + w * 0.02, h * 0.90)
        ..lineTo(cx + w * 0.30, h * 0.86)
        ..close(),
      fill(_dark),
    );
    // Estandarte.
    c.drawLine(
      Offset(cx + w * 0.22, h * 0.86),
      Offset(cx + w * 0.22, h * 0.24),
      Paint()
        ..color = _dark
        ..strokeWidth = w * 0.05
        ..isAntiAlias = true,
    );
    c.drawPath(
      Path()
        ..moveTo(cx + w * 0.22, h * 0.26)
        ..lineTo(cx + w * 0.44, h * 0.32)
        ..lineTo(cx + w * 0.22, h * 0.40)
        ..close(),
      fill(_lit),
    );
  }

  @override
  bool shouldRepaint(covariant _BuildingPainter old) =>
      old.type != type || old.usedToday != usedToday;
}
