import 'campaign_texts.dart';
import 'player_state.dart';

/// Estado persistente de La Campaña de la Niebla.
class CampaignState {
  /// Capítulos ya leídos (en orden: c1..c12).
  List<String> read;

  /// Decisión ①: '' (pendiente), 'destruir' o 'conservar'.
  String decision1;

  /// Final elegido: '' (pendiente), 'verdad', 'silencio' o 'nombre'.
  String ending;

  /// Momento del final oculto (para la niebla rojiza de 24 h).
  DateTime? endingAt;

  /// Hilo de Himmel: 0 = no conocida, 1..5 = misiones completadas.
  int himmelStage;

  /// Marcas de progreso tomadas al leer ciertos capítulos.
  Map<String, int> marks;

  /// Condiciones acumulativas.
  bool nocturnaDone;
  bool mediaLargaDone;

  /// El cruce "Donde se encontraron" (si el reencuentro ocurrió).
  double? reunionLat;
  double? reunionLng;

  CampaignState({
    List<String>? read,
    this.decision1 = '',
    this.ending = '',
    this.endingAt,
    this.himmelStage = 0,
    Map<String, int>? marks,
    this.nocturnaDone = false,
    this.mediaLargaDone = false,
    this.reunionLat,
    this.reunionLng,
  })  : read = read ?? [],
        marks = marks ?? {};

  bool get himmelLost => ending == 'nombre' && himmelStage < 5;
  bool get nieblaRoja =>
      ending == 'nombre' &&
      endingAt != null &&
      DateTime.now().difference(endingAt!).inHours < 24;

  Map<String, dynamic> toJson() => {
        'read': read,
        'decision1': decision1,
        'ending': ending,
        'endingAt': endingAt?.toIso8601String(),
        'himmelStage': himmelStage,
        'marks': marks,
        'nocturnaDone': nocturnaDone,
        'mediaLargaDone': mediaLargaDone,
        'reunionLat': reunionLat,
        'reunionLng': reunionLng,
      };

  factory CampaignState.fromJson(Map<String, dynamic> json) => CampaignState(
        read: ((json['read'] as List?) ?? []).cast<String>().toList(),
        decision1: json['decision1'] as String? ?? '',
        ending: json['ending'] as String? ?? '',
        endingAt: DateTime.tryParse(json['endingAt'] as String? ?? ''),
        himmelStage: (json['himmelStage'] as num?)?.toInt() ?? 0,
        marks: ((json['marks'] as Map?) ?? {})
            .map((k, v) => MapEntry(k.toString(), (v as num).toInt())),
        nocturnaDone: json['nocturnaDone'] == true,
        mediaLargaDone: json['mediaLargaDone'] == true,
        reunionLat: (json['reunionLat'] as num?)?.toDouble(),
        reunionLng: (json['reunionLng'] as num?)?.toDouble(),
      );
}

/// Definición de un capítulo de la campaña.
class Chapter {
  final String id;
  final String title;
  final String body;
  final int xp;

  /// Descripción humana de la condición de desbloqueo.
  final String conditionText;

  /// Evalúa si la condición está cumplida.
  final bool Function(PlayerState p, CampaignState c) isMet;

  /// ¿Tiene decisión al final? ('' = no; 'decision1' o 'final').
  final String decision;

  const Chapter({
    required this.id,
    required this.title,
    required this.body,
    required this.xp,
    required this.conditionText,
    required this.isMet,
    this.decision = '',
  });
}

/// Los 12 capítulos, en orden. Un capítulo solo puede desbloquearse si el
/// anterior ya fue leído.
final List<Chapter> campaignChapters = [
  Chapter(
    id: 'c1',
    title: c1Title,
    body: c1Body,
    xp: 100,
    conditionText: 'Completa tu primera expedición',
    isMet: (p, c) => p.expeditionsDone >= 1,
  ),
  Chapter(
    id: 'c2',
    title: c2Title,
    body: c2Body,
    xp: 120,
    conditionText: 'Completa 2 expediciones',
    isMet: (p, c) => p.expeditionsDone >= 2,
  ),
  Chapter(
    id: 'c3',
    title: c3Title,
    body: c3Body,
    xp: 150,
    conditionText: 'Completa 1 expedición media o larga',
    isMet: (p, c) => c.mediaLargaDone,
  ),
  Chapter(
    id: 'c4',
    title: c4Title,
    body: c4Body,
    xp: 180,
    conditionText: 'Vence 3 criaturas de la bruma',
    isMet: (p, c) => p.battlesWon >= 3,
  ),
  Chapter(
    id: 'c5',
    title: c5Title,
    body: c5Body,
    xp: 200,
    conditionText: 'Completa 5 expediciones en total',
    isMet: (p, c) => p.expeditionsDone >= 5,
  ),
  Chapter(
    id: 'c6',
    title: c6Title,
    body: c6Body,
    xp: 220,
    conditionText: 'Completa 1 expedición nocturna (después de las 21 h)',
    isMet: (p, c) => c.nocturnaDone,
  ),
  Chapter(
    id: 'c7',
    title: c7Title,
    body: c7Body,
    xp: 250,
    conditionText: 'Completa 1 expedición larga',
    isMet: (p, c) => p.longExpeditionsDone >= 1,
  ),
  Chapter(
    id: 'c8',
    title: c8Title,
    body: c8Body,
    xp: 250,
    conditionText: 'Completa 1 expedición más',
    isMet: (p, c) => p.expeditionsDone > (c.marks['exp@c7'] ?? 999999),
    decision: 'decision1',
  ),
  Chapter(
    id: 'c9',
    title: c9Title,
    body: c9Body,
    xp: 300,
    conditionText: 'Vence al Guardián de la Bruma o completa 25 expediciones',
    isMet: (p, c) =>
        (p.bestiary['guardian'] ?? 0) >= 1 || p.expeditionsDone >= 25,
  ),
  Chapter(
    id: 'c10',
    title: c10Title,
    body: c10Body,
    xp: 300,
    conditionText: 'Completa 2 expediciones largas más',
    isMet: (p, c) =>
        p.longExpeditionsDone >= (c.marks['larga@c9'] ?? 999999) + 2,
  ),
  Chapter(
    id: 'c11',
    title: c11Title,
    body: c11Body,
    xp: 350,
    conditionText: 'Vence al Guardián de la Bruma una vez más',
    isMet: (p, c) =>
        (p.bestiary['guardian'] ?? 0) > (c.marks['guard@c10'] ?? 999999),
  ),
  Chapter(
    id: 'c12',
    title: c12Title,
    body: c12Body,
    xp: 500,
    conditionText: 'Completa 1 expedición más',
    isMet: (p, c) => p.expeditionsDone > (c.marks['exp@c11'] ?? 999999),
    decision: 'final',
  ),
];

Chapter? chapterById(String id) {
  for (final ch in campaignChapters) {
    if (ch.id == id) return ch;
  }
  return null;
}

/// Marcas de progreso que se registran al leer un capítulo (para las
/// condiciones relativas de capítulos posteriores).
void recordChapterMarks(String chapterId, PlayerState p, CampaignState c) {
  switch (chapterId) {
    case 'c7':
      c.marks['exp@c7'] = p.expeditionsDone;
      break;
    case 'c9':
      c.marks['larga@c9'] = p.longExpeditionsDone;
      break;
    case 'c10':
      c.marks['guard@c10'] = p.bestiary['guardian'] ?? 0;
      break;
    case 'c11':
      c.marks['exp@c11'] = p.expeditionsDone;
      break;
  }
}

/// Misiones de Himmel.
class HimmelMission {
  final int stage; // 1..5
  final String title;
  final String intro;
  final String outro;
  final int xp;

  /// tier de la ruta (0 corta, 1 media); -1 = sin caminata (solo escena).
  final int tier;

  const HimmelMission({
    required this.stage,
    required this.title,
    required this.intro,
    required this.outro,
    required this.xp,
    required this.tier,
  });
}

final List<HimmelMission> himmelMissions = [
  HimmelMission(
      stage: 1,
      title: h1Title,
      intro: h1Intro,
      outro: h1Outro,
      xp: 150,
      tier: 0),
  HimmelMission(
      stage: 2,
      title: h2Title,
      intro: h2Intro,
      outro: h2Outro,
      xp: 200,
      tier: 1),
  HimmelMission(
      stage: 3,
      title: h3Title,
      intro: h3Intro,
      outro: h3Outro,
      xp: 250,
      tier: 1),
  HimmelMission(
      stage: 4,
      title: h4Title,
      intro: h4Body,
      outro: '',
      xp: 200,
      tier: -1),
  HimmelMission(
      stage: 5,
      title: h5Title,
      intro: h5Intro,
      outro: h5Outro,
      xp: 400,
      tier: 1),
];

/// Requisito de capítulo leído para cada misión de Himmel.
String himmelRequiredChapter(int stage) {
  switch (stage) {
    case 1:
      return 'c3';
    case 2:
      return 'c5';
    case 3:
      return 'c7';
    case 4:
    case 5:
      return 'c10';
    default:
      return 'c12';
  }
}
