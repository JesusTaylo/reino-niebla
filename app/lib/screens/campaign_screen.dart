import 'package:flutter/material.dart';

import '../game_controller.dart';
import '../models/campaign.dart';
import '../models/campaign_texts.dart';
import '../theme.dart';
import 'chapter_screen.dart';

/// Índice de La Campaña de la Niebla.
class CampaignScreen extends StatelessWidget {
  final GameController controller;

  const CampaignScreen({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('📖 La Campaña de la Niebla', style: fantasyTitle(19)),
      ),
      body: ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          final camp = controller.player.campaign;
          final read = camp.read;

          // El primer capítulo sin leer (el único desbloqueable).
          String? nextId;
          for (final ch in campaignChapters) {
            if (!read.contains(ch.id)) {
              nextId = ch.id;
              break;
            }
          }

          final himmelNext = controller.himmelAvailable();
          final showHimmelSection =
              read.contains('c3') || camp.himmelStage > 0 || camp.himmelLost;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'Hace cien años, la Niebla devoró los mapas del reino. '
                'Camina, y la historia vendrá a buscarte.',
                textAlign: TextAlign.center,
                style: TextStyle(color: RN.parchmentDim, fontSize: 12.5),
              ),
              const SizedBox(height: 14),

              // ---- Hilo de Himmel ----
              if (showHimmelSection) ...[
                _himmelCard(context, camp, himmelNext),
                const SizedBox(height: 14),
              ],

              // ---- Capítulos ----
              for (var i = 0; i < campaignChapters.length; i++)
                _chapterTile(context, i, campaignChapters[i], camp, nextId),
            ],
          );
        },
      ),
    );
  }

  Widget _himmelCard(
      BuildContext context, CampaignState camp, HimmelMission? himmelNext) {
    String subtitle;
    VoidCallback? onTap;
    String emoji = '🏹';

    if (camp.himmelLost) {
      emoji = '🌫️';
      subtitle = endingNameHimmelLost;
    } else if (camp.himmelStage >= 5) {
      emoji = '🫂';
      subtitle = 'Donde se encontraron. Una sola fogata en vez de dos.';
      onTap = () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => HimmelSceneScreen(
              controller: controller,
              mission: himmelMissions[4],
              isIntro: false,
            ),
          ));
    } else if (himmelNext != null) {
      final m = himmelNext;
      subtitle = 'Misión ${m.stage} de 5: "${m.title}" — tócala para empezar';
      onTap = () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => HimmelSceneScreen(
              controller: controller,
              mission: m,
              isIntro: true,
            ),
          ));
    } else if (controller.activeQuest?.himmelStage != null &&
        (controller.activeQuest?.himmelStage ?? 0) > 0) {
      subtitle = 'Misión en curso: camina la ruta de Himmel.';
    } else {
      subtitle = 'Himmel aguarda. Avanza la campaña para ayudarla.';
    }

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: RN.teal.withValues(alpha: 0.5)),
      ),
      child: ListTile(
        leading: Text(emoji, style: const TextStyle(fontSize: 26)),
        title: Text('El hilo de Himmel y Ram',
            style: fantasyTitle(15, color: RN.teal)),
        subtitle: Text(subtitle,
            style: const TextStyle(fontSize: 12, color: RN.parchmentDim)),
        onTap: onTap,
      ),
    );
  }

  Widget _chapterTile(BuildContext context, int index, Chapter chapter,
      CampaignState camp, String? nextId) {
    final isRead = camp.read.contains(chapter.id);
    final isNext = chapter.id == nextId;
    final isMet = isNext && chapter.isMet(controller.player, camp);

    String title;
    String subtitle;
    Widget leading;
    VoidCallback? onTap;

    if (isRead) {
      title = chapter.title;
      subtitle = 'Leído · toca para releer';
      leading = const Text('📜', style: TextStyle(fontSize: 22));
      onTap = () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) =>
                ChapterScreen(controller: controller, chapter: chapter),
          ));
    } else if (isNext && isMet) {
      title = chapter.title;
      subtitle = '✉️ ¡Carta lacrada! Tócala para abrirla';
      leading = const Text('✉️', style: TextStyle(fontSize: 22));
      onTap = () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) =>
                ChapterScreen(controller: controller, chapter: chapter),
          ));
    } else if (isNext) {
      title = 'Capítulo ${index + 1}';
      subtitle = '🔒 ${chapter.conditionText}';
      leading = const Text('🔒', style: TextStyle(fontSize: 20));
    } else {
      title = 'Capítulo ${index + 1}';
      subtitle = '· · ·';
      leading = const Opacity(
        opacity: 0.35,
        child: Text('🌫️', style: TextStyle(fontSize: 20)),
      );
    }

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isNext && isMet
              ? RN.gold
              : Colors.white.withValues(alpha: isRead ? 0.2 : 0.06),
        ),
      ),
      child: ListTile(
        dense: true,
        leading: leading,
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: isRead || (isNext && isMet)
                ? RN.parchment
                : RN.parchmentDim,
          ),
        ),
        subtitle: Text(subtitle,
            style: const TextStyle(fontSize: 11.5, color: RN.parchmentDim)),
        onTap: onTap,
      ),
    );
  }
}
