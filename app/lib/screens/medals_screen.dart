import 'package:flutter/material.dart';

import '../game_controller.dart';
import '../models/medals.dart';
import '../theme.dart';
import '../util/geo.dart';

class MedalsScreen extends StatelessWidget {
  final GameController controller;

  const MedalsScreen({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Salón de Medallas', style: fantasyTitle(22)),
      ),
      body: ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          final player = controller.player;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Estadísticas del explorador.
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text(
                          player.name.isEmpty
                              ? 'Crónica del Explorador'
                              : 'Crónica de ${player.name}',
                          style: fantasyTitle(18, color: RN.goldSoft)),
                      Text(player.title,
                          style: const TextStyle(
                              fontSize: 12, color: RN.parchmentDim)),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _stat('🥾', formatKm(player.totalMeters),
                              'caminados'),
                          _stat('🗺️', '${player.expeditionsDone}',
                              'expediciones'),
                          _stat('🌫️', '${player.explored.length}',
                              'zonas despejadas'),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.95,
                children: [
                  for (final medal in medalCatalog)
                    _MedalTile(
                      medal: medal,
                      earned: player.medals.contains(medal.id),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _stat(String emoji, String value, String label) {
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 22)),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(
                fontWeight: FontWeight.bold, fontSize: 16, color: RN.gold)),
        Text(label,
            style: const TextStyle(fontSize: 11, color: RN.parchmentDim)),
      ],
    );
  }
}

class _MedalTile extends StatelessWidget {
  final Medal medal;
  final bool earned;

  const _MedalTile({required this.medal, required this.earned});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: earned
                    ? RN.gold.withValues(alpha: 0.22)
                    : Colors.white.withValues(alpha: 0.05),
                border: Border.all(
                  color: earned ? RN.gold : Colors.white24,
                  width: 2,
                ),
              ),
              alignment: Alignment.center,
              child: Opacity(
                opacity: earned ? 1 : 0.35,
                child:
                    Text(medal.emoji, style: const TextStyle(fontSize: 26)),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              medal.name,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: earned ? RN.parchment : RN.parchmentDim,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              medal.desc,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 10.5, color: RN.parchmentDim),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
