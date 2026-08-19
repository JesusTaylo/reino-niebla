import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import 'models/items.dart';
import 'models/medals.dart';
import 'models/player_state.dart';
import 'models/quest.dart';
import 'services/quest_generator.dart';
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

  StreamSubscription<Position>? _posSub;
  DateTime _lastSave = DateTime.fromMillisecondsSinceEpoch(0);
  LatLng? _lastTrailPoint;
  DateTime? _lastTrailTime;

  /// Rejilla espacial (~50 m) para no duplicar puntos de niebla revelada.
  final Set<String> _exploredKeys = {};

  static String _gridKey(LatLng p) =>
      '${(p.latitude * 2000).round()}:${(p.longitude * 2000).round()}';

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
    for (final p in player.explored) {
      _exploredKeys.add(_gridKey(p));
    }
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
    // Rejilla espacial: si esta celda (~50 m) ya fue revelada, no duplicar.
    final key = _gridKey(p);
    if (_exploredKeys.contains(key)) return;
    // Y además, mínima separación con los puntos recientes.
    final start = math.max(0, explored.length - 60);
    for (var i = explored.length - 1; i >= start; i--) {
      if (haversineMeters(explored[i], p) < _exploredMinGapMeters) {
        return;
      }
    }
    _exploredKeys.add(key);
    explored.add(p);
    _checkFogMedal();
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

    _checkQuestCompletion(p);
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
    await Storage.save(player, activeQuest);
    await startTracking();
    notifyListeners();
  }

  Future<void> abandonQuest() async {
    activeQuest = null;
    _lastTrailPoint = null;
    _lastTrailTime = null;
    await Storage.save(player, activeQuest);
    await startTracking();
    notifyListeners();
  }

  void _completeQuest(Quest quest) {
    activeQuest = null;
    _lastTrailPoint = null;
    _lastTrailTime = null;

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

    Storage.save(player, activeQuest);
    startTracking();
    notifyListeners();
  }

  void clearPendingReward() {
    pendingReward = null;
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
