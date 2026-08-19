class Medal {
  final String id;
  final String name;
  final String desc;
  final String emoji;

  const Medal({
    required this.id,
    required this.name,
    required this.desc,
    required this.emoji,
  });
}

const List<Medal> medalCatalog = [
  Medal(
    id: 'primera_expedicion',
    name: 'Primeros Pasos',
    desc: 'Completa tu primera expedición.',
    emoji: '🥾',
  ),
  Medal(
    id: 'exp_5',
    name: 'Explorador Constante',
    desc: 'Completa 5 expediciones.',
    emoji: '🧭',
  ),
  Medal(
    id: 'exp_25',
    name: 'Veterano del Camino',
    desc: 'Completa 25 expediciones.',
    emoji: '🛡️',
  ),
  Medal(
    id: 'exp_100',
    name: 'Leyenda Andante',
    desc: 'Completa 100 expediciones.',
    emoji: '👑',
  ),
  Medal(
    id: 'km_10',
    name: 'Diez Leguas',
    desc: 'Camina 10 km en expediciones.',
    emoji: '🏞️',
  ),
  Medal(
    id: 'km_50',
    name: 'Cincuenta Reales',
    desc: 'Camina 50 km en expediciones.',
    emoji: '⛰️',
  ),
  Medal(
    id: 'km_150',
    name: 'Rompebotas',
    desc: 'Camina 150 km en expediciones.',
    emoji: '🔥',
  ),
  Medal(
    id: 'km_500',
    name: 'Conquistador del Reino',
    desc: 'Camina 500 km en expediciones.',
    emoji: '🏰',
  ),
  Medal(
    id: 'larga_1',
    name: 'Gran Travesía',
    desc: 'Completa una expedición larga.',
    emoji: '🗻',
  ),
  Medal(
    id: 'madrugador',
    name: 'Alba Temprana',
    desc: 'Completa una expedición antes de las 8 de la mañana.',
    emoji: '🌅',
  ),
  Medal(
    id: 'noctambulo',
    name: 'Guardián Nocturno',
    desc: 'Completa una expedición después de las 9 de la noche.',
    emoji: '🌙',
  ),
  Medal(
    id: 'niebla_1000',
    name: 'Destierra-Nieblas',
    desc: 'Despeja 1000 zonas de niebla del mapa.',
    emoji: '🌫️',
  ),
];

Medal? medalById(String id) {
  for (final m in medalCatalog) {
    if (m.id == id) return m;
  }
  return null;
}
