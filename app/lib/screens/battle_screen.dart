import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../game_controller.dart';
import '../models/bestiary.dart';
import '../models/items.dart';
import '../theme.dart';
import '../widgets/avatar_view.dart';
import '../widgets/enemy_sprite.dart';

/// Combate por turnos contra una criatura de la bruma.
class BattleScreen extends StatefulWidget {
  final GameController controller;
  final Enemy enemy;

  const BattleScreen({
    super.key,
    required this.controller,
    required this.enemy,
  });

  @override
  State<BattleScreen> createState() => _BattleScreenState();
}

enum _Phase { playerTurn, enemyTurn, victory, defeat }

class _BattleScreenState extends State<BattleScreen>
    with SingleTickerProviderStateMixin {
  final _rng = math.Random();

  late int _playerHp;
  late int _playerMaxHp;
  late int _enemyHp;
  bool _defending = false;
  int _relicCooldown = 0;
  _Phase _phase = _Phase.playerTurn;
  String _log = '';
  BattleSpoils? _spoils;

  late final AnimationController _shake;

  GameController get game => widget.controller;
  Enemy get enemy => widget.enemy;

  @override
  void initState() {
    super.initState();
    _playerMaxHp = game.maxHp;
    _playerHp = _playerMaxHp;
    _enemyHp = enemy.maxHp;
    _log = '¡${enemy.displayName} (Nv ${enemy.level}) te cierra el paso!';
    _shake = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    HapticFeedback.mediumImpact();
  }

  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  // ---- Acciones del jugador ----

  void _attack({bool relic = false}) {
    if (_phase != _Phase.playerTurn) return;
    var dmg = game.attack + _rng.nextInt(6) - 2;
    var text = '';
    if (relic) {
      dmg = (dmg * 1.8).round();
      _relicCooldown = 3;
      text = '✨ ¡Invocas el poder de tu reliquia! ';
    }
    final crit = _rng.nextInt(100) < 8 + game.luck * 2;
    if (crit) {
      dmg *= 2;
      HapticFeedback.heavyImpact();
    } else {
      HapticFeedback.mediumImpact();
    }
    dmg = math.max(1, dmg);
    _enemyHp = math.max(0, _enemyHp - dmg);
    _shake.forward(from: 0);
    setState(() {
      _log = '$text${crit ? '💥 ¡CRÍTICO! ' : ''}'
          'Golpeas a ${enemy.displayName} por $dmg de daño.';
    });
    _afterPlayerAction();
  }

  void _defend() {
    if (_phase != _Phase.playerTurn) return;
    _defending = true;
    _playerHp = math.min(_playerMaxHp, _playerHp + 4);
    HapticFeedback.selectionClick();
    setState(() {
      _log = '🛡️ Te cubres tras tu equipo y recuperas el aliento (+4 vida).';
    });
    _afterPlayerAction();
  }

  Future<void> _flee() async {
    if (_phase != _Phase.playerTurn) return;
    final ok = _rng.nextInt(100) < 55 + game.luck * 3;
    if (ok) {
      game.applyBattleResult(enemy, false);
      if (mounted) Navigator.of(context).pop();
      return;
    }
    setState(() {
      _log = '🏃 ¡Intentas huir pero ${enemy.displayName} te alcanza!';
    });
    _afterPlayerAction(skipVictoryCheck: true);
  }

  void _afterPlayerAction({bool skipVictoryCheck = false}) {
    if (!skipVictoryCheck && _enemyHp <= 0) {
      _win();
      return;
    }
    _phase = _Phase.enemyTurn;
    Future.delayed(const Duration(milliseconds: 900), _enemyAct);
  }

  void _enemyAct() {
    if (!mounted || _phase != _Phase.enemyTurn) return;
    var dmg = enemy.atk + _rng.nextInt(4) - 1 - (game.defense ~/ 2);
    dmg = math.max(1, dmg);
    if (_defending) {
      dmg = math.max(1, (dmg * 0.35).round());
      _defending = false;
    }
    _playerHp = math.max(0, _playerHp - dmg);
    if (_relicCooldown > 0) _relicCooldown--;
    HapticFeedback.lightImpact();
    _shake.forward(from: 0);
    setState(() {
      _log = '${enemy.spec.emoji} ${enemy.displayName} te golpea por $dmg.';
      if (_playerHp <= 0) {
        _phase = _Phase.defeat;
        _log = 'La bruma te envuelve… despiertas en el camino, ileso. '
            'La criatura se ha ido.';
        game.applyBattleResult(enemy, false);
      } else {
        _phase = _Phase.playerTurn;
      }
    });
  }

  void _win() {
    HapticFeedback.heavyImpact();
    setState(() {
      _phase = _Phase.victory;
      _spoils = game.applyBattleResult(enemy, true);
      _log = '🎉 ¡${enemy.displayName} se disuelve en la niebla!';
    });
  }

  // ---- UI ----

  @override
  Widget build(BuildContext context) {
    final equipped = {
      for (final slot in GearSlot.values) slot: game.equippedIn(slot),
    };

    return PopScope(
      canPop: _phase == _Phase.victory || _phase == _Phase.defeat,
      child: Scaffold(
        backgroundColor: RN.night,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // ---- Enemigo ----
                _hpBar(enemy.displayName, 'Nv ${enemy.level}', _enemyHp,
                    enemy.maxHp, RN.danger),
                const SizedBox(height: 10),
                Expanded(
                  child: AnimatedBuilder(
                    animation: _shake,
                    builder: (context, child) {
                      final t = _shake.value;
                      final dx =
                          math.sin(t * math.pi * 5) * (1 - t) * 8;
                      return Transform.translate(
                          offset: Offset(dx, 0), child: child);
                    },
                    child: Center(
                      child: AnimatedScale(
                        scale: _enemyHp <= 0 ? 0.0 : 1.0,
                        duration: const Duration(milliseconds: 500),
                        child: EnemySprite(
                          enemy: enemy,
                          size: enemy.spec.isBoss ? 220 : 170,
                        ),
                      ),
                    ),
                  ),
                ),

                // ---- Registro de combate ----
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: RN.panel,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: RN.gold.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    _log,
                    textAlign: TextAlign.center,
                    style:
                        const TextStyle(color: RN.parchment, height: 1.3),
                  ),
                ),
                const SizedBox(height: 12),

                // ---- Jugador ----
                Row(
                  children: [
                    SizedBox(
                      width: 52,
                      height: 62,
                      child: AvatarView(
                        equipped: equipped,
                        appearance: game.player.appearance,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _hpBar(
                          game.player.name.isEmpty
                              ? 'Tú'
                              : game.player.name,
                          'Nv ${game.player.level}',
                          _playerHp,
                          _playerMaxHp,
                          RN.teal),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // ---- Acciones / resultado ----
                if (_phase == _Phase.victory)
                  _victoryPanel()
                else if (_phase == _Phase.defeat)
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text('Seguir caminando'),
                      ),
                    ),
                  )
                else
                  _actionButtons(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _actionButtons() {
    final canAct = _phase == _Phase.playerTurn;
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: FilledButton(
                onPressed: canAct ? () => _attack() : null,
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Text('⚔️ Atacar'),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.tonal(
                onPressed: canAct ? _defend : null,
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Text('🛡️ Defender'),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              flex: 3,
              child: FilledButton.tonal(
                onPressed: canAct && _relicCooldown == 0
                    ? () => _attack(relic: true)
                    : null,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Text(_relicCooldown == 0
                      ? '✨ Poder de la Reliquia'
                      : '✨ Recargando ($_relicCooldown)'),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: TextButton(
                onPressed: canAct ? _flee : null,
                child: const Text('🏃 Huir',
                    style: TextStyle(color: RN.parchmentDim)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _victoryPanel() {
    final s = _spoils!;
    final material =
        s.materialId != null ? materialById(s.materialId!) : null;
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: RN.gold.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: RN.gold.withValues(alpha: 0.5)),
          ),
          child: Column(
            children: [
              Text('¡Victoria!  ⭐ +${s.xp} XP',
                  style: fantasyTitle(17, color: RN.goldSoft)),
              if (material != null)
                Text(
                  '${material.emoji} ${material.name} × ${s.materialCount}',
                  style: const TextStyle(color: RN.parchment),
                ),
              if (s.gear != null)
                Text(
                  '🎁 ¡Botín: ${s.gear!.name} (${s.gear!.rarity.label})!',
                  style: TextStyle(
                      color: s.gear!.rarity.color,
                      fontWeight: FontWeight.bold),
                ),
              if (s.leveledUp)
                Text('⬆️ ¡Subiste al nivel ${game.player.level}!',
                    style: const TextStyle(
                        color: RN.goldSoft, fontWeight: FontWeight.bold)),
              for (final m in s.newMedals)
                Text('🏅 Nueva medalla: ${m.name}',
                    style: const TextStyle(color: RN.goldSoft)),
            ],
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('Continuar la expedición'),
            ),
          ),
        ),
      ],
    );
  }

  Widget _hpBar(
      String name, String level, int hp, int maxHp, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('$name · $level',
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 13)),
            Text('$hp / $maxHp',
                style:
                    const TextStyle(fontSize: 12, color: RN.parchmentDim)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(5),
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: maxHp <= 0 ? 0.0 : hp / maxHp),
            duration: const Duration(milliseconds: 350),
            builder: (context, v, _) => LinearProgressIndicator(
              value: v,
              minHeight: 9,
              backgroundColor: Colors.white12,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}
