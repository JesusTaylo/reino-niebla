import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../util/geo.dart';

class RouteResult {
  final List<LatLng> points;
  final double meters;
  const RouteResult(this.points, this.meters);
}

/// Genera rutas caminables reales usando servidores públicos de ruteo
/// sobre datos de OpenStreetMap.
class RoutingService {
  static const _userAgent = 'ReinoDeNiebla/0.1 (juego fitness personal)';

  /// Genera una ruta circular (sales y vuelves al mismo punto) de
  /// aproximadamente [targetMeters]. Devuelve null si no se pudo.
  static Future<RouteResult?> generateLoop(
    LatLng start,
    double targetMeters, {
    math.Random? rng,
  }) async {
    final random = rng ?? math.Random();
    // Radio inicial estimado: la ruta de 3 puntos sobre un círculo de radio r
    // mide aproximadamente 6.5 * r caminando por calles.
    var radius = targetMeters / 6.5;
    final baseBearing = random.nextDouble() * 360.0;

    for (var attempt = 0; attempt < 4; attempt++) {
      final a = destinationPoint(start, radius, baseBearing);
      final b = destinationPoint(start, radius, baseBearing + 120);
      final result = await _route([start, a, b, start]);
      if (result == null || result.points.length < 2) {
        // Prueba con otro rumbo por si caímos en zona sin calles.
        radius *= 0.9;
        continue;
      }
      final ratio = result.meters / targetMeters;
      if (ratio >= 0.7 && ratio <= 1.35) {
        return result;
      }
      // Ajusta el radio proporcionalmente y reintenta.
      radius = (radius / ratio).clamp(80.0, 4000.0);
    }
    return null;
  }

  static Future<RouteResult?> _route(List<LatLng> waypoints) async {
    final valhalla = await _valhallaRoute(waypoints);
    if (valhalla != null) return valhalla;
    return _osrmRoute(waypoints);
  }

  /// Servidor público de Valhalla (perfil peatón) de la comunidad OSM.
  static Future<RouteResult?> _valhallaRoute(List<LatLng> waypoints) async {
    try {
      final body = jsonEncode({
        'locations': waypoints
            .map((p) => {'lat': p.latitude, 'lon': p.longitude})
            .toList(),
        'costing': 'pedestrian',
        'units': 'kilometers',
      });
      final resp = await http
          .post(
            Uri.parse('https://valhalla1.openstreetmap.de/route'),
            headers: {
              'Content-Type': 'application/json',
              'User-Agent': _userAgent,
            },
            body: body,
          )
          .timeout(const Duration(seconds: 14));
      if (resp.statusCode != 200) return null;
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final trip = data['trip'] as Map<String, dynamic>?;
      if (trip == null) return null;
      final legs = (trip['legs'] as List?) ?? [];
      final points = <LatLng>[];
      for (final leg in legs) {
        final shape = (leg as Map)['shape'] as String?;
        if (shape == null) continue;
        final decoded = decodePolyline(shape, precision: 6);
        if (points.isNotEmpty && decoded.isNotEmpty) {
          decoded.removeAt(0);
        }
        points.addAll(decoded);
      }
      if (points.length < 2) return null;
      final summary = trip['summary'] as Map<String, dynamic>?;
      final km = (summary?['length'] as num?)?.toDouble();
      final meters = km != null ? km * 1000.0 : pathLengthMeters(points);
      return RouteResult(points, meters);
    } catch (_) {
      return null;
    }
  }

  /// Respaldo: servidor demo de OSRM.
  static Future<RouteResult?> _osrmRoute(List<LatLng> waypoints) async {
    try {
      final coords = waypoints
          .map((p) => '${p.longitude},${p.latitude}')
          .join(';');
      final url =
          'https://router.project-osrm.org/route/v1/foot/$coords'
          '?overview=full&geometries=geojson';
      final resp = await http.get(
        Uri.parse(url),
        headers: {'User-Agent': _userAgent},
      ).timeout(const Duration(seconds: 14));
      if (resp.statusCode != 200) return null;
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final routes = (data['routes'] as List?) ?? [];
      if (routes.isEmpty) return null;
      final route = routes.first as Map<String, dynamic>;
      final geometry = route['geometry'] as Map<String, dynamic>?;
      final coordsRaw = (geometry?['coordinates'] as List?) ?? [];
      final points = coordsRaw
          .map((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()))
          .toList();
      if (points.length < 2) return null;
      final meters =
          (route['distance'] as num?)?.toDouble() ?? pathLengthMeters(points);
      return RouteResult(points, meters);
    } catch (_) {
      return null;
    }
  }
}
