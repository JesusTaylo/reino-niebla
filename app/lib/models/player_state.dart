import 'package:latlong2/latlong.dart';

import 'campaign.dart';

/// Apariencia física del explorador (elegida en el Espejo Mágico).
class Appearance {
  /// false = hombre, true = mujer.
  bool female;
  int skinTone; // índice en la paleta de piel
  int hairStyle; // 0 rapado, 1 corto, 2 despeinado, 3 media melena, 4 larga, 5 chongo
  int hairColor; // índice en la paleta de pelo
  int facialHair; // 0 nada, 1 bigote, 2 candado, 3 barba completa

  Appearance({
    this.female = false,
    this.skinTone = 1,
    this.hairStyle = 1,
    this.hairColor = 0,
    this.facialHair = 0,
  });

  Appearance copy() => Appearance(
        female: female,
        skinTone: skinTone,
        hairStyle: hairStyle,
        hairColor: hairColor,
        facialHair: facialHair,
      );

  Map<String, dynamic> toJson() => {
        'female': female,
        'skinTone': skinTone,
        'hairStyle': hairStyle,
        'hairColor': hairColor,
        'facialHair': facialHair,
      };

  factory Appearance.fromJson(Map<String, dynamic> json) => Appearance(
        female: json['female'] == true,
        skinTone: (json['skinTone'] as num?)?.toInt() ?? 1,
        hairStyle: (json['hairStyle'] as num?)?.toInt() ?? 1,
        hairColor: (json['hairColor'] as num?)?.toInt() ?? 0,
        facialHair: (json['facialHair'] as num?)?.toInt() ?? 0,
      );
}

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

  /// Nombre elegido por el jugador ('' = aún no creó su personaje).
  String name;
  Appearance appearance;

  /// Materiales de caza (id -> cantidad).
  Map<String, int> materials;

  /// Bestiario (id de criatura -> victorias).
  Map<String, int> bestiary;
  int battlesWon;

  /// La Campaña de la Niebla.
  CampaignState campaign;

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
    this.name = '',
    Appearance? appearance,
    Map<String, int>? materials,
    Map<String, int>? bestiary,
    this.battlesWon = 0,
    CampaignState? campaign,
  })  : medals = medals ?? [],
        inventory = inventory ?? [],
        equipped = equipped ?? {},
        explored = explored ?? [],
        appearance = appearance ?? Appearance(),
        materials = materials ?? {},
        bestiary = bestiary ?? {},
        campaign = campaign ?? CampaignState();

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
        'name': name,
        'appearance': appearance.toJson(),
        'materials': materials,
        'bestiary': bestiary,
        'battlesWon': battlesWon,
        'campaign': campaign.toJson(),
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
      name: json['name'] as String? ?? '',
      appearance: json['appearance'] is Map
          ? Appearance.fromJson(
              (json['appearance'] as Map).cast<String, dynamic>())
          : null,
      materials: ((json['materials'] as Map?) ?? {})
          .map((k, v) => MapEntry(k.toString(), (v as num).toInt())),
      bestiary: ((json['bestiary'] as Map?) ?? {})
          .map((k, v) => MapEntry(k.toString(), (v as num).toInt())),
      battlesWon: (json['battlesWon'] as num?)?.toInt() ?? 0,
      campaign: json['campaign'] is Map
          ? CampaignState.fromJson(
              (json['campaign'] as Map).cast<String, dynamic>())
          : null,
    );
  }
}
