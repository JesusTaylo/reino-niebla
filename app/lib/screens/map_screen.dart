import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../game_controller.dart';
import '../models/items.dart';
import '../models/quest.dart';
import '../theme.dart';
import '../util/geo.dart';
import '../widgets/avatar_view.dart';
import '../widgets/fog_layer.dart';
import 'avatar_screen.dart';
import 'medals_screen.dart';
import 'reward_screen.dart';

class MapScreen extends StatefulWidget {
  final GameController controller;

  const MapScreen({super.key, required this.controller});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  bool _mapReady = false;
  bool _follow = true;
  bool _centeredOnce = false;
  bool _rewardShowing = false;
  LatLng? _lastFollowed;

  GameController get game => widget.controller;

  // Tinte pergamino para las teselas del mapa.
  static const _parchmentMatrix = <double>[
    0.393, 0.769, 0.189, 0, -10,
    0.349, 0.686, 0.168, 0, -10,
    0.272, 0.534, 0.131, 0, -10,
    0, 0, 0, 1, 0,
  ];

  @override
  void initState() {
    super.initState();
    game.addListener(_onGameChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeOnboard());
  }

  @override
  void dispose() {
    game.removeListener(_onGameChanged);
    super.dispose();
  }

  void _onGameChanged() {
    final pos = game.position;
    if (pos != null && _mapReady) {
      if (!_centeredOnce) {
        _centeredOnce = true;
        _mapController.move(pos, 16);
        _lastFollowed = pos;
      } else if (_follow && (_lastFollowed == null ||
          haversineMeters(_lastFollowed!, pos) > 2)) {
        _lastFollowed = pos;
        _mapController.move(pos, _mapController.camera.zoom);
      }
    }

    final reward = game.pendingReward;
    if (reward != null && !_rewardShowing && mounted) {
      _rewardShowing = true;
      Navigator.of(context)
          .push(MaterialPageRoute(
        builder: (_) => RewardScreen(controller: game, reward: reward),
      ))
          .then((_) {
        _rewardShowing = false;
      });
    }
  }

  Future<void> _maybeOnboard() async {
    if (!mounted) return;
    if (game.loaded && !game.player.onboardingDone) {
      await _showOnboarding();
    }
  }

  Future<void> _showOnboarding() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: RN.panel,
        title: Text('🏰 El Reino de Niebla',
            style: fantasyTitle(22, color: RN.goldSoft),
            textAlign: TextAlign.center),
        content: SingleChildScrollView(
          child: Text(
            'Hace cien años, la Niebla devoró los mapas del reino. '
            'Las calles siguen ahí afuera… pero nadie las recuerda.\n\n'
            'Tú eres el nuevo Cartógrafo Real. Cada paso que des en el '
            'mundo real despeja la Niebla y devuelve tu ciudad al mapa.\n\n'
            '⚔️ Acepta expediciones, camínalas de verdad, y gana cofres, '
            'medallas y equipo para tu explorador.\n\n'
            'El reino cuenta contigo. Y con tus piernas.',
            style: const TextStyle(color: RN.parchment, height: 1.4),
          ),
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                game.completeOnboarding();
                Navigator.of(context).pop();
                game.refreshPermissions().then((_) {
                  if (game.locationStatus == LocationStatus.ok) {
                    game.startTracking();
                  }
                });
              },
              child: const Text('Aceptar la misión'),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListenableBuilder(
        listenable: game,
        builder: (context, _) {
          final pos = game.position;
          final quest = game.activeQuest;
          final initialCenter = pos ??
              (game.player.explored.isNotEmpty
                  ? game.player.explored.last
                  : const LatLng(23.6345, -102.5528));

          return Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: initialCenter,
                  initialZoom: pos != null ? 16 : 5,
                  minZoom: 3,
                  maxZoom: 19,
                  backgroundColor: RN.night,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                  ),
                  onMapReady: () => _mapReady = true,
                  onPositionChanged: (camera, hasGesture) {
                    if (hasGesture && _follow) {
                      setState(() => _follow = false);
                    }
                  },
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'dev.jesus.reino_niebla',
                    tileBuilder: (context, tileWidget, tile) => ColorFiltered(
                      colorFilter:
                          const ColorFilter.matrix(_parchmentMatrix),
                      child: tileWidget,
                    ),
                  ),
                  FogLayer(
                    revealed: game.player.explored,
                    playerPosition: pos,
                    radiusMeters: GameController.fogRevealRadiusMeters,
                  ),
                  if (quest != null && quest.route.isNotEmpty)
                    PolylineLayer(
                      polylines: [
                        // Contorno oscuro para que la ruta resalte sobre todo.
                        Polyline(
                          points: quest.route,
                          strokeWidth: 9,
                          color: const Color(0xB30D1026),
                        ),
                        Polyline(
                          points: quest.route,
                          strokeWidth: 5,
                          color: RN.gold.withValues(alpha: 0.95),
                          pattern: StrokePattern.dashed(
                              segments: const [14.0, 10.0]),
                        ),
                        if (quest.trail.length >= 2)
                          Polyline(
                            points: quest.trail,
                            strokeWidth: 4,
                            color: RN.teal.withValues(alpha: 0.85),
                          ),
                      ],
                    ),
                  MarkerLayer(
                    markers: [
                      if (quest != null && quest.route.isNotEmpty)
                        Marker(
                          point: quest.goal,
                          width: 40,
                          height: 40,
                          alignment: Alignment.topCenter,
                          child: const Text('🚩',
                              style: TextStyle(fontSize: 30)),
                        ),
                      if (pos != null)
                        Marker(
                          point: pos,
                          width: 44,
                          height: 44,
                          child: _PlayerMarker(headingDeg: game.headingDeg),
                        ),
                    ],
                  ),
                ],
              ),

              // ---- HUD superior ----
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: _TopHud(controller: game),
                ),
              ),

              // ---- Botón de seguir mi posición ----
              Positioned(
                right: 12,
                bottom: 150,
                child: FloatingActionButton.small(
                  heroTag: 'follow',
                  backgroundColor: _follow
                      ? RN.gold
                      : RN.night.withValues(alpha: 0.88),
                  foregroundColor: _follow ? RN.night : RN.parchment,
                  onPressed: () {
                    setState(() => _follow = true);
                    final p = game.position;
                    if (p != null && _mapReady) {
                      _mapController.move(p, math.max(16, _mapController.camera.zoom));
                    }
                  },
                  child: const Icon(Icons.my_location),
                ),
              ),

              // ---- Panel inferior ----
              Align(
                alignment: Alignment.bottomCenter,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: _bottomPanel(quest),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _bottomPanel(Quest? quest) {
    final status = game.locationStatus;

    if (status == LocationStatus.serviceOff ||
        status == LocationStatus.denied ||
        status == LocationStatus.deniedForever) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🌫️', style: TextStyle(fontSize: 30)),
              const SizedBox(height: 6),
              Text(
                status == LocationStatus.serviceOff
                    ? 'La Niebla bloquea tu brújula: activa la ubicación (GPS) del teléfono.'
                    : 'El Cartógrafo Real necesita permiso de ubicación para trazar tu camino.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: RN.parchment),
              ),
              const SizedBox(height: 10),
              FilledButton(
                onPressed: () async {
                  if (status == LocationStatus.deniedForever) {
                    await Geolocator.openAppSettings();
                  } else if (status == LocationStatus.serviceOff) {
                    await Geolocator.openLocationSettings();
                  }
                  await game.refreshPermissions();
                  if (game.locationStatus == LocationStatus.ok) {
                    await game.startTracking();
                  }
                },
                child: const Text('Conceder permiso'),
              ),
            ],
          ),
        ),
      );
    }

    if (quest == null) {
      // Botón píldora centrado: no ocupa todo el ancho del mapa.
      return FilledButton(
        style: FilledButton.styleFrom(
          padding:
              const EdgeInsets.symmetric(horizontal: 26, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(26),
          ),
        ),
        onPressed: game.position == null ? null : _openQuestSheet,
        child: Text(
          game.position == null
              ? 'Buscando tu posición…'
              : '🗺️  Nueva expedición',
          style: const TextStyle(fontSize: 15.5),
        ),
      );
    }

    final remaining =
        math.max(0.0, quest.routeMeters - quest.walkedMeters);

    // Panel compacto y translúcido: información esencial, mapa visible.
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
      decoration: BoxDecoration(
        color: RN.night.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: RN.gold.withValues(alpha: 0.35)),
        boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 8)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  quest.name,
                  style: fantasyTitle(14.5, color: RN.goldSoft),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              InkWell(
                customBorder: const CircleBorder(),
                onTap: _confirmAbandon,
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child:
                      Icon(Icons.close, size: 18, color: RN.parchmentDim),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: quest.progress,
                    minHeight: 7,
                    backgroundColor: Colors.white12,
                    color: RN.gold,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                quest.walkedMeters < 30
                    ? '${formatKm(quest.routeMeters)} 🥾'
                    : 'faltan ${formatKm(remaining)}',
                style: const TextStyle(
                    fontSize: 12,
                    color: RN.parchment,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 6),
            ],
          ),
          if (quest.walkedMeters < 30) ...[
            const SizedBox(height: 5),
            const Text(
              'Ruta circular: sigue el camino dorado y vuelve al inicio',
              style: TextStyle(fontSize: 11, color: RN.parchmentDim),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _confirmAbandon() async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: RN.panel,
        title: const Text('¿Abandonar la expedición?'),
        content: const Text(
            'La Niebla reclamará esta ruta. No recibirás recompensas.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Seguir caminando'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Abandonar',
                style: TextStyle(color: RN.danger)),
          ),
        ],
      ),
    );
    if (sure == true) {
      await game.abandonQuest();
    }
  }

  Future<void> _openQuestSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: RN.panel,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _QuestSheet(controller: game),
    );
  }
}

// ---------------------------------------------------------------------
// HUD superior
// ---------------------------------------------------------------------

class _TopHud extends StatelessWidget {
  final GameController controller;

  const _TopHud({required this.controller});

  @override
  Widget build(BuildContext context) {
    final player = controller.player;
    final equipped = {
      for (final slot in GearSlot.values) slot: controller.equippedIn(slot),
    };
    // Píldora compacta y translúcida: tapa lo mínimo posible del mapa.
    return Align(
      alignment: Alignment.topCenter,
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: RN.night.withValues(alpha: 0.88),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: RN.gold.withValues(alpha: 0.35)),
          boxShadow: const [
            BoxShadow(color: Colors.black38, blurRadius: 8),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => AvatarScreen(controller: controller),
              )),
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: RN.night,
                  border: Border.all(color: RN.gold, width: 1.5),
                ),
                child: ClipOval(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: AvatarView(
                        equipped: equipped,
                        appearance: player.appearance),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  player.name.isEmpty
                      ? 'Nv ${player.level} · ${player.title}'
                      : '${player.name} · Nv ${player.level}',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                SizedBox(
                  width: 130,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: player.levelProgress,
                      minHeight: 4,
                      backgroundColor: Colors.white12,
                      color: RN.teal,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 4),
            InkWell(
              customBorder: const CircleBorder(),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => MedalsScreen(controller: controller),
              )),
              child: const Padding(
                padding: EdgeInsets.all(6),
                child: Text('🏅', style: TextStyle(fontSize: 19)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------
// Marcador del jugador
// ---------------------------------------------------------------------

class _PlayerMarker extends StatelessWidget {
  final double? headingDeg;

  const _PlayerMarker({this.headingDeg});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: RN.gold,
        border: Border.all(color: RN.parchment, width: 3),
        boxShadow: [
          BoxShadow(
            color: RN.gold.withValues(alpha: 0.55),
            blurRadius: 14,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Transform.rotate(
        angle: (headingDeg ?? 0) * math.pi / 180,
        child: const Icon(Icons.navigation, color: RN.night, size: 24),
      ),
    );
  }
}

// ---------------------------------------------------------------------
// Hoja de nueva expedición
// ---------------------------------------------------------------------

class _QuestSheet extends StatefulWidget {
  final GameController controller;

  const _QuestSheet({required this.controller});

  @override
  State<_QuestSheet> createState() => _QuestSheetState();
}

enum _SheetPhase { choose, loading, preview, error }

class _QuestSheetState extends State<_QuestSheet> {
  _SheetPhase _phase = _SheetPhase.choose;
  Quest? _quest;
  int _tier = 0;

  Future<void> _generate(int tier) async {
    setState(() {
      _tier = tier;
      _phase = _SheetPhase.loading;
    });
    final quest = await widget.controller.generateQuest(tier);
    if (!mounted) return;
    setState(() {
      if (quest == null) {
        _phase = _SheetPhase.error;
      } else {
        _quest = quest;
        _phase = _SheetPhase.preview;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: 20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 200),
        child: switch (_phase) {
          _SheetPhase.choose => _chooseView(),
          _SheetPhase.loading => _loadingView(),
          _SheetPhase.preview => _previewView(),
          _SheetPhase.error => _errorView(),
        },
      ),
    );
  }

  Widget _chooseView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Elige tu expedición',
            style: fantasyTitle(20, color: RN.goldSoft),
            textAlign: TextAlign.center),
        const SizedBox(height: 4),
        const Text(
          'Sales y regresas al mismo punto, caminando por calles reales.',
          textAlign: TextAlign.center,
          style: TextStyle(color: RN.parchmentDim, fontSize: 12.5),
        ),
        const SizedBox(height: 14),
        _tierTile(0, '🥾 Corta', '≈ 1 km · un paseo de reconocimiento'),
        _tierTile(1, '🧭 Media', '≈ 3 km · una misión seria'),
        _tierTile(2, '🗻 Larga', '≈ 5 km · una gran travesía (mejor botín)'),
      ],
    );
  }

  Widget _tierTile(int tier, String title, String subtitle) {
    return Card(
      color: RN.nightSoft,
      child: ListTile(
        title: Text(title,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle,
            style: const TextStyle(fontSize: 12, color: RN.parchmentDim)),
        trailing: const Icon(Icons.chevron_right, color: RN.gold),
        onTap: () => _generate(tier),
      ),
    );
  }

  Widget _loadingView() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: RN.gold),
          SizedBox(height: 16),
          Text('Los cartógrafos del gremio trazan tu ruta…',
              style: TextStyle(color: RN.parchmentDim)),
        ],
      ),
    );
  }

  Widget _previewView() {
    final quest = _quest!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(quest.name,
            style: fantasyTitle(20, color: RN.goldSoft),
            textAlign: TextAlign.center),
        const SizedBox(height: 6),
        Text(
          '${quest.tierLabel} · ${formatKm(quest.routeMeters)} por calles reales',
          textAlign: TextAlign.center,
          style: const TextStyle(color: RN.teal, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        Text(
          quest.flavor,
          textAlign: TextAlign.center,
          style: const TextStyle(
              color: RN.parchment, fontStyle: FontStyle.italic, height: 1.35),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: () async {
            await widget.controller.acceptQuest(quest);
            if (mounted) Navigator.of(context).pop();
          },
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('⚔️ ¡En marcha!', style: TextStyle(fontSize: 16)),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: TextButton(
                onPressed: () => _generate(_tier),
                child: const Text('Otra ruta'),
              ),
            ),
            Expanded(
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancelar',
                    style: TextStyle(color: RN.parchmentDim)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _errorView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('🌫️', style: TextStyle(fontSize: 34)),
        const SizedBox(height: 8),
        const Text(
          'La Niebla es espesa: no se pudo trazar la ruta.\n'
          'Revisa tu conexión a internet e inténtalo de nuevo.',
          textAlign: TextAlign.center,
          style: TextStyle(color: RN.parchment),
        ),
        const SizedBox(height: 14),
        FilledButton(
          onPressed: () => _generate(_tier),
          child: const Text('Reintentar'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child:
              const Text('Cerrar', style: TextStyle(color: RN.parchmentDim)),
        ),
      ],
    );
  }
}
