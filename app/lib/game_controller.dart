import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:path_provider/path_provider.dart';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import 'models/bestiary.dart';
import 'models/campaign.dart';
import 'models/items.dart';
import 'models/outposts.dart';
import 'models/medals.dart';
import 'models/player_state.dart';
import 'models/quest.dart';
import 'services/quest_generator.dart';
import 'services/routing.dart';
import 'services/storage.dart';
import 'util/geo.dart';

enum LocationStatus { unknown, ok, serviceOff, denied, deniedForever }

/// Resultado de completar una expedición (para la pantalla de recompensas).
class RewardBundle {
  final Quest quest;
  final int xpGained;
  final GearItem? item;
  final bool duplicate;
  final int duplicateBonusXp;
  final List<Medal> newMedals;
  final int newLevel;
  final bool leveledUp;

  const RewardBundle({
    required this.quest,
    required this.xpGained,
    required this.item,
    required this.duplicate,
    required this.duplicateBonusXp,
    required this.newMedals,
    required this.newLevel,
    required this.leveledUp,
  });
}

/// Botín de una batalla contra una criatura de la bruma.
class BattleSpoils {
  final bool won;
  final int xp;
  final String? materialId;
  final int materialCount;
  final GearItem? gear;
  final List<Medal> newMedals;
  final bool leveledUp;

  const BattleSpoils({
    required this.won,
    required this.xp,
    required this.materialId,
    required this.materialCount,
    required this.gear,
    required this.newMedals,
    required this.leveledUp,
  });
}

/// Controlador central del juego: posición, niebla, expediciones y progreso.
class GameController extends ChangeNotifier {
  PlayerState player = PlayerState.newPlayer();
  Quest? activeQuest;

  LatLng? position;
  double? headingDeg;
  LocationStatus locationStatus = LocationStatus.unknown;
  bool loaded = false;

  /// Recompensa pendiente de mostrar tras completar una expedición.
  RewardBundle? pendingReward;

  /// Capítulo de la campaña listo para leerse (carta lacrada).
  Chapter? pendingChapter;

  /// Escena de misión de Himmel pendiente de mostrar.
  HimmelMission? pendingHimmelScene;

  /// Tras la misión 5: elegir Martillo de Ram o Silbato de Himmel.
  bool reunionRelicPending = false;

  /// Criatura de la bruma que bloquea el camino (si hay encuentro activo).
  Enemy? pendingEncounter;
  double _metersSinceEncounterRoll = 0;
  bool _bossSpawnedThisQuest = false;

  StreamSubscription<Position>? _posSub;
  DateTime _lastSave = DateTime.fromMillisecondsSinceEpoch(0);
  LatLng? _lastTrailPoint;
  DateTime? _lastTrailTime;

  /// Rejilla espacial (~50 m): clave -> índice del punto en explored,
  /// para refrescar su fecha cuando el jugador revisita la zona.
  final Map<String, int> _exploredKeys = {};

  static String _gridKey(LatLng p) =>
      '${(p.latitude * 2000).round()}:${(p.longitude * 2000).round()}';

  /// Días sin visitar tras los cuales la Niebla empieza a regresar.
  static const int fogReturnDays = 10;

  final _rng = math.Random();

  static const double fogRevealRadiusMeters = 55;
  static const double _exploredMinGapMeters = 25;

  // ------------------------------------------------------------------
  // Inicialización
  // ------------------------------------------------------------------

  Future<void> init() async {
    final data = await Storage.load();
    player = data.player;
    activeQuest = data.activeQuest;
    // Migración: partidas viejas no tenían fechas por punto explorado.
    if (player.exploredDays.length != player.explored.length) {
      final today = dayNumber();
      player.exploredDays =
          List<int>.filled(player.explored.length, today, growable: true);
    }
    for (var i = 0; i < player.explored.length; i++) {
      _exploredKeys[_gridKey(player.explored[i])] = i;
    }
    _checkCampaign();
    loaded = true;
    notifyListeners();
    await refreshPermissions();
    if (locationStatus == LocationStatus.ok) {
      await startTracking();
    }
  }

  Future<void> refreshPermissions() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        locationStatus = LocationStatus.serviceOff;
        notifyListeners();
        return;
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      switch (perm) {
        case LocationPermission.always:
        case LocationPermission.whileInUse:
          locationStatus = LocationStatus.ok;
          break;
        case LocationPermission.deniedForever:
          locationStatus = LocationStatus.deniedForever;
          break;
        default:
          locationStatus = LocationStatus.denied;
      }
    } catch (_) {
      locationStatus = LocationStatus.denied;
    }
    notifyListeners();
  }

  // ------------------------------------------------------------------
  // GPS
  // ------------------------------------------------------------------

  Future<void> startTracking() async {
    await _posSub?.cancel();
    final settings = _buildSettings(activeQuest != null);
    try {
      final last = await Geolocator.getLastKnownPosition();
      if (last != null && position == null) {
        position = LatLng(last.latitude, last.longitude);
        notifyListeners();
      }
    } catch (_) {}
    _posSub = Geolocator.getPositionStream(locationSettings: settings).listen(
      _onPosition,
      onError: (_) {},
    );
  }

  LocationSettings _buildSettings(bool questActive) {
    if (defaultTargetPlatform == TargetPlatform.android && questActive) {
      // Con expedición activa usamos un servicio en primer plano para que
      // el rastreo siga aunque se apague la pantalla.
      return AndroidSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 4,
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'Reino de Niebla',
          notificationText: 'Expedición en curso: la Niebla retrocede a tu paso.',
          enableWakeLock: true,
        ),
      );
    }
    return const LocationSettings(
      accuracy: LocationAccuracy.best,
      distanceFilter: 5,
    );
  }

  void _onPosition(Position pos) {
    final p = LatLng(pos.latitude, pos.longitude);
    position = p;
    if (pos.heading.isFinite && pos.heading >= 0) {
      headingDeg = pos.heading;
    }

    // Precisión muy mala: no la usamos para revelar ni contar.
    final accuracyOk = pos.accuracy.isFinite && pos.accuracy <= 40;

    if (accuracyOk) {
      _revealFog(p);
      _trackQuest(p, pos.timestamp);
    }

    _maybeSave();
    notifyListeners();
  }

  void _revealFog(LatLng p) {
    final explored = player.explored;
    final key = _gridKey(p);
    final existing = _exploredKeys[key];
    if (existing != null) {
      // Zona ya revelada: revisitarla ahuyenta a la Niebla de nuevo.
      if (existing < player.exploredDays.length) {
        player.exploredDays[existing] = dayNumber();
      }
      return;
    }
    // Mínima separación con los puntos recientes.
    final start = math.max(0, explored.length - 60);
    for (var i = explored.length - 1; i >= start; i--) {
      if (haversineMeters(explored[i], p) < _exploredMinGapMeters) {
        return;
      }
    }
    _exploredKeys[key] = explored.length;
    explored.add(p);
    player.exploredDays.add(dayNumber());
    _checkFogMedal();
  }

  /// Revela un estallido de niebla alrededor de un punto (puestos).
  void _revealBurst(LatLng center) {
    _revealFogPointForced(center);
    for (var i = 0; i < 6; i++) {
      _revealFogPointForced(destinationPoint(center, 65, i * 60.0));
      _revealFogPointForced(destinationPoint(center, 125, i * 60.0 + 30));
    }
  }

  void _revealFogPointForced(LatLng p) {
    final key = _gridKey(p);
    final existing = _exploredKeys[key];
    if (existing != null) {
      if (existing < player.exploredDays.length) {
        player.exploredDays[existing] = dayNumber();
      }
      return;
    }
    _exploredKeys[key] = player.explored.length;
    player.explored.add(p);
    player.exploredDays.add(dayNumber());
  }

  // ------------------------------------------------------------------
  // Puestos de avanzada
  // ------------------------------------------------------------------

  /// ¿El puesto ya fue activado hoy?
  bool outpostUsedToday(Outpost o) =>
      player.outpostDay[o.id] == dayNumber();

  /// Resultado: null = ok; texto = motivo por el que no se pudo.
  String? activateOutpost(Outpost o) {
    final p = position;
    if (p == null) return 'Aún no encuentro tu posición.';
    if (haversineMeters(p, o.pos) > 45) {
      return 'Acércate más: la bendición se recibe a pie.';
    }
    if (outpostUsedToday(o)) {
      return 'Este lugar ya te bendijo hoy. Vuelve mañana.';
    }

    final firstTime = !player.outpostDay.containsKey(o.id);
    player.outpostDay[o.id] = dayNumber();
    if (firstTime) player.outpostsActivated += 1;

    player.xp += 40;
    _revealBurst(o.pos);

    // A veces el puesto guarda un material olvidado.
    if (_rng.nextInt(100) < 30) {
      final mat = materialCatalog[_rng.nextInt(4)]; // materiales comunes
      player.materials[mat.id] = (player.materials[mat.id] ?? 0) + 1;
    }

    if (player.outpostsActivated >= 10 &&
        !player.medals.contains('peregrino')) {
      player.medals.add('peregrino');
    }
    if (player.outpostsActivated >= 25 &&
        !player.medals.contains('red_reino')) {
      player.medals.add('red_reino');
    }

    Storage.save(player, activeQuest);
    notifyListeners();
    return null;
  }

  void _trackQuest(LatLng p, DateTime timestamp) {
    final quest = activeQuest;
    if (quest == null) return;

    final last = _lastTrailPoint;
    final lastTime = _lastTrailTime;
    if (last == null || lastTime == null) {
      _lastTrailPoint = p;
      _lastTrailTime = timestamp;
      quest.trail.add(p);
      return;
    }

    final segment = haversineMeters(last, p);
    if (segment < 3) return; // ruido de GPS

    final dt = timestamp.difference(lastTime).inMilliseconds / 1000.0;
    final speed = dt > 0 ? segment / dt : 0.0;

    _lastTrailPoint = p;
    _lastTrailTime = timestamp;

    // Salto de GPS o velocidad de vehículo: no cuenta como caminata.
    if (segment > 200 || speed > 4.6) {
      return;
    }

    quest.walkedMeters += segment;
    quest.trail.add(p);

    _maybeSpawnEncounter(segment, quest.tier);
    _checkQuestCompletion(p);
  }

  // ------------------------------------------------------------------
  // Criaturas de la bruma
  // ------------------------------------------------------------------

  /// Stats de combate del jugador (nivel + equipo).
  int _gearBonus(GearSlot slot) => equippedIn(slot)?.statValue ?? 0;
  int get maxHp => 30 + player.level * 5 + _gearBonus(GearSlot.yelmo) * 3;
  int get attack => 6 + player.level * 2 + _gearBonus(GearSlot.reliquia);
  int get defense => 2 + player.level + _gearBonus(GearSlot.tunica);
  int get luck => _gearBonus(GearSlot.capa);

  void _maybeSpawnEncounter(double segment, int tier) {
    if (pendingEncounter != null || pendingReward != null) return;
    _metersSinceEncounterRoll += segment;
    if (_metersSinceEncounterRoll < 130) return;
    _metersSinceEncounterRoll = 0;

    // El Guardián solo despierta en rutas largas, una vez por expedición.
    if (tier == 2 && !_bossSpawnedThisQuest && _rng.nextDouble() < 0.06) {
      _bossSpawnedThisQuest = true;
      pendingEncounter = Enemy.boss(player.level);
      notifyListeners();
      return;
    }
    if (_rng.nextDouble() < 0.24) {
      pendingEncounter = Enemy.randomFor(player.level, _rng);
      notifyListeners();
    }
  }

  /// Evitar el encuentro: la criatura vuelve a la niebla.
  void dismissEncounter() {
    pendingEncounter = null;
    _metersSinceEncounterRoll = -150; // distancia de gracia
    notifyListeners();
  }

  /// Aplica el resultado de una batalla y devuelve el botín para mostrar.
  BattleSpoils applyBattleResult(Enemy enemy, bool won) {
    pendingEncounter = null;
    _metersSinceEncounterRoll = -100;

    if (!won) {
      Storage.save(player, activeQuest);
      notifyListeners();
      return const BattleSpoils(
          won: false,
          xp: 0,
          materialId: null,
          materialCount: 0,
          gear: null,
          newMedals: [],
          leveledUp: false);
    }

    final levelBefore = player.level;
    // La Niebla rojiza (final oculto) duplica la experiencia 24 h.
    final gainedXp =
        player.campaign.nieblaRoja ? enemy.xp * 2 : enemy.xp;
    player.xp += gainedXp;
    player.battlesWon += 1;
    player.bestiary[enemy.spec.id] =
        (player.bestiary[enemy.spec.id] ?? 0) + 1;

    // Materiales: 1-2 (el duende y el jefe son más generosos).
    var count = 1 + _rng.nextInt(2);
    if (enemy.spec.id == 'duende' || enemy.spec.isBoss) count += 1;
    player.materials[enemy.spec.materialId] =
        (player.materials[enemy.spec.materialId] ?? 0) + count;

    // Botín de equipo raro (la suerte de tu capa ayuda).
    GearItem? gear;
    final dropChance = (enemy.spec.isBoss ? 45 : 6) + luck;
    if (_rng.nextInt(100) < dropChance) {
      final unowned = gearCatalog
          .where((g) =>
              !player.inventory.contains(g.id) &&
              (enemy.spec.isBoss
                  ? true
                  : g.rarity == Rarity.comun || g.rarity == Rarity.raro))
          .toList();
      if (unowned.isNotEmpty) {
        gear = unowned[_rng.nextInt(unowned.length)];
        player.inventory.add(gear.id);
      }
    }

    final newMedals = _checkMedals();
    final leveledUp = player.level > levelBefore;

    _checkCampaign();
    Storage.save(player, activeQuest);
    notifyListeners();
    return BattleSpoils(
      won: true,
      xp: gainedXp,
      materialId: enemy.spec.materialId,
      materialCount: count,
      gear: gear,
      newMedals: newMedals,
      leveledUp: leveledUp,
    );
  }

  void _checkQuestCompletion(LatLng p) {
    final quest = activeQuest;
    if (quest == null || quest.route.isEmpty) return;

    final nearGoal = haversineMeters(p, quest.goal) < 60;
    final walkedEnough = quest.walkedMeters >= quest.routeMeters * 0.88;
    final elapsed = DateTime.now().difference(quest.startedAt).inSeconds;
    final timeOk = elapsed > quest.routeMeters / 3.5;

    if (nearGoal && walkedEnough && timeOk) {
      _completeQuest(quest);
    }
  }

  // ------------------------------------------------------------------
  // Expediciones
  // ------------------------------------------------------------------

  Future<Quest?> generateQuest(int tier) async {
    final p = position;
    if (p == null) return null;
    return QuestGenerator.generate(p, tier);
  }

  Future<void> acceptQuest(Quest quest) async {
    activeQuest = quest;
    _lastTrailPoint = null;
    _lastTrailTime = null;
    pendingEncounter = null;
    _metersSinceEncounterRoll = 0;
    _bossSpawnedThisQuest = false;
    await Storage.save(player, activeQuest);
    await startTracking();
    notifyListeners();
  }

  Future<void> abandonQuest() async {
    activeQuest = null;
    _lastTrailPoint = null;
    _lastTrailTime = null;
    pendingEncounter = null;
    await Storage.save(player, activeQuest);
    await startTracking();
    notifyListeners();
  }

  void _completeQuest(Quest quest) {
    activeQuest = null;
    _lastTrailPoint = null;
    _lastTrailTime = null;
    pendingEncounter = null;

    // Condiciones de campaña que dependen del tipo de expedición.
    final hour = DateTime.now().hour;
    if (hour >= 21 || hour < 4) player.campaign.nocturnaDone = true;
    if (quest.tier >= 1) player.campaign.mediaLargaDone = true;

    if (quest.himmelStage > 0) {
      _completeHimmelQuest(quest);
      return;
    }

    final levelBefore = player.level;

    // XP por distancia real caminada.
    final km = quest.walkedMeters / 1000.0;
    final xpGained = 60 + (km * 110).round();
    player.xp += xpGained;
    player.expeditionsDone += 1;
    player.totalMeters += quest.walkedMeters;
    if (quest.tier == 2) {
      player.longExpeditionsDone += 1;
    }

    // Botín del cofre.
    final loot = _rollLoot(quest.tier);
    var duplicate = false;
    var duplicateBonusXp = 0;
    if (loot != null) {
      if (player.inventory.contains(loot.id)) {
        duplicate = true;
        duplicateBonusXp = _duplicateXp(loot.rarity);
        player.xp += duplicateBonusXp;
      } else {
        player.inventory.add(loot.id);
      }
    }

    // Medallas nuevas.
    final newMedals = _checkMedals(completedQuest: quest);

    final levelAfter = player.level;

    pendingReward = RewardBundle(
      quest: quest,
      xpGained: xpGained,
      item: loot,
      duplicate: duplicate,
      duplicateBonusXp: duplicateBonusXp,
      newMedals: newMedals,
      newLevel: levelAfter,
      leveledUp: levelAfter > levelBefore,
    );

    _checkCampaign();
    Storage.save(player, activeQuest);
    startTracking();
    notifyListeners();
  }

  void clearPendingReward() {
    pendingReward = null;
    notifyListeners();
  }

  // ------------------------------------------------------------------
  // La Campaña de la Niebla
  // ------------------------------------------------------------------

  /// Revisa si el siguiente capítulo sin leer ya cumple su condición.
  void _checkCampaign() {
    if (pendingChapter != null) return;
    final read = player.campaign.read;
    for (final ch in campaignChapters) {
      if (read.contains(ch.id)) continue;
      if (ch.isMet(player, player.campaign)) {
        pendingChapter = ch;
      }
      break; // solo evaluamos el siguiente capítulo en orden
    }
  }

  /// Marca un capítulo como leído y otorga sus recompensas.
  void markChapterRead(Chapter chapter) {
    if (player.campaign.read.contains(chapter.id)) return;
    player.campaign.read.add(chapter.id);
    player.xp += chapter.xp;
    recordChapterMarks(chapter.id, player, player.campaign);
    if (chapter.id == 'c9' && !player.inventory.contains('pluma_anselmo')) {
      player.inventory.add('pluma_anselmo');
    }
    if (pendingChapter?.id == chapter.id) pendingChapter = null;
    _checkCampaign();
    Storage.save(player, activeQuest);
    notifyListeners();
  }

  /// Decisión ① (capítulo 8): 'destruir' o 'conservar'.
  void applyDecision1(String choice) {
    player.campaign.decision1 = choice;
    Storage.save(player, activeQuest);
    notifyListeners();
  }

  /// El final (capítulo 12): 'verdad', 'silencio' o 'nombre'.
  void applyEnding(String choice) {
    final c = player.campaign;
    c.ending = choice;
    if (choice == 'nombre') {
      c.endingAt = DateTime.now();
      if (!player.medals.contains('el_que_escribio')) {
        player.medals.add('el_que_escribio');
      }
    } else {
      if (!player.medals.contains('cronista')) {
        player.medals.add('cronista');
      }
    }
    Storage.save(player, activeQuest);
    notifyListeners();
  }

  // ---- Hilo de Himmel ----

  /// La siguiente misión de Himmel disponible, o null.
  HimmelMission? himmelAvailable() {
    final c = player.campaign;
    if (c.himmelLost) return null;
    if (c.himmelStage >= 5) return null;
    final next = himmelMissions[c.himmelStage];
    final required = himmelRequiredChapter(next.stage);
    if (!c.read.contains(required)) return null;
    return next;
  }

  /// Inicia una misión de Himmel. Devuelve false si no se pudo generar ruta.
  Future<bool> startHimmelMission(HimmelMission mission) async {
    if (mission.tier < 0) {
      // Sin caminata: la escena ocurre de inmediato.
      player.campaign.himmelStage = mission.stage;
      player.xp += mission.xp;
      pendingHimmelScene = mission;
      Storage.save(player, activeQuest);
      notifyListeners();
      return true;
    }
    final p = position;
    if (p == null) return false;
    final target = QuestGenerator.targetMeters[mission.tier.clamp(0, 2)];
    final route = await RoutingService.generateLoop(p, target);
    if (route == null) return false;
    final quest = Quest(
      name: '🏹 ${mission.title}',
      flavor: 'Misión de Himmel',
      tier: mission.tier,
      himmelStage: mission.stage,
      route: route.points,
      routeMeters: route.meters,
    );
    await acceptQuest(quest);
    return true;
  }

  void _completeHimmelQuest(Quest quest) {
    final mission = himmelMissions[quest.himmelStage - 1];
    player.expeditionsDone += 1;
    player.totalMeters += quest.walkedMeters;
    player.xp += mission.xp;
    player.campaign.himmelStage = mission.stage;

    if (mission.stage == 5) {
      if (!player.medals.contains('reunion')) {
        player.medals.add('reunion');
      }
      // El cruce "Donde se encontraron": punto medio de la ruta.
      if (quest.route.isNotEmpty) {
        final mid = quest.route[quest.route.length ~/ 2];
        player.campaign.reunionLat = mid.latitude;
        player.campaign.reunionLng = mid.longitude;
      }
      reunionRelicPending = true;
    }

    pendingHimmelScene = mission;
    _checkMedals();
    _checkCampaign();
    Storage.save(player, activeQuest);
    startTracking();
    notifyListeners();
  }

  /// Elección de reliquia tras el reencuentro.
  void chooseReunionRelic(String itemId) {
    if (!reunionRelicPending) return;
    if (itemId == 'martillo_ram' || itemId == 'silbato_himmel') {
      if (!player.inventory.contains(itemId)) {
        player.inventory.add(itemId);
      }
    }
    reunionRelicPending = false;
    Storage.save(player, activeQuest);
    notifyListeners();
  }

  void clearHimmelScene() {
    pendingHimmelScene = null;
    notifyListeners();
  }

  GearItem? _rollLoot(int tier) {
    // Pesos de rareza según el tamaño de la expedición.
    const weights = [
      [60, 30, 9, 1], // corta
      [45, 38, 14, 3], // media
      [30, 42, 22, 6], // larga
    ];
    final w = weights[tier.clamp(0, 2)];
    final total = w[0] + w[1] + w[2] + w[3];
    var roll = _rng.nextInt(total);
    var rarityIndex = 0;
    for (var i = 0; i < 4; i++) {
      if (roll < w[i]) {
        rarityIndex = i;
        break;
      }
      roll -= w[i];
    }
    final rarity = Rarity.values[rarityIndex];

    // Prefiere objetos que aún no tienes de esa rareza.
    final ofRarity =
        gearCatalog.where((g) => g.rarity == rarity).toList();
    if (ofRarity.isEmpty) return null;
    final unowned =
        ofRarity.where((g) => !player.inventory.contains(g.id)).toList();
    final pool = unowned.isNotEmpty ? unowned : ofRarity;
    return pool[_rng.nextInt(pool.length)];
  }

  int _duplicateXp(Rarity rarity) {
    switch (rarity) {
      case Rarity.comun:
        return 40;
      case Rarity.raro:
        return 90;
      case Rarity.epico:
        return 180;
      case Rarity.legendario:
        return 400;
    }
  }

  List<Medal> _checkMedals({Quest? completedQuest}) {
    final earned = <Medal>[];
    void grant(String id) {
      if (player.medals.contains(id)) return;
      final medal = medalById(id);
      if (medal == null) return;
      player.medals.add(id);
      earned.add(medal);
    }

    final exp = player.expeditionsDone;
    if (exp >= 1) grant('primera_expedicion');
    if (exp >= 5) grant('exp_5');
    if (exp >= 25) grant('exp_25');
    if (exp >= 100) grant('exp_100');

    final km = player.totalMeters / 1000.0;
    if (km >= 10) grant('km_10');
    if (km >= 50) grant('km_50');
    if (km >= 150) grant('km_150');
    if (km >= 500) grant('km_500');

    if (player.longExpeditionsDone >= 1) grant('larga_1');

    final wins = player.battlesWon;
    if (wins >= 1) grant('cazador_1');
    if (wins >= 10) grant('cazador_10');
    if (wins >= 50) grant('cazador_50');
    if ((player.bestiary['guardian'] ?? 0) >= 1) grant('jefe_1');

    if (completedQuest != null) {
      final hour = DateTime.now().hour;
      if (hour < 8) grant('madrugador');
      if (hour >= 21) grant('noctambulo');
    }

    return earned;
  }

  void _checkFogMedal() {
    if (player.explored.length >= 1000 &&
        !player.medals.contains('niebla_1000')) {
      final medal = medalById('niebla_1000');
      if (medal != null) {
        player.medals.add('niebla_1000');
      }
    }
  }

  // ------------------------------------------------------------------
  // Avatar
  // ------------------------------------------------------------------

  GearItem? equippedIn(GearSlot slot) {
    final id = player.equipped[slot.name];
    if (id == null) return null;
    return gearById(id);
  }

  void equip(GearItem item) {
    if (!player.inventory.contains(item.id)) return;
    player.equipped[item.slot.name] = item.id;
    Storage.save(player, activeQuest);
    notifyListeners();
  }

  void unequip(GearSlot slot) {
    player.equipped.remove(slot.name);
    Storage.save(player, activeQuest);
    notifyListeners();
  }

  // ------------------------------------------------------------------
  // Respaldo de partida
  // ------------------------------------------------------------------

  /// Crea un archivo de respaldo listo para compartir. Devuelve su ruta.
  Future<String?> exportBackup() async {
    try {
      await Storage.save(player, activeQuest);
      final raw = await Storage.rawJson();
      if (raw == null) return null;
      final dir = await getTemporaryDirectory();
      final now = DateTime.now();
      final stamp = '${now.year}'
          '${now.month.toString().padLeft(2, '0')}'
          '${now.day.toString().padLeft(2, '0')}';
      final file = File('${dir.path}/ReinoDeNiebla-respaldo-$stamp.json');
      await file.writeAsString(raw, flush: true);
      return file.path;
    } catch (_) {
      return null;
    }
  }

  /// Restaura una partida desde el contenido de un respaldo.
  /// Devuelve false si el archivo no es un respaldo válido.
  Future<bool> importBackup(String rawJson) async {
    try {
      final data = jsonDecode(rawJson) as Map<String, dynamic>;
      if (data['player'] is! Map) return false;
      final restored = PlayerState.fromJson(
          (data['player'] as Map).cast<String, dynamic>());
      await Storage.writeRaw(rawJson);
      player = restored;
      activeQuest = null;
      pendingEncounter = null;
      pendingReward = null;
      if (player.exploredDays.length != player.explored.length) {
        final today = dayNumber();
        player.exploredDays =
            List<int>.filled(player.explored.length, today, growable: true);
      }
      _exploredKeys.clear();
      for (var i = 0; i < player.explored.length; i++) {
        _exploredKeys[_gridKey(player.explored[i])] = i;
      }
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Guarda nombre/apariencia editados en el Espejo Mágico.
  void saveProfile() {
    Storage.save(player, activeQuest);
    notifyListeners();
  }

  void completeOnboarding() {
    player.onboardingDone = true;
    Storage.save(player, activeQuest);
    notifyListeners();
  }

  // ------------------------------------------------------------------
  // Guardado
  // ------------------------------------------------------------------

  void _maybeSave() {
    final now = DateTime.now();
    if (now.difference(_lastSave).inSeconds >= 20) {
      _lastSave = now;
      Storage.save(player, activeQuest);
    }
  }

  Future<void> saveNow() => Storage.save(player, activeQuest);

  @override
  void dispose() {
    _posSub?.cancel();
    super.dispose();
  }
}
