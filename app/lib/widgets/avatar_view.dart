import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models/items.dart';
import '../models/player_state.dart';

/// Paleta de tonos de piel disponibles en el Espejo Mágico.
const List<Color> skinPalette = [
  Color(0xFFF5D7B8),
  Color(0xFFE8B98A),
  Color(0xFFD29B6E),
  Color(0xFFB07B4F),
  Color(0xFF8B5A33),
  Color(0xFF5F3C22),
];

/// Paleta de colores de pelo.
const List<Color> hairPalette = [
  Color(0xFF241D18), // negro
  Color(0xFF4A3220), // café oscuro
  Color(0xFF7A5230), // castaño
  Color(0xFFD9A94A), // rubio
  Color(0xFFB4502E), // pelirrojo
  Color(0xFFB9B9B9), // canoso
  Color(0xFF4E6ED6), // azul místico
];

const List<String> hairStyleNames = [
  'Rapado',
  'Corto',
  'Despeinado',
  'Media melena',
  'Melena larga',
  'Chongo',
];

const List<String> facialHairNames = [
  'Sin vello',
  'Bigote',
  'Candado',
  'Barba completa',
];

/// Dibuja el avatar del explorador con su apariencia y equipo actuales.
class AvatarView extends StatelessWidget {
  final Map<GearSlot, GearItem?> equipped;
  final Appearance appearance;

  const AvatarView({
    super.key,
    required this.equipped,
    required this.appearance,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _AvatarPainter(equipped, appearance),
      child: const AspectRatio(aspectRatio: 100 / 120),
    );
  }
}

class _AvatarPainter extends CustomPainter {
  final Map<GearSlot, GearItem?> equipped;
  final Appearance look;

  _AvatarPainter(this.equipped, this.look);

  static const _boot = Color(0xFF4E3524);
  static const _defaultTunicA = Color(0xFFC9B896);
  static const _defaultTunicB = Color(0xFF9C8A66);

  Color get _skin => skinPalette[look.skinTone % skinPalette.length];
  Color get _hair => hairPalette[look.hairColor % hairPalette.length];

  late double _u;
  late Canvas _c;

  Offset _p(double x, double y) => Offset(x * _u, y * _u);

  @override
  void paint(Canvas canvas, Size size) {
    _c = canvas;
    // Lienzo lógico de 100 x 120.
    _u = math.min(size.width / 100.0, size.height / 120.0);
    final dx = (size.width - 100 * _u) / 2;
    final dy = (size.height - 120 * _u) / 2;
    canvas.save();
    canvas.translate(dx, dy);

    final cape = equipped[GearSlot.capa];
    final tunic = equipped[GearSlot.tunica];
    final helmet = equipped[GearSlot.yelmo];
    final relic = equipped[GearSlot.reliquia];
    final hasHelmet = helmet != null;

    if (cape != null) _drawCape(cape);
    _drawHairBehind();
    _drawLegs();
    _drawBody(tunic);
    _drawArms(tunic);
    _drawHead();
    _drawFacialHair();
    _drawHairTop(hasHelmet);
    if (helmet != null) _drawHelmet(helmet);
    if (relic != null) _drawRelic(relic);

    canvas.restore();
  }

  Paint _fill(Color color) => Paint()
    ..color = color
    ..style = PaintingStyle.fill
    ..isAntiAlias = true;

  Paint _stroke(Color color, double width) => Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = width * _u
    ..strokeCap = StrokeCap.round
    ..isAntiAlias = true;

  // ---- Pelo: capa trasera (melenas) ----
  void _drawHairBehind() {
    final paint = _fill(_hair);
    switch (look.hairStyle) {
      case 3: // media melena: cortina detrás hasta la mandíbula
        final path = Path()
          ..moveTo(36 * _u, 26 * _u)
          ..quadraticBezierTo(33 * _u, 44 * _u, 36 * _u, 50 * _u)
          ..lineTo(64 * _u, 50 * _u)
          ..quadraticBezierTo(67 * _u, 44 * _u, 64 * _u, 26 * _u)
          ..close();
        _c.drawPath(path, paint);
        break;
      case 4: // melena larga: cae hasta los hombros
        final path = Path()
          ..moveTo(36 * _u, 24 * _u)
          ..quadraticBezierTo(30 * _u, 48 * _u, 34 * _u, 64 * _u)
          ..quadraticBezierTo(42 * _u, 68 * _u, 50 * _u, 66 * _u)
          ..quadraticBezierTo(58 * _u, 68 * _u, 66 * _u, 64 * _u)
          ..quadraticBezierTo(70 * _u, 48 * _u, 64 * _u, 24 * _u)
          ..close();
        _c.drawPath(path, paint);
        break;
    }
  }

  // ---- Pelo: capa superior ----
  void _drawHairTop(bool hasHelmet) {
    final style = look.hairStyle;
    final paint = _fill(_hair);
    final topRect =
        Rect.fromCircle(center: _p(50, 33.5), radius: 14.4 * _u);

    if (style == 0) {
      // Rapado: sombra sutil en el cráneo.
      if (!hasHelmet) {
        _c.drawArc(
            topRect, math.pi, math.pi, true, _fill(_hair.withValues(alpha: 0.28)));
      }
      return;
    }

    // Casquete base para todos los estilos con pelo.
    _c.drawArc(topRect, math.pi, math.pi, true, paint);
    // Patillas.
    _c.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(36.2 * _u, 32 * _u, 3 * _u, 6 * _u),
          Radius.circular(1.5 * _u)),
      paint,
    );
    _c.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(60.8 * _u, 32 * _u, 3 * _u, 6 * _u),
          Radius.circular(1.5 * _u)),
      paint,
    );

    if (hasHelmet) return; // el yelmo cubre los detalles superiores

    switch (style) {
      case 2: // despeinado: picos
        final spikes = Path();
        const xs = [40.0, 46.0, 52.0, 58.0];
        for (final x in xs) {
          spikes
            ..moveTo(x * _u, 22 * _u)
            ..lineTo((x + 3) * _u, 13 * _u)
            ..lineTo((x + 6) * _u, 21 * _u)
            ..close();
        }
        _c.drawPath(spikes, paint);
        break;
      case 5: // chongo
        _c.drawCircle(_p(50, 16), 5.2 * _u, paint);
        _c.drawLine(_p(46, 20), _p(54, 20), _stroke(_hair, 2));
        break;
    }
  }

  // ---- Vello facial ----
  void _drawFacialHair() {
    if (look.female || look.facialHair == 0) return;
    final paint = _fill(_hair);
    final f = look.facialHair;

    if (f == 3) {
      // Barba completa: media luna en la mitad inferior de la cara.
      final path = Path()
        ..addArc(
            Rect.fromCircle(center: _p(50, 34.5), radius: 14.2 * _u),
            math.pi * 0.08,
            math.pi * 0.84)
        ..arcTo(
            Rect.fromCircle(center: _p(50, 33), radius: 8.2 * _u),
            math.pi * 0.88,
            -math.pi * 0.76,
            false)
        ..close();
      _c.drawPath(path, paint);
      return;
    }

    // Bigote (para 1 y 2).
    final mustache = Path()
      ..moveTo(50 * _u, 37.2 * _u)
      ..quadraticBezierTo(46 * _u, 36.6 * _u, 44 * _u, 38.8 * _u)
      ..quadraticBezierTo(47 * _u, 39.4 * _u, 50 * _u, 38.6 * _u)
      ..quadraticBezierTo(53 * _u, 39.4 * _u, 56 * _u, 38.8 * _u)
      ..quadraticBezierTo(54 * _u, 36.6 * _u, 50 * _u, 37.2 * _u)
      ..close();
    _c.drawPath(mustache, paint);

    if (f == 2) {
      // Candado: parche en la barbilla.
      _c.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(
                center: _p(50, 45.5), width: 7 * _u, height: 4.4 * _u),
            Radius.circular(2 * _u)),
        paint,
      );
    }
  }

  // ---- Capa ----
  void _drawCape(GearItem cape) {
    final path = Path()
      ..moveTo(34 * _u, 52 * _u)
      ..quadraticBezierTo(20 * _u, 80 * _u, 26 * _u, 108 * _u)
      ..quadraticBezierTo(38 * _u, 104 * _u, 50 * _u, 108 * _u)
      ..quadraticBezierTo(62 * _u, 104 * _u, 74 * _u, 108 * _u)
      ..quadraticBezierTo(80 * _u, 80 * _u, 66 * _u, 52 * _u)
      ..close();

    if (cape.variant == 3) {
      final paint = Paint()
        ..shader = ui.Gradient.linear(
          _p(50, 52),
          _p(50, 108),
          [cape.colorA, Color.lerp(cape.colorA, cape.colorB, 0.7)!],
        )
        ..isAntiAlias = true;
      _c.drawPath(path, paint);
      final dot = _fill(cape.colorB);
      const spots = [
        [32.0, 70.0],
        [44.0, 88.0],
        [60.0, 66.0],
        [68.0, 92.0],
        [50.0, 76.0],
      ];
      for (final s in spots) {
        _c.drawCircle(_p(s[0], s[1]), 1.6 * _u, dot);
      }
    } else {
      _c.drawPath(path, _fill(cape.colorA));
      if (cape.variant == 2) {
        _c.drawPath(path, _stroke(cape.colorB, 2.2));
      }
    }
  }

  // ---- Piernas y botas ----
  void _drawLegs() {
    final leg = _fill(const Color(0xFF6B5B45));
    _c.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(40 * _u, 92 * _u, 8 * _u, 16 * _u),
          Radius.circular(3 * _u)),
      leg,
    );
    _c.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(52 * _u, 92 * _u, 8 * _u, 16 * _u),
          Radius.circular(3 * _u)),
      leg,
    );
    final boot = _fill(_boot);
    _c.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(38 * _u, 104 * _u, 12 * _u, 8 * _u),
          Radius.circular(3 * _u)),
      boot,
    );
    _c.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(50 * _u, 104 * _u, 12 * _u, 8 * _u),
          Radius.circular(3 * _u)),
      boot,
    );
  }

  // ---- Cuerpo / túnica ----
  void _drawBody(GearItem? tunic) {
    final a = tunic?.colorA ?? _defaultTunicA;
    final b = tunic?.colorB ?? _defaultTunicB;
    final variant = tunic?.variant ?? 1;

    // Silueta con cintura ligeramente marcada para el cuerpo femenino.
    final waist = look.female ? 3.0 : 0.0;
    final body = Path()
      ..moveTo(38 * _u, 52 * _u)
      ..quadraticBezierTo(50 * _u, 46 * _u, 62 * _u, 52 * _u)
      ..quadraticBezierTo(
          (63 - waist) * _u, 72 * _u, 66 * _u, 94 * _u)
      ..quadraticBezierTo(50 * _u, 100 * _u, 34 * _u, 94 * _u)
      ..quadraticBezierTo(
          (37 + waist) * _u, 72 * _u, 38 * _u, 52 * _u)
      ..close();
    _c.drawPath(body, _fill(a));

    if (variant == 2) {
      _c.drawRect(Rect.fromLTWH(35 * _u, 74 * _u, 30 * _u, 5 * _u), _fill(b));
      _c.drawRect(
          Rect.fromLTWH(47 * _u, 73 * _u, 6 * _u, 7 * _u),
          _fill(const Color(0xFFD4AF37)));
    } else if (variant == 3) {
      final scale = _stroke(b, 1.6);
      for (var row = 0; row < 4; row++) {
        final y = (58 + row * 9).toDouble();
        for (var col = 0; col < 3; col++) {
          final x = (40 + col * 8).toDouble();
          _c.drawArc(
            Rect.fromCircle(center: _p(x + 2, y), radius: 4 * _u),
            0,
            math.pi,
            false,
            scale,
          );
        }
      }
    } else {
      _c.drawLine(_p(50, 52), _p(50, 96), _stroke(b, 1.2));
    }
  }

  // ---- Brazos ----
  void _drawArms(GearItem? tunic) {
    final a = tunic?.colorA ?? _defaultTunicA;
    final arm = _stroke(a, 7);
    _c.drawLine(_p(38, 56), _p(30, 76), arm);
    _c.drawLine(_p(62, 56), _p(74, 70), arm);
    final hand = _fill(_skin);
    _c.drawCircle(_p(30, 78), 3.4 * _u, hand);
    _c.drawCircle(_p(76, 71), 3.4 * _u, hand);
  }

  // ---- Cabeza ----
  void _drawHead() {
    _c.drawCircle(_p(50, 34), 14 * _u, _fill(_skin));
    final shadow =
        Color.lerp(_skin, const Color(0xFF3A2B1E), 0.28)!;
    _c.drawArc(
      Rect.fromCircle(center: _p(50, 36), radius: 13 * _u),
      math.pi * 0.15,
      math.pi * 0.7,
      false,
      _stroke(shadow, 1.4),
    );
    // Ojos.
    final eye = _fill(const Color(0xFF3A2B1E));
    _c.drawCircle(_p(45, 33), 1.7 * _u, eye);
    _c.drawCircle(_p(55, 33), 1.7 * _u, eye);
    // Pestañas para el cuerpo femenino.
    if (look.female) {
      final lash = _stroke(const Color(0xFF3A2B1E), 1.1);
      _c.drawLine(_p(42.6, 31.4), _p(44.0, 32.2), lash);
      _c.drawLine(_p(57.4, 31.4), _p(56.0, 32.2), lash);
    }
    // Sonrisa (la barba completa la tapa después, como debe ser).
    _c.drawArc(
      Rect.fromCircle(center: _p(50, 37), radius: 5 * _u),
      math.pi * 0.2,
      math.pi * 0.6,
      false,
      _stroke(const Color(0xFF3A2B1E), 1.2),
    );
  }

  // ---- Yelmos ----
  void _drawHelmet(GearItem helmet) {
    final a = helmet.colorA;
    final b = helmet.colorB;
    switch (helmet.variant) {
      case 1: // Capucha
        final hood = Path()
          ..moveTo(35 * _u, 38 * _u)
          ..quadraticBezierTo(32 * _u, 16 * _u, 50 * _u, 15 * _u)
          ..quadraticBezierTo(68 * _u, 16 * _u, 65 * _u, 38 * _u)
          ..quadraticBezierTo(62 * _u, 26 * _u, 50 * _u, 25 * _u)
          ..quadraticBezierTo(38 * _u, 26 * _u, 35 * _u, 38 * _u)
          ..close();
        _c.drawPath(hood, _fill(a));
        _c.drawPath(hood, _stroke(b, 1.2));
        break;
      case 2: // Gorro con pluma
        _c.drawArc(
          Rect.fromCircle(center: _p(50, 28), radius: 15 * _u),
          math.pi,
          math.pi,
          true,
          _fill(a),
        );
        _c.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(34 * _u, 25 * _u, 32 * _u, 5 * _u),
              Radius.circular(2.5 * _u)),
          _fill(a),
        );
        final feather = Path()
          ..moveTo(62 * _u, 26 * _u)
          ..quadraticBezierTo(70 * _u, 12 * _u, 76 * _u, 8 * _u)
          ..quadraticBezierTo(72 * _u, 18 * _u, 66 * _u, 27 * _u)
          ..close();
        _c.drawPath(feather, _fill(b));
        break;
      case 3: // Casco de hierro
        _c.drawArc(
          Rect.fromCircle(center: _p(50, 30), radius: 15 * _u),
          math.pi,
          math.pi,
          true,
          _fill(a),
        );
        _c.drawRect(
            Rect.fromLTWH(48 * _u, 30 * _u, 4 * _u, 10 * _u), _fill(a));
        _c.drawLine(_p(36, 30), _p(64, 30), _stroke(b, 1.6));
        break;
      case 4: // Yelmo alado
        _c.drawArc(
          Rect.fromCircle(center: _p(50, 29), radius: 15 * _u),
          math.pi,
          math.pi,
          true,
          _fill(a),
        );
        final wingL = Path()
          ..moveTo(36 * _u, 27 * _u)
          ..lineTo(22 * _u, 14 * _u)
          ..lineTo(34 * _u, 22 * _u)
          ..close();
        final wingR = Path()
          ..moveTo(64 * _u, 27 * _u)
          ..lineTo(78 * _u, 14 * _u)
          ..lineTo(66 * _u, 22 * _u)
          ..close();
        _c.drawPath(wingL, _fill(b));
        _c.drawPath(wingR, _fill(b));
        break;
      case 5: // Corona
        final crown = Path()
          ..moveTo(38 * _u, 24 * _u)
          ..lineTo(38 * _u, 16 * _u)
          ..lineTo(44 * _u, 21 * _u)
          ..lineTo(50 * _u, 13 * _u)
          ..lineTo(56 * _u, 21 * _u)
          ..lineTo(62 * _u, 16 * _u)
          ..lineTo(62 * _u, 24 * _u)
          ..close();
        _c.drawPath(crown, _fill(const Color(0xFFD4AF37)));
        _c.drawCircle(_p(50, 20), 2.2 * _u, _fill(a));
        _c.drawLine(_p(38, 24), _p(62, 24), _stroke(b, 1.4));
        break;
    }
  }

  // ---- Reliquias ----
  void _drawRelic(GearItem relic) {
    final a = relic.colorA;
    final b = relic.colorB;
    switch (relic.variant) {
      case 1: // Brújula
        if (relic.rarity == Rarity.legendario) {
          final glow = Paint()
            ..color = a.withValues(alpha: 0.45)
            ..maskFilter =
                const ui.MaskFilter.blur(ui.BlurStyle.normal, 6)
            ..isAntiAlias = true;
          _c.drawCircle(_p(80, 64), 9 * _u, glow);
        }
        _c.drawCircle(_p(80, 64), 7 * _u, _fill(a));
        _c.drawCircle(_p(80, 64), 5 * _u, _fill(b));
        _c.drawLine(_p(80, 68), _p(80, 60),
            _stroke(const Color(0xFFC94F4F), 1.6));
        break;
      case 2: // Mapa enrollado
        _c.save();
        _c.translate(80 * _u, 64 * _u);
        _c.rotate(-0.5);
        _c.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromCenter(
                  center: Offset.zero, width: 8 * _u, height: 22 * _u),
              Radius.circular(3 * _u)),
          _fill(a),
        );
        _c.drawLine(Offset(-4 * _u, -5 * _u), Offset(4 * _u, -5 * _u),
            _stroke(b, 1.6));
        _c.drawLine(Offset(-4 * _u, 5 * _u), Offset(4 * _u, 5 * _u),
            _stroke(b, 1.6));
        _c.restore();
        break;
      case 3: // Farol
        final glow = Paint()
          ..color = b.withValues(alpha: 0.5)
          ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 7)
          ..isAntiAlias = true;
        _c.drawCircle(_p(80, 66), 8 * _u, glow);
        _c.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromCenter(
                  center: _p(80, 66), width: 10 * _u, height: 14 * _u),
              Radius.circular(2.5 * _u)),
          _fill(a),
        );
        _c.drawCircle(_p(80, 66), 3.2 * _u, _fill(b));
        _c.drawLine(_p(76, 58), _p(84, 58), _stroke(a, 1.6));
        break;
      case 4: // Catalejo
        _c.save();
        _c.translate(80 * _u, 64 * _u);
        _c.rotate(-0.8);
        _c.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromCenter(
                  center: Offset.zero, width: 7 * _u, height: 16 * _u),
              Radius.circular(2 * _u)),
          _fill(a),
        );
        _c.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromCenter(
                  center: Offset(0, -10 * _u), width: 5 * _u, height: 8 * _u),
              Radius.circular(1.5 * _u)),
          _fill(b),
        );
        _c.restore();
        break;
      case 5: // Estandarte
        _c.drawLine(
            _p(84, 88), _p(84, 40), _stroke(const Color(0xFF6E4F2F), 2.2));
        final flag = Path()
          ..moveTo(84 * _u, 42 * _u)
          ..lineTo(98 * _u, 46 * _u)
          ..lineTo(84 * _u, 54 * _u)
          ..close();
        _c.drawPath(flag, _fill(a));
        _c.drawCircle(_p(89, 47), 1.8 * _u, _fill(b));
        break;
      case 6: // Martillo de herrero
        _c.save();
        _c.translate(80 * _u, 66 * _u);
        _c.rotate(-0.6);
        // mango
        _c.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromCenter(
                  center: Offset(0, 4 * _u), width: 4 * _u, height: 20 * _u),
              Radius.circular(2 * _u)),
          _fill(b),
        );
        // cabeza
        _c.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromCenter(
                  center: Offset(0, -7 * _u),
                  width: 14 * _u,
                  height: 8 * _u),
              Radius.circular(2 * _u)),
          _fill(a),
        );
        _c.restore();
        break;
      case 7: // Silbato con nota
        _c.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromCenter(
                  center: _p(79, 66), width: 12 * _u, height: 6 * _u),
              Radius.circular(3 * _u)),
          _fill(a),
        );
        _c.drawCircle(_p(84, 68), 3.4 * _u, _fill(a));
        _c.drawCircle(_p(84, 68), 1.6 * _u, _fill(b));
        // notita musical
        _c.drawLine(_p(88, 56), _p(88, 62), _stroke(b, 1.4));
        _c.drawCircle(_p(87, 62.5), 1.6 * _u, _fill(b));
        break;
      case 8: // Pluma de escriba
        _c.save();
        _c.translate(80 * _u, 64 * _u);
        _c.rotate(0.5);
        final quill = Path()
          ..moveTo(0, 10 * _u)
          ..quadraticBezierTo(-5 * _u, 0, -2 * _u, -10 * _u)
          ..quadraticBezierTo(1 * _u, -13 * _u, 3 * _u, -10 * _u)
          ..quadraticBezierTo(4 * _u, 0, 0, 10 * _u)
          ..close();
        _c.drawPath(quill, _fill(a));
        _c.drawLine(Offset(0, 10 * _u), Offset(1 * _u, 13 * _u),
            _stroke(b, 1.6));
        _c.restore();
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _AvatarPainter oldDelegate) => true;
}
