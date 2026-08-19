import 'package:flutter/material.dart';

import '../models/bestiary.dart';

/// Sprite de una criatura, con respaldo de emoji si el asset faltara.
class EnemySprite extends StatelessWidget {
  final Enemy enemy;
  final double size;

  const EnemySprite({super.key, required this.enemy, required this.size});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      enemy.spritePath,
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      errorBuilder: (context, error, stack) => SizedBox(
        width: size,
        height: size,
        child: Center(
          child: Text(enemy.spec.emoji,
              style: TextStyle(fontSize: size * 0.7)),
        ),
      ),
    );
  }
}
