import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

/// Puestos de avanzada: estructuras del reino repartidas por el mundo.
/// Se generan de forma DETERMINISTA a partir de la posición (sin internet
/// ni servidor): la misma celda del mundo siempre produce el mismo puesto.
class Outpost {
  final String id;
  final String name;
  final int type; // 0 atalaya, 1 santuario, 2 obelisco, 3 puesto
  final LatLng pos;

  const Outpost({
    required this.id,
    required this.name,
    required this.type,
    required this.pos,
  });

  String get typeName {
    switch (type) {
      case 0:
        return 'Atalaya';
      case 1:
        return 'Santuario';
      case 2:
        return 'Obelisco';
      default:
        return 'Puesto de avanzada';
    }
  }

  String get emoji {
    switch (type) {
      case 0:
        return '🗼';
      case 1:
        return '⛩️';
      case 2:
        return '🗿';
      default:
        return '🏕️';
    }
  }
}

const List<String> _prefixes = [
  'Atalaya',
  'Santuario',
  'Obelisco',
  'Puesto',
];

const List<String> _suffixes = [
  'del Alba',
  'del Ocaso',
  'del Peregrino',
  'de la Vigilia',
  'del Cuervo',
  'de la Espiga',
  'del Roble',
  'de las Campanas',
  'del Susurro',
  'de la Estrella',
  'de los Vientos',
  'de la Fuente',
  'del Eco',
  'de la Luna',
  'del Primer Paso',
  'de la Promesa',
];

/// Tamaño de celda en metros (~separación entre puestos).
const double outpostCellMeters = 450;

int _hash(int ix, int iy) {
  var h = ix * 73856093 ^ iy * 19349663;
  h = h & 0x7fffffff;
  // Mezcla extra para que celdas vecinas no se parezcan.
  h = (h ^ (h >> 13)) * 1274126177 & 0x7fffffff;
  return h;
}

/// Genera los puestos dentro de un rectángulo de coordenadas.
/// [maxCount] evita saturar el mapa si el área es enorme.
List<Outpost> outpostsInArea(
  double south,
  double west,
  double north,
  double east, {
  int maxCount = 80,
}) {
  final result = <Outpost>[];
  final latCell = outpostCellMeters / 111320.0;
  final midLat = (south + north) / 2;
  final lngCell = outpostCellMeters /
      (111320.0 * math.cos(midLat * math.pi / 180).abs().clamp(0.2, 1.0));

  final iy0 = (south / latCell).floor();
  final iy1 = (north / latCell).ceil();
  final ix0 = (west / lngCell).floor();
  final ix1 = (east / lngCell).ceil();

  for (var iy = iy0; iy <= iy1; iy++) {
    for (var ix = ix0; ix <= ix1; ix++) {
      final h = _hash(ix, iy);
      // ~30% de las celdas no tienen puesto: respiro entre estructuras.
      if (h % 10 < 3) continue;

      final fx = 0.2 + ((h >> 4) % 600) / 1000.0; // 0.2 .. 0.8
      final fy = 0.2 + ((h >> 14) % 600) / 1000.0;
      final lat = (iy + fy) * latCell;
      final lng = (ix + fx) * lngCell;
      final type = (h >> 8) % 4;
      final name =
          '${_prefixes[type]} ${_suffixes[(h >> 20) % _suffixes.length]}';

      result.add(Outpost(
        id: '$ix:$iy',
        name: name,
        type: type,
        pos: LatLng(lat, lng),
      ));
      if (result.length >= maxCount) return result;
    }
  }
  return result;
}

/// Día actual como número entero (para cooldowns y niebla que regresa).
int dayNumber([DateTime? when]) =>
    (when ?? DateTime.now()).difference(DateTime(2020, 1, 1)).inDays;
