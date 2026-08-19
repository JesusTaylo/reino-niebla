import 'package:flutter/material.dart';

import '../game_controller.dart';
import '../models/items.dart';
import '../theme.dart';
import '../widgets/avatar_view.dart';
import 'character_creator_screen.dart';

class AvatarScreen extends StatefulWidget {
  final GameController controller;

  const AvatarScreen({super.key, required this.controller});

  @override
  State<AvatarScreen> createState() => _AvatarScreenState();
}

class _AvatarScreenState extends State<AvatarScreen> {
  GearSlot _selectedSlot = GearSlot.yelmo;

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    return Scaffold(
      appBar: AppBar(
        title: Text('Tu Explorador', style: fantasyTitle(22)),
        actions: [
          IconButton(
            tooltip: 'Espejo Mágico (editar apariencia)',
            icon: const Text('🪞', style: TextStyle(fontSize: 20)),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) =>
                  CharacterCreatorScreen(controller: controller),
            )),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          final player = controller.player;
          final equipped = {
            for (final slot in GearSlot.values) slot: controller.equippedIn(slot),
          };
          final itemsForSlot = gearCatalog
              .where((g) => g.slot == _selectedSlot)
              .toList();

          return Column(
            children: [
              const SizedBox(height: 8),
              Text(player.name.isEmpty ? 'Explorador' : player.name,
                  style: fantasyTitle(20, color: RN.goldSoft)),
              Text('Nivel ${player.level} · ${player.title}',
                  style: const TextStyle(color: RN.parchmentDim)),
              SizedBox(
                height: 210,
                child: AvatarView(
                    equipped: equipped, appearance: player.appearance),
              ),
              const SizedBox(height: 8),
              // Selector de slot.
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    for (final slot in GearSlot.values)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text('${slot.emoji} ${slot.label}'),
                          selected: _selectedSlot == slot,
                          selectedColor: RN.gold.withValues(alpha: 0.3),
                          onSelected: (_) =>
                              setState(() => _selectedSlot = slot),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: itemsForSlot.length,
                  itemBuilder: (context, i) {
                    final item = itemsForSlot[i];
                    final owned = player.inventory.contains(item.id);
                    final isEquipped =
                        player.equipped[item.slot.name] == item.id;
                    return Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: isEquipped
                              ? RN.gold
                              : item.rarity.color
                                  .withValues(alpha: owned ? 0.7 : 0.25),
                          width: isEquipped ? 2 : 1,
                        ),
                      ),
                      child: ListTile(
                        leading: Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: item.rarity.color
                                .withValues(alpha: owned ? 0.25 : 0.08),
                          ),
                          alignment: Alignment.center,
                          child: Opacity(
                            opacity: owned ? 1 : 0.35,
                            child: Text(item.slot.emoji,
                                style: const TextStyle(fontSize: 20)),
                          ),
                        ),
                        title: Text(
                          owned ? item.name : '??? ',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: owned ? RN.parchment : RN.parchmentDim,
                          ),
                        ),
                        subtitle: Text(
                          owned
                              ? item.desc
                              : 'Objeto ${item.rarity.label.toLowerCase()} por descubrir…',
                          style: const TextStyle(
                              fontSize: 11.5, color: RN.parchmentDim),
                        ),
                        trailing: owned
                            ? (isEquipped
                                ? const Icon(Icons.check_circle,
                                    color: RN.gold)
                                : TextButton(
                                    onPressed: () => controller.equip(item),
                                    child: const Text('Equipar'),
                                  ))
                            : const Icon(Icons.lock_outline,
                                color: Colors.white24),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
