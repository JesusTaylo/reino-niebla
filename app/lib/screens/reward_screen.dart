import 'package:flutter/material.dart';

import '../game_controller.dart';
import '../models/items.dart';
import '../theme.dart';
import '../util/geo.dart';

/// Pantalla de recompensas tras completar una expedición.
class RewardScreen extends StatefulWidget {
  final GameController controller;
  final RewardBundle reward;

  const RewardScreen({
    super.key,
    required this.controller,
    required this.reward,
  });

  @override
  State<RewardScreen> createState() => _RewardScreenState();
}

class _RewardScreenState extends State<RewardScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;
  bool _chestOpened = false;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  void _openChest() {
    setState(() => _chestOpened = true);
    _anim.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.reward;
    final item = r.item;

    return Scaffold(
      backgroundColor: RN.night,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Text('✦ Expedición completada ✦',
                  style: fantasyTitle(24, color: RN.goldSoft),
                  textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(r.quest.name,
                  style: fantasyTitle(17), textAlign: TextAlign.center),
              Text(
                '${formatKm(r.quest.walkedMeters)} recorridos',
                style: const TextStyle(color: RN.parchmentDim),
              ),
              const SizedBox(height: 20),
              _xpCard(r),
              if (r.leveledUp) ...[
                const SizedBox(height: 10),
                Card(
                  color: RN.gold.withValues(alpha: 0.15),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      '⬆️ ¡Subiste al nivel ${r.newLevel}! '
                      'Ahora eres ${widget.controller.player.title}.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: RN.goldSoft, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Expanded(
                child: Center(
                  child: !_chestOpened
                      ? _closedChest()
                      : _openedChest(item, r),
                ),
              ),
              if (r.newMedals.isNotEmpty) ...[
                for (final medal in r.newMedals)
                  Card(
                    color: RN.panel,
                    child: ListTile(
                      leading: Text(medal.emoji,
                          style: const TextStyle(fontSize: 26)),
                      title: Text('¡Nueva medalla: ${medal.name}!',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: RN.goldSoft)),
                      subtitle: Text(medal.desc,
                          style: const TextStyle(
                              fontSize: 12, color: RN.parchmentDim)),
                    ),
                  ),
                const SizedBox(height: 8),
              ],
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _chestOpened
                      ? () {
                          widget.controller.clearPendingReward();
                          Navigator.of(context).pop();
                        }
                      : _openChest,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Text(
                      _chestOpened ? 'Continuar la aventura' : 'Abrir el cofre',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _xpCard(RewardBundle r) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('⭐', style: TextStyle(fontSize: 22)),
            const SizedBox(width: 10),
            Text(
              '+${r.xpGained + r.duplicateBonusXp} XP',
              style: const TextStyle(
                  fontSize: 20, fontWeight: FontWeight.bold, color: RN.gold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _closedChest() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(seconds: 1),
          curve: Curves.elasticOut,
          builder: (context, v, child) =>
              Transform.scale(scale: 0.6 + 0.4 * v, child: child),
          child: const Text('🧰', style: TextStyle(fontSize: 96)),
        ),
        const SizedBox(height: 12),
        const Text('Un cofre te espera al final del camino…',
            style: TextStyle(color: RN.parchmentDim)),
      ],
    );
  }

  Widget _openedChest(GearItem? item, RewardBundle r) {
    if (item == null) {
      return const Text('El cofre estaba vacío… los duendes fueron más rápidos.');
    }
    return ScaleTransition(
      scale: CurvedAnimation(parent: _anim, curve: Curves.elasticOut),
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: item.rarity.color, width: 2),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(item.slot.emoji, style: const TextStyle(fontSize: 48)),
              const SizedBox(height: 8),
              Text(
                item.rarity.label.toUpperCase(),
                style: TextStyle(
                  color: item.rarity.color,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 4),
              Text(item.name,
                  style: fantasyTitle(20), textAlign: TextAlign.center),
              const SizedBox(height: 6),
              Text(
                item.desc,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontSize: 13, color: RN.parchmentDim),
              ),
              const SizedBox(height: 12),
              if (r.duplicate)
                Text(
                  'Ya lo tenías: +${r.duplicateBonusXp} XP extra',
                  style: const TextStyle(color: RN.goldSoft, fontSize: 13),
                )
              else
                TextButton.icon(
                  onPressed: () {
                    widget.controller.equip(item);
                    setState(() {});
                  },
                  icon: const Icon(Icons.check),
                  label: const Text('Equipar ahora'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
