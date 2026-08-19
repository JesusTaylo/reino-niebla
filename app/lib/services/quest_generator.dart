import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

import '../models/quest.dart';
import 'routing.dart';

/// Genera nombres, historias y rutas para las expediciones.
class QuestGenerator {
  static final _rng = math.Random();

  static const _templates = [
    'La Senda de {n}',
    'Expedición a {n}',
    'El Camino de {n}',
    'Patrulla de {n}',
    'La Ruta de {n}',
    'Travesía de {n}',
    'En Busca de {n}',
    'Misión: {n}',
  ];

  static const _places = [
    'el Mensajero Real',
    'las Brumas Grises',
    'el Bastión Olvidado',
    'la Torre del Vigía',
    'el Puente de Plata',
    'los Faroles Antiguos',
    'la Puerta del Alba',
    'el Sendero del Halcón',
    'las Murallas Perdidas',
    'el Mercado de Medianoche',
    'la Fuente del Peregrino',
    'el Bosque de Piedra',
    'las Campanas Lejanas',
    'el Cruce de los Vientos',
    'la Colina del Dragón Dormido',
    'el Archivo Real',
    'los Jardines Sumergidos',
    'la Estrella del Norte',
  ];

  static const _flavors = [
    'Los cartógrafos del gremio aseguran que la Niebla es débil en esta zona. Es tu oportunidad de reclamarla.',
    'Un mensajero desapareció por estas calles hace cien años. Recorre su ruta y devuélvela al mapa del reino.',
    'El Consejo Real necesita ojos en este sector. Camina la ruta y reporta lo que la Niebla escondía.',
    'Se dice que al final de este camino un cofre espera a quien lo recorra completo, paso a paso.',
    'La Niebla avanza cuando nadie camina. Hoy retrocede ante ti.',
    'Cada calle que pisas vuelve a existir en el mapa del reino. Los escribas ya preparan la tinta.',
    'Los vigías reportan movimiento en la bruma. Solo un explorador a pie puede confirmar el terreno.',
    'Esta ruta aparece en un mapa quemado del Archivo Real. Compruébala con tus propios pies.',
  ];

  /// Distancias objetivo por tier (metros).
  static const targetMeters = [1000.0, 3000.0, 5000.0];

  static String randomName() {
    final t = _templates[_rng.nextInt(_templates.length)];
    final p = _places[_rng.nextInt(_places.length)];
    return t.replaceAll('{n}', p);
  }

  static String randomFlavor() => _flavors[_rng.nextInt(_flavors.length)];

  /// Genera una expedición completa con ruta real desde [start].
  /// Devuelve null si el servicio de rutas no respondió.
  static Future<Quest?> generate(LatLng start, int tier) async {
    final target = targetMeters[tier.clamp(0, 2)];
    final route = await RoutingService.generateLoop(start, target, rng: _rng);
    if (route == null) return null;
    return Quest(
      name: randomName(),
      flavor: randomFlavor(),
      tier: tier,
      route: route.points,
      routeMeters: route.meters,
    );
  }
}
