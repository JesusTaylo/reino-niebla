import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../game_controller.dart';
import '../models/campaign.dart';
import '../models/campaign_texts.dart';
import '../theme.dart';

/// Estilo compartido de "pergamino" para la narrativa.
class ParchmentBody extends StatelessWidget {
  final String text;

  const ParchmentBody({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text.trim(),
      style: const TextStyle(
        fontFamily: 'serif',
        fontSize: 16,
        height: 1.55,
        color: RN.parchment,
      ),
    );
  }
}

/// Lector de capítulos de la campaña (carta lacrada).
class ChapterScreen extends StatefulWidget {
  final GameController controller;
  final Chapter chapter;

  const ChapterScreen({
    super.key,
    required this.controller,
    required this.chapter,
  });

  @override
  State<ChapterScreen> createState() => _ChapterScreenState();
}

class _ChapterScreenState extends State<ChapterScreen> {
  String _outcomeText = '';

  GameController get game => widget.controller;
  Chapter get chapter => widget.chapter;
  CampaignState get camp => game.player.campaign;

  @override
  void initState() {
    super.initState();
    HapticFeedback.mediumImpact();
    // Recompensas al abrir por primera vez.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      game.markChapterRead(chapter);
    });
  }

  bool get _needsDecision1 =>
      chapter.decision == 'decision1' && camp.decision1.isEmpty;
  bool get _needsEnding =>
      chapter.decision == 'final' && camp.ending.isEmpty;

  bool get _canClose =>
      !_needsDecision1 && !_needsEnding || _outcomeText.isNotEmpty;

  String get _fullBody {
    var body = chapter.body;
    // Capítulo 10: la página cifrada solo existe si conservaste la denuncia.
    if (chapter.id == 'c10' && camp.decision1 == 'conservar') {
      body += c10Cifrada;
    }
    // Relecturas: mostrar el desenlace ya elegido.
    if (chapter.id == 'c8' && camp.decision1.isNotEmpty &&
        _outcomeText.isEmpty) {
      body += '\n⸻\n${camp.decision1 == 'destruir' ? c8OutcomeDestroy : c8OutcomeKeep}';
    }
    if (chapter.id == 'c12' && camp.ending.isNotEmpty &&
        _outcomeText.isEmpty) {
      body += '\n⸻\n${_endingText(camp.ending)}';
    }
    return body;
  }

  String _endingText(String ending) {
    switch (ending) {
      case 'verdad':
        return endingTruth;
      case 'silencio':
        return endingSilence;
      case 'nombre':
        var t = endingName;
        if (camp.himmelLost) {
          t += '\n⸻\n$endingNameHimmelLost';
        }
        return t;
      default:
        return '';
    }
  }

  void _decide1(String choice) {
    game.applyDecision1(choice);
    HapticFeedback.heavyImpact();
    setState(() {
      _outcomeText =
          choice == 'destruir' ? c8OutcomeDestroy : c8OutcomeKeep;
    });
  }

  void _decideEnding(String choice) {
    game.applyEnding(choice);
    HapticFeedback.heavyImpact();
    setState(() {
      _outcomeText = _endingText(choice);
    });
  }

  @override
  Widget build(BuildContext context) {
    final showNameOption =
        camp.decision1 == 'conservar' && camp.read.contains('c10');

    return PopScope(
      canPop: _canClose,
      child: Scaffold(
        backgroundColor: RN.night,
        appBar: AppBar(
          automaticallyImplyLeading: _canClose,
          title: Text('📖 ${chapter.title}', style: fantasyTitle(18)),
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(22, 10, 22, 24),
            children: [
              Center(
                child: Text(
                  '— Capítulo ${campaignChapters.indexOf(chapter) + 1} —',
                  style: const TextStyle(
                      color: RN.goldSoft, letterSpacing: 2, fontSize: 12),
                ),
              ),
              const SizedBox(height: 14),
              ParchmentBody(text: _fullBody),

              if (_outcomeText.isNotEmpty) ...[
                const Divider(color: Colors.white24, height: 32),
                ParchmentBody(text: _outcomeText),
              ],

              const SizedBox(height: 22),

              // ---- Decisión ① ----
              if (_needsDecision1 && _outcomeText.isEmpty) ...[
                FilledButton(
                  onPressed: () => _decide1('destruir'),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text(c8OptionDestroy),
                  ),
                ),
                const SizedBox(height: 10),
                FilledButton.tonal(
                  onPressed: () => _decide1('conservar'),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text(c8OptionKeep),
                  ),
                ),
              ],

              // ---- El final ----
              if (_needsEnding && _outcomeText.isEmpty) ...[
                FilledButton(
                  onPressed: () => _decideEnding('verdad'),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text(endingTruthLabel),
                  ),
                ),
                const SizedBox(height: 10),
                FilledButton.tonal(
                  onPressed: () => _decideEnding('silencio'),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text(endingSilenceLabel),
                  ),
                ),
                if (showNameOption) ...[
                  const SizedBox(height: 10),
                  // Un renglón vacío que tiembla apenas. Sin etiqueta.
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.25, end: 0.55),
                    duration: const Duration(seconds: 2),
                    curve: Curves.easeInOut,
                    builder: (context, v, child) =>
                        Opacity(opacity: v, child: child),
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                            color: RN.danger.withValues(alpha: 0.4)),
                      ),
                      onPressed: () => _decideEnding('nombre'),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text(endingNameLabel),
                      ),
                    ),
                  ),
                ],
              ],

              if (_canClose) ...[
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('Cerrar la carta'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Escenas del hilo de Himmel: introducción (antes de caminar) o
/// desenlace (tras completar la ruta).
class HimmelSceneScreen extends StatefulWidget {
  final GameController controller;
  final HimmelMission mission;

  /// true = mostrar intro con botón de iniciar ruta; false = desenlace.
  final bool isIntro;

  const HimmelSceneScreen({
    super.key,
    required this.controller,
    required this.mission,
    required this.isIntro,
  });

  @override
  State<HimmelSceneScreen> createState() => _HimmelSceneScreenState();
}

class _HimmelSceneScreenState extends State<HimmelSceneScreen> {
  bool _generating = false;
  String? _error;

  GameController get game => widget.controller;
  HimmelMission get mission => widget.mission;

  Future<void> _start() async {
    setState(() {
      _generating = true;
      _error = null;
    });
    final ok = await game.startHimmelMission(mission);
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop();
    } else {
      setState(() {
        _generating = false;
        _error = 'La Niebla es espesa: no se pudo trazar la ruta. '
            'Revisa tu conexión e inténtalo de nuevo.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = widget.isIntro ? mission.intro : mission.outro;
    final showRelicChoice = !widget.isIntro &&
        mission.stage == 5 &&
        game.reunionRelicPending;

    return Scaffold(
      backgroundColor: RN.night,
      appBar: AppBar(
        title: Text('🏹 ${mission.title}', style: fantasyTitle(18)),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 10, 22, 24),
          children: [
            ParchmentBody(text: text),
            const SizedBox(height: 22),

            if (_error != null) ...[
              Text(_error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: RN.danger)),
              const SizedBox(height: 10),
            ],

            if (widget.isIntro && mission.tier >= 0)
              FilledButton(
                onPressed: _generating ? null : _start,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(_generating
                      ? 'Trazando la ruta…'
                      : '⚔️ Preparar la ruta'),
                ),
              )
            else if (showRelicChoice) ...[
              Text('Eligen dejarte un recuerdo. ¿Cuál aceptas?',
                  textAlign: TextAlign.center,
                  style: fantasyTitle(15, color: RN.goldSoft)),
              const SizedBox(height: 10),
              FilledButton(
                onPressed: () {
                  game.chooseReunionRelic('martillo_ram');
                  setState(() {});
                },
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text('🔨 El Martillo de Ram'),
                ),
              ),
              const SizedBox(height: 10),
              FilledButton.tonal(
                onPressed: () {
                  game.chooseReunionRelic('silbato_himmel');
                  setState(() {});
                },
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text('🎶 El Silbato de Himmel'),
                ),
              ),
            ] else
              FilledButton(
                onPressed: () {
                  game.clearHimmelScene();
                  Navigator.of(context).pop();
                },
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text('Continuar'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Emblema del cruce del reencuentro (usado como marcador en el mapa).
class ReunionMarker extends StatelessWidget {
  const ReunionMarker({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: RN.night.withValues(alpha: 0.85),
        border: Border.all(color: RN.goldSoft, width: 1.5),
      ),
      alignment: Alignment.center,
      child: const Text('🫂', style: TextStyle(fontSize: 18)),
    );
  }
}
