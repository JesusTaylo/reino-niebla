import 'package:flutter/material.dart';

import '../game_controller.dart';
import '../models/items.dart';
import '../models/player_state.dart';
import '../theme.dart';
import '../widgets/avatar_view.dart';

/// El Espejo Mágico: creación y edición del personaje.
class CharacterCreatorScreen extends StatefulWidget {
  final GameController controller;

  /// true en el primer arranque (botón "Comenzar aventura", sin volver atrás).
  final bool firstTime;

  const CharacterCreatorScreen({
    super.key,
    required this.controller,
    this.firstTime = false,
  });

  @override
  State<CharacterCreatorScreen> createState() =>
      _CharacterCreatorScreenState();
}

class _CharacterCreatorScreenState extends State<CharacterCreatorScreen> {
  late Appearance _look;
  late final TextEditingController _nameCtrl;

  @override
  void initState() {
    super.initState();
    _look = widget.controller.player.appearance.copy();
    _nameCtrl =
        TextEditingController(text: widget.controller.player.name);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  bool get _canSave => _nameCtrl.text.trim().isNotEmpty;

  void _save() {
    final player = widget.controller.player;
    player.name = _nameCtrl.text.trim();
    player.appearance = _look;
    widget.controller.saveProfile();
    if (!widget.firstTime && mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final equipped = {
      for (final slot in GearSlot.values)
        slot: widget.controller.equippedIn(slot),
    };

    return Scaffold(
      backgroundColor: RN.night,
      appBar: AppBar(
        automaticallyImplyLeading: !widget.firstTime,
        title: Text('🪞 El Espejo Mágico', style: fantasyTitle(20)),
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (widget.firstTime)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  'El espejo del gremio refleja al explorador que llevas dentro. '
                  'Dale forma… y un nombre digno de las crónicas.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: RN.parchmentDim, fontSize: 12.5),
                ),
              ),
            SizedBox(
              height: 190,
              child: AvatarView(equipped: equipped, appearance: _look),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                children: [
                  // ---- Nombre ----
                  TextField(
                    controller: _nameCtrl,
                    maxLength: 14,
                    textCapitalization: TextCapitalization.words,
                    onChanged: (_) => setState(() {}),
                    style: fantasyTitle(18),
                    decoration: InputDecoration(
                      labelText: 'Nombre de tu explorador',
                      labelStyle:
                          const TextStyle(color: RN.parchmentDim),
                      counterStyle:
                          const TextStyle(color: RN.parchmentDim),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                            color: RN.gold.withValues(alpha: 0.4)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: RN.gold),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),

                  // ---- Cuerpo ----
                  _sectionTitle('Cuerpo'),
                  Row(
                    children: [
                      _chip('Hombre', !_look.female,
                          () => setState(() => _look.female = false)),
                      const SizedBox(width: 8),
                      _chip('Mujer', _look.female,
                          () => setState(() => _look.female = true)),
                    ],
                  ),

                  // ---- Piel ----
                  _sectionTitle('Tono de piel'),
                  _colorRow(
                    skinPalette,
                    _look.skinTone,
                    (i) => setState(() => _look.skinTone = i),
                  ),

                  // ---- Peinado ----
                  _sectionTitle('Peinado'),
                  _arrowSelector(
                    hairStyleNames[_look.hairStyle],
                    () => setState(() => _look.hairStyle =
                        (_look.hairStyle - 1 + hairStyleNames.length) %
                            hairStyleNames.length),
                    () => setState(() => _look.hairStyle =
                        (_look.hairStyle + 1) % hairStyleNames.length),
                  ),

                  // ---- Color de pelo ----
                  _sectionTitle('Color de pelo'),
                  _colorRow(
                    hairPalette,
                    _look.hairColor,
                    (i) => setState(() => _look.hairColor = i),
                  ),

                  // ---- Vello facial (solo cuerpo masculino) ----
                  if (!_look.female) ...[
                    _sectionTitle('Vello facial'),
                    _arrowSelector(
                      facialHairNames[_look.facialHair],
                      () => setState(() => _look.facialHair =
                          (_look.facialHair - 1 + facialHairNames.length) %
                              facialHairNames.length),
                      () => setState(() => _look.facialHair =
                          (_look.facialHair + 1) %
                              facialHairNames.length),
                    ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _canSave ? _save : null,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      widget.firstTime
                          ? '⚔️ Comenzar la aventura'
                          : 'Guardar cambios',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 6),
        child: Text(
          text,
          style: const TextStyle(
            color: RN.goldSoft,
            fontWeight: FontWeight.bold,
            fontSize: 13,
            letterSpacing: 0.5,
          ),
        ),
      );

  Widget _chip(String label, bool selected, VoidCallback onTap) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      selectedColor: RN.gold.withValues(alpha: 0.3),
      onSelected: (_) => onTap(),
    );
  }

  Widget _colorRow(
      List<Color> palette, int selected, void Function(int) onPick) {
    return Wrap(
      spacing: 10,
      runSpacing: 8,
      children: [
        for (var i = 0; i < palette.length; i++)
          GestureDetector(
            onTap: () => onPick(i),
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: palette[i],
                border: Border.all(
                  color: i == selected ? RN.gold : Colors.white24,
                  width: i == selected ? 3 : 1,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _arrowSelector(
      String label, VoidCallback onPrev, VoidCallback onNext) {
    return Container(
      decoration: BoxDecoration(
        color: RN.panel,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left, color: RN.gold),
            onPressed: onPrev,
          ),
          Expanded(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, color: RN.parchment),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right, color: RN.gold),
            onPressed: onNext,
          ),
        ],
      ),
    );
  }
}
