import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../util/geo.dart';

/// Capa de niebla de guerra: cubre el mapa y se despeja en las zonas
/// que el jugador ya exploró.
class FogLayer extends StatelessWidget {
  final List<LatLng> revealed;

  /// Día en que cada punto fue visitado por última vez (paralelo a
  /// [revealed]). Los puntos viejos se ven parcialmente re-cubiertos:
  /// la Niebla regresa a lo que se deja de caminar.
  final List<int> revealedDays;
  final int today;
  final int staleAfterDays;

  final LatLng? playerPosition;
  final double radiusMeters;
  final Color fogColor;

  const FogLayer({
    super.key,
    required this.revealed,
    required this.revealedDays,
    required this.today,
    this.staleAfterDays = 10,
    required this.playerPosition,
    this.radiusMeters = 55,
    // Niebla translúcida: el mapa sin explorar se ve oscurecido, no tapado.
    this.fogColor = const Color(0x8F0A0E24),
  });

  @override
  Widget build(BuildContext context) {
    final camera = MapCamera.of(context);
    return IgnorePointer(
      child: CustomPaint(
        size: Size.infinite,
        painter: _FogPainter(
          camera: camera,
          revealed: revealed,
          revealedDays: revealedDays,
          today: today,
          staleAfterDays: staleAfterDays,
          playerPosition: playerPosition,
          radiusMeters: radiusMeters,
          fogColor: fogColor,
        ),
      ),
    );
  }
}

class _FogPainter extends CustomPainter {
  final MapCamera camera;
  final List<LatLng> revealed;
  final List<int> revealedDays;
  final int today;
  final int staleAfterDays;
  final LatLng? playerPosition;
  final double radiusMeters;
  final Color fogColor;

  _FogPainter({
    required this.camera,
    required this.revealed,
    required this.revealedDays,
    required this.today,
    required this.staleAfterDays,
    required this.playerPosition,
    required this.radiusMeters,
    required this.fogColor,
  });

  Offset _project(LatLng p) => camera.latLngToScreenOffset(p);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    // Radio de revelado en píxeles según el zoom actual.
    final center = camera.center;
    final edge = destinationPoint(center, radiusMeters, 90);
    final pixRadius = (_project(edge) - _project(center)).distance;

    // Si el zoom está muy lejos, los agujeros serían subpíxel: pintamos
    // niebla ligera uniforme y listo.
    if (pixRadius < 1.5) {
      canvas.drawRect(rect, Paint()..color = fogColor.withValues(alpha: 0.30));
      return;
    }

    canvas.saveLayer(rect, Paint());
    canvas.drawRect(rect, Paint()..color = fogColor);

    // Sin MaskFilter: el desenfoque + BlendMode.clear falla en algunos
    // renderizadores Android (Impeller) y la niebla queda sólida.
    final clear = Paint()
      ..blendMode = BlendMode.clear
      ..isAntiAlias = true;

    // Solo proyectamos puntos dentro (o cerca) de la pantalla.
    final bounds = camera.visibleBounds;
    final margin = radiusMeters * 2.5;
    final latMargin = margin / 111320.0;

    for (var i = 0; i < revealed.length; i++) {
      final p = revealed[i];
      if (p.latitude < bounds.south - latMargin ||
          p.latitude > bounds.north + latMargin ||
          p.longitude < bounds.west - latMargin * 2 ||
          p.longitude > bounds.east + latMargin * 2) {
        continue;
      }
      final age =
          i < revealedDays.length ? today - revealedDays[i] : 0;
      if (age >= staleAfterDays) {
        // La Niebla regresa: el claro se encoge (revisitar lo restaura).
        canvas.drawCircle(_project(p), pixRadius * 0.55, clear);
      } else {
        canvas.drawCircle(_project(p), pixRadius, clear);
      }
    }

    // Alrededor del jugador siempre hay una burbuja amplia de visibilidad,
    // con un borde suave hecho con anillos concéntricos (sin blur).
    final player = playerPosition;
    if (player != null) {
      final p = _project(player);
      canvas.drawCircle(p, pixRadius * 3.0, clear);
      for (var i = 1; i <= 3; i++) {
        final ring = Paint()
          ..blendMode = BlendMode.clear
          ..isAntiAlias = true
          ..color = Colors.white.withValues(alpha: 1.0 - i * 0.25);
        canvas.drawCircle(p, pixRadius * (3.0 + i * 0.22), ring);
      }
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _FogPainter oldDelegate) => true;
}
