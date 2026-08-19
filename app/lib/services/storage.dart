import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/player_state.dart';
import '../models/quest.dart';

/// Guardado local en JSON dentro de los documentos de la app.
class Storage {
  static Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/reino_niebla_save.json');
  }

  static Future<({PlayerState player, Quest? activeQuest})> load() async {
    try {
      final f = await _file();
      if (!await f.exists()) {
        return (player: PlayerState.newPlayer(), activeQuest: null);
      }
      final data = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
      final player = PlayerState.fromJson(
          (data['player'] as Map?)?.cast<String, dynamic>() ?? {});
      Quest? quest;
      if (data['activeQuest'] is Map) {
        quest = Quest.fromJson(
            (data['activeQuest'] as Map).cast<String, dynamic>());
      }
      return (player: player, activeQuest: quest);
    } catch (_) {
      // Si el guardado se corrompe, empezamos limpio antes que crashear.
      return (player: PlayerState.newPlayer(), activeQuest: null);
    }
  }

  static Future<void> save(PlayerState player, Quest? activeQuest) async {
    try {
      final f = await _file();
      final data = {
        'player': player.toJson(),
        'activeQuest': activeQuest?.toJson(),
        'savedAt': DateTime.now().toIso8601String(),
      };
      await f.writeAsString(jsonEncode(data), flush: true);
    } catch (_) {
      // No interrumpir el juego por un error de escritura puntual.
    }
  }
}
