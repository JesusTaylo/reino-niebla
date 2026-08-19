import 'package:flutter/material.dart';

enum Rarity { comun, raro, epico, legendario }

extension RarityInfo on Rarity {
  String get label {
    switch (this) {
      case Rarity.comun:
        return 'Común';
      case Rarity.raro:
        return 'Raro';
      case Rarity.epico:
        return 'Épico';
      case Rarity.legendario:
        return 'Legendario';
    }
  }

  Color get color {
    switch (this) {
      case Rarity.comun:
        return const Color(0xFF9BA1A6);
      case Rarity.raro:
        return const Color(0xFF4F8FF7);
      case Rarity.epico:
        return const Color(0xFFB05CE0);
      case Rarity.legendario:
        return const Color(0xFFE8A83D);
    }
  }
}

enum GearSlot { yelmo, capa, tunica, reliquia }

extension GearSlotInfo on GearSlot {
  String get label {
    switch (this) {
      case GearSlot.yelmo:
        return 'Yelmo';
      case GearSlot.capa:
        return 'Capa';
      case GearSlot.tunica:
        return 'Túnica';
      case GearSlot.reliquia:
        return 'Reliquia';
    }
  }

  String get emoji {
    switch (this) {
      case GearSlot.yelmo:
        return '🪖';
      case GearSlot.capa:
        return '🧣';
      case GearSlot.tunica:
        return '👕';
      case GearSlot.reliquia:
        return '🧭';
    }
  }
}

class GearItem {
  final String id;
  final String name;
  final String desc;
  final GearSlot slot;
  final Rarity rarity;

  /// Color principal y secundario usados por el pintor del avatar.
  final Color colorA;
  final Color colorB;

  /// Variante de forma que dibuja el pintor (depende del slot).
  final int variant;

  const GearItem({
    required this.id,
    required this.name,
    required this.desc,
    required this.slot,
    required this.rarity,
    required this.colorA,
    required this.colorB,
    required this.variant,
  });
}

/// Catálogo completo de equipo del juego.
const List<GearItem> gearCatalog = [
  // ---- Yelmos ----
  GearItem(
    id: 'capucha_lino',
    name: 'Capucha de Lino',
    desc: 'Sencilla pero digna. Todo cartógrafo empieza con una.',
    slot: GearSlot.yelmo,
    rarity: Rarity.comun,
    colorA: Color(0xFFA1887F),
    colorB: Color(0xFF795548),
    variant: 1,
  ),
  GearItem(
    id: 'capucha_verde',
    name: 'Capucha del Sendero',
    desc: 'Teñida con hierbas del camino real.',
    slot: GearSlot.yelmo,
    rarity: Rarity.comun,
    colorA: Color(0xFF6B8E4E),
    colorB: Color(0xFF4A6334),
    variant: 1,
  ),
  GearItem(
    id: 'gorro_cartografo',
    name: 'Gorro del Cartógrafo',
    desc: 'Con pluma de halcón mensajero. Marca de oficio.',
    slot: GearSlot.yelmo,
    rarity: Rarity.raro,
    colorA: Color(0xFF3F5E9E),
    colorB: Color(0xFFC94F4F),
    variant: 2,
  ),
  GearItem(
    id: 'casco_explorador',
    name: 'Casco del Explorador',
    desc: 'Forjado para quienes cruzan la Niebla sin miedo.',
    slot: GearSlot.yelmo,
    rarity: Rarity.raro,
    colorA: Color(0xFF8C9BA5),
    colorB: Color(0xFF5C6B75),
    variant: 3,
  ),
  GearItem(
    id: 'yelmo_alado',
    name: 'Yelmo Alado',
    desc: 'Dicen que quien lo porta nunca siente cansancio en los pies.',
    slot: GearSlot.yelmo,
    rarity: Rarity.epico,
    colorA: Color(0xFFD4AF37),
    colorB: Color(0xFFF5E6C4),
    variant: 4,
  ),
  GearItem(
    id: 'corona_brumas',
    name: 'Corona de las Brumas',
    desc: 'Reliquia del primer rey que caminó todo su reino a pie.',
    slot: GearSlot.yelmo,
    rarity: Rarity.legendario,
    colorA: Color(0xFFB8E0E8),
    colorB: Color(0xFF6BC5D2),
    variant: 5,
  ),

  // ---- Capas ----
  GearItem(
    id: 'capa_viajero',
    name: 'Capa del Viajero',
    desc: 'Ha visto más caminos que muchas botas.',
    slot: GearSlot.capa,
    rarity: Rarity.comun,
    colorA: Color(0xFF7A5C43),
    colorB: Color(0xFF5A4330),
    variant: 1,
  ),
  GearItem(
    id: 'capa_escarlata',
    name: 'Capa Escarlata',
    desc: 'Visible desde la torre más lejana del reino.',
    slot: GearSlot.capa,
    rarity: Rarity.comun,
    colorA: Color(0xFFA83C3C),
    colorB: Color(0xFF7E2B2B),
    variant: 1,
  ),
  GearItem(
    id: 'capa_bosque',
    name: 'Capa del Bosque',
    desc: 'Bordada con hilo de oro por los guardas del sendero.',
    slot: GearSlot.capa,
    rarity: Rarity.raro,
    colorA: Color(0xFF3E6B4A),
    colorB: Color(0xFFD4AF37),
    variant: 2,
  ),
  GearItem(
    id: 'capa_azur',
    name: 'Capa Azur',
    desc: 'Del color del cielo tras despejarse la Niebla.',
    slot: GearSlot.capa,
    rarity: Rarity.raro,
    colorA: Color(0xFF33548F),
    colorB: Color(0xFFD4AF37),
    variant: 2,
  ),
  GearItem(
    id: 'capa_estelar',
    name: 'Capa Estelar',
    desc: 'Cosida con fragmentos de noche despejada.',
    slot: GearSlot.capa,
    rarity: Rarity.epico,
    colorA: Color(0xFF2C2A5E),
    colorB: Color(0xFFEFE3AE),
    variant: 3,
  ),
  GearItem(
    id: 'capa_del_alba',
    name: 'Capa del Alba',
    desc: 'Tejida con la primera luz que tocó el reino.',
    slot: GearSlot.capa,
    rarity: Rarity.legendario,
    colorA: Color(0xFFE8A83D),
    colorB: Color(0xFFF2D8A0),
    variant: 3,
  ),

  // ---- Túnicas ----
  GearItem(
    id: 'tunica_lino',
    name: 'Túnica de Lino',
    desc: 'Cómoda para caminar leguas enteras.',
    slot: GearSlot.tunica,
    rarity: Rarity.comun,
    colorA: Color(0xFFC9B896),
    colorB: Color(0xFF9C8A66),
    variant: 1,
  ),
  GearItem(
    id: 'tunica_gris',
    name: 'Túnica del Peregrino',
    desc: 'Gris como la niebla que estás por desterrar.',
    slot: GearSlot.tunica,
    rarity: Rarity.comun,
    colorA: Color(0xFF8A8F94),
    colorB: Color(0xFF62676B),
    variant: 1,
  ),
  GearItem(
    id: 'jubon_cuero',
    name: 'Jubón de Cuero',
    desc: 'Con cinturón para colgar mapas y brújulas.',
    slot: GearSlot.tunica,
    rarity: Rarity.raro,
    colorA: Color(0xFF8B5E3C),
    colorB: Color(0xFF553622),
    variant: 2,
  ),
  GearItem(
    id: 'cota_escamas',
    name: 'Cota de Escamas',
    desc: 'Ligera como brisa, firme como muralla.',
    slot: GearSlot.tunica,
    rarity: Rarity.epico,
    colorA: Color(0xFF5E7A8A),
    colorB: Color(0xFF3D525E),
    variant: 3,
  ),
  GearItem(
    id: 'armadura_real',
    name: 'Armadura del Cartógrafo Real',
    desc: 'Solo la visten quienes han cartografiado un reino entero.',
    slot: GearSlot.tunica,
    rarity: Rarity.legendario,
    colorA: Color(0xFFD4AF37),
    colorB: Color(0xFF8A6D1F),
    variant: 3,
  ),

  // ---- Reliquias ----
  GearItem(
    id: 'brujula_laton',
    name: 'Brújula de Latón',
    desc: 'Apunta al norte... la mayoría de las veces.',
    slot: GearSlot.reliquia,
    rarity: Rarity.comun,
    colorA: Color(0xFFB08D57),
    colorB: Color(0xFFF0E6D2),
    variant: 1,
  ),
  GearItem(
    id: 'mapa_viejo',
    name: 'Mapa del Reino Antiguo',
    desc: 'Sus bordes quemados guardan secretos.',
    slot: GearSlot.reliquia,
    rarity: Rarity.comun,
    colorA: Color(0xFFD8C49A),
    colorB: Color(0xFF8B5E3C),
    variant: 2,
  ),
  GearItem(
    id: 'farol_ambar',
    name: 'Farol de Ámbar',
    desc: 'Su luz atraviesa la Niebla más espesa.',
    slot: GearSlot.reliquia,
    rarity: Rarity.raro,
    colorA: Color(0xFF4E4A45),
    colorB: Color(0xFFF2B94A),
    variant: 3,
  ),
  GearItem(
    id: 'catalejo_capitan',
    name: 'Catalejo del Capitán',
    desc: 'Ve tres colinas más allá que cualquier ojo.',
    slot: GearSlot.reliquia,
    rarity: Rarity.raro,
    colorA: Color(0xFF6E4F2F),
    colorB: Color(0xFFB08D57),
    variant: 4,
  ),
  GearItem(
    id: 'estandarte_reino',
    name: 'Estandarte del Reino',
    desc: 'Plántalo donde la Niebla retroceda ante ti.',
    slot: GearSlot.reliquia,
    rarity: Rarity.epico,
    colorA: Color(0xFF7A2E3C),
    colorB: Color(0xFFD4AF37),
    variant: 5,
  ),
  GearItem(
    id: 'brujula_celeste',
    name: 'Brújula Celeste',
    desc: 'No apunta al norte: apunta a tu próxima aventura.',
    slot: GearSlot.reliquia,
    rarity: Rarity.legendario,
    colorA: Color(0xFF6BC5D2),
    colorB: Color(0xFFEAF7FA),
    variant: 1,
  ),
];

GearItem? gearById(String id) {
  for (final item in gearCatalog) {
    if (item.id == id) return item;
  }
  return null;
}
