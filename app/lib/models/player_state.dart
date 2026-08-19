import 'package:latlong2/latlong.dart';

/// Estado persistente del jugador.
class PlayerState {
  int xp;
  int expeditionsDone;
  int longExpeditionsDone;
  double totalMeters;
  List<String> medals;
  List<String> inventory;

  /// slot (name del enum) -> itemId
  Map<String, String> equipped;

  /// Puntos del mapa ya revelados (niebla despejada).
  List<LatLng> explored;

  bool onboardingDone;

  PlayerState({
    this.xp = 0,
    this.expeditionsDone = 0,
    this.longExpeditionsDone = 0,
    this.totalMeters = 0,
    List<String>? medals,
    List<String>? inventory,
    Map<String, String>? equipped,
    List<LatLng>? explored,
    this.onboardingDone = false,
  })  : medals = medals ?? [],
        inventory = inventory ?? [],
        equipped = equipped ?? {},
        explored = explored ?? [];

  factory PlayerState.newPlayer() {
    return PlayerState(
      inventory: ['tunica_lino', 'capa_viajero', 'brujula_laton'],
      equipped: {
        'tunica': 'tunica_lino',
        'capa': 'capa_viajero',
        'reliquia': 'brujula_laton',
      },
    );
  }

  // ---- Niveles ----

  /// XP acumulada necesaria para alcanzar el nivel [l].
  static int xpForLevel(int l) => 300 * l * (l - 1);

  int get level {
    var l = 1;
    while (xp >= xpForLevel(l + 1)) {
      l++;
    }
    return l;
  }

  /// Progreso 0..1 dentro del nivel actual.
  double get levelProgress {
    final l = level;
    final cur = xpForLevel(l);
    final next = xpForLevel(l + 1);
    if (next == cur) return 1;
    return ((xp - cur) / (next - cur)).clamp(0.0, 1.0);
  }

  int get xpToNextLevel => xpForLevel(level + 1) - xp;

  String get title {
    final l = level;
    if (l >= 20) return 'Leyenda del Reino';
    if (l >= 16) return 'Gran Explorador';
    if (l >= 12) return 'Cartógrafo Real';
    if (l >= 8) return 'Explorador Veterano';
    if (l >= 5) return 'Cartógrafo del Gremio';
    if (l >= 3) return 'Explorador Novato';
    return 'Aprendiz de Cartógrafo';
  }

  // ---- Serialización ----

  Map<String, dynamic> toJson() => {
        'xp': xp,
        'expeditionsDone': expeditionsDone,
        'longExpeditionsDone': longExpeditionsDone,
        'totalMeters': totalMeters,
        'medals': medals,
        'inventory': inventory,
        'equipped': equipped,
        'explored': explored
            .map((p) => [
                  double.parse(p.latitude.toStringAsFixed(6)),
                  double.parse(p.longitude.toStringAsFixed(6)),
                ])
            .toList(),
        'onboardingDone': onboardingDone,
      };

  factory PlayerState.fromJson(Map<String, dynamic> json) {
    final exploredRaw = (json['explored'] as List?) ?? [];
    return PlayerState(
      xp: (json['xp'] as num?)?.toInt() ?? 0,
      expeditionsDone: (json['expeditionsDone'] as num?)?.toInt() ?? 0,
      longExpeditionsDone: (json['longExpeditionsDone'] as num?)?.toInt() ?? 0,
      totalMeters: (json['totalMeters'] as num?)?.toDouble() ?? 0,
      medals: ((json['medals'] as List?) ?? []).cast<String>().toList(),
      inventory: ((json['inventory'] as List?) ?? []).cast<String>().toList(),
      equipped: ((json['equipped'] as Map?) ?? {})
          .map((k, v) => MapEntry(k.toString(), v.toString())),
      explored: exploredRaw
          .map((e) => LatLng(
                (e[0] as num).toDouble(),
                (e[1] as num).toDouble(),
              ))
          .toList(),
      onboardingDone: json['onboardingDone'] == true,
    );
  }
}
