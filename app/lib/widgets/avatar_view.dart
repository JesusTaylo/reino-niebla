import 'package:flutter/material.dart';

import '../models/items.dart';
import '../models/player_state.dart';

/// Paleta de tonos de piel disponibles en el Espejo Mágico.
/// (Coincide con los recoloreos horneados en assets/chars/.)
const List<Color> skinPalette = [
  Color(0xFFF5D7B8),
  Color(0xFFE8B98A),
  Color(0xFFD29B6E),
  Color(0xFFB07B4F),
  Color(0xFF8B5A33),
  Color(0xFF5F3C22),
];

/// Paleta de colores de pelo. (Coincide con los tintes horneados.)
const List<Color> hairPalette = [
  Color(0xFF241D18), // negro
  Color(0xFF4A3220), // café oscuro
  Color(0xFF7A5230), // castaño
  Color(0xFFD9A94A), // rubio
  Color(0xFFB4502E), // pelirrojo
  Color(0xFFB9B9B9), // canoso
  Color(0xFF4E6ED6), // azul místico
];

/// 0 = rapado (sin capa de pelo); 1..10 = estilos de la hoja de arte.
const List<String> hairStyleNames = [
  'Rapado',
  'Corto',
  'Hacia atrás',
  'Media melena',
  'Melena lisa',
  'Melena suelta',
  'Trenza',
  'Rizado',
  'Despeinado',
  'Ondulado',
  'Recogido',
];

const List<String> facialHairNames = [
  'Sin vello',
  'Bigote',
  'Candado',
  'Barba completa',
];

// Geometría del lienzo horneado en assets/chars/ (110 x 200,
// cabeza centrada en x=55, barbilla en y=60).
const double _kW = 110;
const double _kH = 200;
// Caja de la cabeza (con margen para el pelo) para el modo busto.
const double _kHeadLeft = 25;
const double _kHeadTop = 4;
const double _kHeadSize = 60;

/// Avatar del explorador con arte pixelado real (capas horneadas).
///
/// [equipped] se conserva para el arte de equipo (próxima fase);
/// hoy el retrato muestra el cuerpo, peinado y vello elegidos.
class AvatarView extends StatelessWidget {
  final Map<GearSlot, GearItem?> equipped;
  final Appearance appearance;

  /// true = solo la cabeza (para el medallón del mapa).
  final bool bust;

  const AvatarView({
    super.key,
    required this.equipped,
    required this.appearance,
    this.bust = false,
  });

  List<String> get _layers {
    final a = appearance;
    final g = a.female ? 'f' : 'm';
    final skin = a.skinTone.clamp(0, skinPalette.length - 1);
    final color = a.hairColor.clamp(0, hairPalette.length - 1);
    return [
      'assets/chars/base_${g}_$skin.png',
      if (a.hairStyle > 0 && a.hairStyle <= 10)
        'assets/chars/hair_${a.hairStyle - 1}_$color.png',
      if (!a.female && a.facialHair > 0 && a.facialHair <= 3)
        'assets/chars/facial_${a.facialHair}_$color.png',
    ];
  }

  Widget _stack() {
    return Stack(
      fit: StackFit.expand,
      children: [
        for (final path in _layers)
          Image.asset(
            path,
            fit: BoxFit.fill,
            filterQuality: FilterQuality.none,
            errorBuilder: (c, e, s) => const SizedBox.shrink(),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (bust) {
      return LayoutBuilder(builder: (context, cons) {
        final side = cons.maxWidth.isFinite
            ? cons.maxWidth
            : (cons.maxHeight.isFinite ? cons.maxHeight : 34.0);
        final s = side / _kHeadSize;
        return ClipRect(
          child: Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              Positioned(
                left: -_kHeadLeft * s,
                top: -_kHeadTop * s,
                width: _kW * s,
                height: _kH * s,
                child: _stack(),
              ),
            ],
          ),
        );
      });
    }
    return Center(
      child: AspectRatio(
        aspectRatio: _kW / _kH,
        child: _stack(),
      ),
    );
  }
}
