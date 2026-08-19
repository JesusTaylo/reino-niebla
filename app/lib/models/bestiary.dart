import 'dart:math' as math;

/// Materiales que sueltan las criaturas de la bruma.
class MaterialSpec {
  final String id;
  final String name;
  final String emoji;

  const MaterialSpec(this.id, this.name, this.emoji);
}

const List<MaterialSpec> materialCatalog = [
  MaterialSpec('colmillo_lobo', 'Colmillo de lobo', '🦷'),
  MaterialSpec('gel_slime', 'Gel de slime', '🫧'),
  MaterialSpec('hueso_runico', 'Hueso rúnico', '🦴'),
  MaterialSpec('moneda_duende', 'Moneda de duende', '🪙'),
  MaterialSpec('esencia_espectral', 'Esencia espectral', '🔮'),
  MaterialSpec('nucleo_bruma', 'Núcleo de bruma', '💠'),
];

MaterialSpec? materialById(String id) {
  for (final m in materialCatalog) {
    if (m.id == id) return m;
  }
  return null;
}

/// Especie de criatura de la bruma.
class EnemySpec {
  final String id;
  final String name;
  final String emoji;
  final String flavor;
  final int hpBase;
  final int atkBase;
  final int xpBase;
  final int minPlayerLevel;
  final String materialId;
  final int spawnWeight;
  final bool isBoss;

  const EnemySpec({
    required this.id,
    required this.name,
    required this.emoji,
    required this.flavor,
    required this.hpBase,
    required this.atkBase,
    required this.xpBase,
    required this.minPlayerLevel,
    required this.materialId,
    required this.spawnWeight,
    this.isBoss = false,
  });
}

const List<EnemySpec> enemyCatalog = [
  EnemySpec(
    id: 'lobo',
    name: 'Lobo de Bruma',
    emoji: '🐺',
    flavor: 'Sus aullidos se confunden con el viento entre la niebla.',
    hpBase: 18,
    atkBase: 5,
    xpBase: 25,
    minPlayerLevel: 1,
    materialId: 'colmillo_lobo',
    spawnWeight: 30,
  ),
  EnemySpec(
    id: 'slime',
    name: 'Slime de Niebla',
    emoji: '🟢',
    flavor: 'Nadie sabe si es niebla condensada o algo peor.',
    hpBase: 26,
    atkBase: 4,
    xpBase: 22,
    minPlayerLevel: 1,
    materialId: 'gel_slime',
    spawnWeight: 28,
  ),
  EnemySpec(
    id: 'esqueleto',
    name: 'Esqueleto Errante',
    emoji: '💀',
    flavor: 'Un explorador que nunca completó su última expedición.',
    hpBase: 24,
    atkBase: 7,
    xpBase: 35,
    minPlayerLevel: 2,
    materialId: 'hueso_runico',
    spawnWeight: 22,
  ),
  EnemySpec(
    id: 'duende',
    name: 'Duende Ladrón',
    emoji: '👺',
    flavor: 'Colecciona monedas de reinos que ya no existen.',
    hpBase: 20,
    atkBase: 6,
    xpBase: 30,
    minPlayerLevel: 3,
    materialId: 'moneda_duende',
    spawnWeight: 15,
  ),
  EnemySpec(
    id: 'espectro',
    name: 'Espectro de la Niebla',
    emoji: '👻',
    flavor: 'Donde la niebla es más espesa, algo antiguo observa.',
    hpBase: 30,
    atkBase: 9,
    xpBase: 55,
    minPlayerLevel: 5,
    materialId: 'esencia_espectral',
    spawnWeight: 5,
  ),
  EnemySpec(
    id: 'guardian',
    name: 'Guardián de la Bruma',
    emoji: '🗿',
    flavor: 'El coloso que mantiene la Niebla sobre el reino. Solo los '
        'grandes caminantes lo despiertan.',
    hpBase: 60,
    atkBase: 10,
    xpBase: 130,
    minPlayerLevel: 1,
    materialId: 'nucleo_bruma',
    spawnWeight: 0, // solo aparece en rutas largas, con tirada especial
    isBoss: true,
  ),
];

EnemySpec? enemyById(String id) {
  for (final e in enemyCatalog) {
    if (e.id == id) return e;
  }
  return null;
}

/// Nombres de las variantes élite de cada especie (índices 0-2).
const Map<String, List<String>> enemyVariantNames = {
  'slime': ['Slime de Niebla', 'Slime Escarchado', 'Slime Abisal'],
  'lobo': ['Lobo de Bruma', 'Lobo Alfa', 'Lobo Espectral'],
  'esqueleto': ['Esqueleto Errante', 'Capitán Caído', 'Esqueleto Rúnico'],
  'duende': ['Duende Ladrón', 'Duende Saqueador', 'Duende Chamán'],
  'espectro': [
    'Espectro de la Niebla',
    'Espectro del Lamento',
    'Espectro Ancestral'
  ],
  'guardian': [
    'Guardián de la Bruma',
    'Guardián Despierto',
    'Guardián Ancestral'
  ],
};

/// Una criatura concreta, escalada al nivel del jugador.
class Enemy {
  final EnemySpec spec;
  final int level;
  final int maxHp;
  final int atk;
  final int xp;

  Enemy(this.spec, this.level, this.maxHp, this.atk, this.xp);

  /// Variante visual según el nivel (0 base, 1 y 2 élites).
  int get variantIndex => spec.isBoss
      ? (level >= 10 ? 2 : (level >= 5 ? 1 : 0))
      : (level >= 8 ? 2 : (level >= 4 ? 1 : 0));

  /// Nombre mostrado (las élites tienen nombre propio).
  String get displayName =>
      enemyVariantNames[spec.id]?[variantIndex] ?? spec.name;

  /// Ruta del sprite correspondiente.
  String get spritePath =>
      'assets/enemies/${spec.id}_$variantIndex.png';

  factory Enemy.scaled(EnemySpec spec, int playerLevel) {
    final l = math.max(1, playerLevel);
    final growth = spec.isBoss ? 7 : 4;
    return Enemy(
      spec,
      l,
      spec.hpBase + (l - 1) * growth,
      spec.atkBase + (l - 1),
      spec.xpBase + (l - 1) * 6,
    );
  }

  /// Elige una criatura común elegible para el nivel dado.
  static Enemy randomFor(int playerLevel, math.Random rng) {
    final pool = enemyCatalog
        .where((e) => !e.isBoss && e.minPlayerLevel <= playerLevel)
        .toList();
    final total = pool.fold<int>(0, (s, e) => s + e.spawnWeight);
    var roll = rng.nextInt(total);
    for (final e in pool) {
      if (roll < e.spawnWeight) return Enemy.scaled(e, playerLevel);
      roll -= e.spawnWeight;
    }
    return Enemy.scaled(pool.first, playerLevel);
  }

  static Enemy boss(int playerLevel) =>
      Enemy.scaled(enemyById('guardian')!, playerLevel);
}
