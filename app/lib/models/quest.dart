import 'package:latlong2/latlong.dart';

/// Una expedición: ruta real generada por las calles de la ciudad.
class Quest {
  final String name;
  final String flavor;

  /// 0 = corta, 1 = media, 2 = larga.
  final int tier;
  final List<LatLng> route;
  final double routeMeters;

  double walkedMeters;
  List<LatLng> trail;
  DateTime startedAt;

  Quest({
    required this.name,
    required this.flavor,
    required this.tier,
    required this.route,
    required this.routeMeters,
    this.walkedMeters = 0,
    List<LatLng>? trail,
    DateTime? startedAt,
  })  : trail = trail ?? [],
        startedAt = startedAt ?? DateTime.now();

  String get tierLabel {
    switch (tier) {
      case 0:
        return 'Corta';
      case 1:
        return 'Media';
      default:
        return 'Larga';
    }
  }

  double get progress =>
      routeMeters <= 0 ? 0 : (walkedMeters / routeMeters).clamp(0.0, 1.0);

  LatLng get goal => route.isEmpty ? const LatLng(0, 0) : route.last;

  Map<String, dynamic> toJson() => {
        'name': name,
        'flavor': flavor,
        'tier': tier,
        'routeMeters': routeMeters,
        'walkedMeters': walkedMeters,
        'startedAt': startedAt.toIso8601String(),
        'route': route.map((p) => [p.latitude, p.longitude]).toList(),
        'trail': trail.map((p) => [p.latitude, p.longitude]).toList(),
      };

  factory Quest.fromJson(Map<String, dynamic> json) {
    List<LatLng> parsePoints(dynamic raw) => ((raw as List?) ?? [])
        .map((e) =>
            LatLng((e[0] as num).toDouble(), (e[1] as num).toDouble()))
        .toList();
    return Quest(
      name: json['name'] as String? ?? 'Expedición',
      flavor: json['flavor'] as String? ?? '',
      tier: (json['tier'] as num?)?.toInt() ?? 0,
      route: parsePoints(json['route']),
      routeMeters: (json['routeMeters'] as num?)?.toDouble() ?? 0,
      walkedMeters: (json['walkedMeters'] as num?)?.toDouble() ?? 0,
      trail: parsePoints(json['trail']),
      startedAt:
          DateTime.tryParse(json['startedAt'] as String? ?? '') ??
              DateTime.now(),
    );
  }
}
