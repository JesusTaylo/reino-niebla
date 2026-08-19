import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

const double earthRadiusMeters = 6371000.0;

double _degToRad(double deg) => deg * math.pi / 180.0;
double _radToDeg(double rad) => rad * 180.0 / math.pi;

/// Distancia en metros entre dos coordenadas (haversine).
double haversineMeters(LatLng a, LatLng b) {
  final dLat = _degToRad(b.latitude - a.latitude);
  final dLng = _degToRad(b.longitude - a.longitude);
  final la1 = _degToRad(a.latitude);
  final la2 = _degToRad(b.latitude);
  final h = math.pow(math.sin(dLat / 2), 2) +
      math.cos(la1) * math.cos(la2) * math.pow(math.sin(dLng / 2), 2);
  return 2 * earthRadiusMeters * math.asin(math.min(1.0, math.sqrt(h)));
}

/// Punto destino partiendo de [from], avanzando [distanceMeters] con rumbo
/// [bearingDeg] (0 = norte, 90 = este).
LatLng destinationPoint(LatLng from, double distanceMeters, double bearingDeg) {
  final delta = distanceMeters / earthRadiusMeters;
  final theta = _degToRad(bearingDeg);
  final phi1 = _degToRad(from.latitude);
  final lambda1 = _degToRad(from.longitude);

  final sinPhi2 = math.sin(phi1) * math.cos(delta) +
      math.cos(phi1) * math.sin(delta) * math.cos(theta);
  final phi2 = math.asin(sinPhi2);
  final y = math.sin(theta) * math.sin(delta) * math.cos(phi1);
  final x = math.cos(delta) - math.sin(phi1) * sinPhi2;
  final lambda2 = lambda1 + math.atan2(y, x);

  return LatLng(_radToDeg(phi2), _radToDeg(lambda2));
}

/// Longitud total en metros de una polilínea.
double pathLengthMeters(List<LatLng> points) {
  var total = 0.0;
  for (var i = 1; i < points.length; i++) {
    total += haversineMeters(points[i - 1], points[i]);
  }
  return total;
}

/// Decodifica una polilínea codificada (formato Google/Valhalla).
/// Valhalla usa precisión 1e6, OSRM/Google 1e5.
List<LatLng> decodePolyline(String encoded, {int precision = 6}) {
  final factor = math.pow(10, precision).toDouble();
  final points = <LatLng>[];
  var index = 0;
  var lat = 0;
  var lng = 0;

  while (index < encoded.length) {
    var result = 0;
    var shift = 0;
    int b;
    do {
      b = encoded.codeUnitAt(index++) - 63;
      result |= (b & 0x1f) << shift;
      shift += 5;
    } while (b >= 0x20);
    lat += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);

    result = 0;
    shift = 0;
    do {
      b = encoded.codeUnitAt(index++) - 63;
      result |= (b & 0x1f) << shift;
      shift += 5;
    } while (b >= 0x20);
    lng += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);

    points.add(LatLng(lat / factor, lng / factor));
  }
  return points;
}

String formatKm(double meters) {
  final km = meters / 1000.0;
  if (km < 10) {
    return '${km.toStringAsFixed(1)} km';
  }
  return '${km.round()} km';
}
