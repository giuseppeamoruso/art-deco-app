import 'package:flutter/material.dart';
import '../theme_manager.dart';

class SeasonalDecoration extends StatelessWidget {
  const SeasonalDecoration({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = ThemeManager.getCurrentTheme();

    switch (theme) {
      case AppTheme.christmas:
        return const _ChristmasDecoration();
      case AppTheme.halloween:
        return const _HalloweenDecoration();
      case AppTheme.summer:
        return const _SummerDecoration();
      default:
        return const SizedBox.shrink();
    }
  }
}

// 🎄 DECORAZIONE NATALE - SOLO EMOJI
class _ChristmasDecoration extends StatelessWidget {
  const _ChristmasDecoration();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Emoji negli angoli
        Positioned(
          top: 60,
          right: 16,
          child: Text(
            '❄️',
            style: TextStyle(
              fontSize: 28,
              shadows: [
                Shadow(
                  color: Colors.white.withOpacity(0.5),
                  blurRadius: 10,
                )
              ],
            ),
          ),
        ),
        Positioned(
          top: 60,
          left: 16,
          child: Text(
            '🎄',
            style: TextStyle(
              fontSize: 28,
              shadows: [
                Shadow(
                  color: Colors.green.withOpacity(0.5),
                  blurRadius: 10,
                )
              ],
            ),
          ),
        ),
        // Emoji aggiuntive
        Positioned(
          bottom: 120,
          right: 40,
          child: Text(
            '🎁',
            style: TextStyle(fontSize: 24),
          ),
        ),
        Positioned(
          bottom: 150,
          left: 50,
          child: Text(
            '⭐',
            style: TextStyle(fontSize: 20),
          ),
        ),
      ],
    );
  }
}

// 🎃 DECORAZIONE HALLOWEEN - SOLO EMOJI
class _HalloweenDecoration extends StatelessWidget {
  const _HalloweenDecoration();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          top: 60,
          right: 16,
          child: Text(
            '🎃',
            style: TextStyle(
              fontSize: 28,
              shadows: [
                Shadow(
                  color: Colors.orange.withOpacity(0.7),
                  blurRadius: 10,
                )
              ],
            ),
          ),
        ),
        Positioned(
          top: 60,
          left: 16,
          child: Text(
            '👻',
            style: TextStyle(
              fontSize: 28,
              shadows: [
                Shadow(
                  color: Colors.purple.withOpacity(0.7),
                  blurRadius: 10,
                )
              ],
            ),
          ),
        ),
        Positioned(
          bottom: 100,
          right: 30,
          child: Text(
            '🕷️',
            style: TextStyle(fontSize: 20),
          ),
        ),
        Positioned(
          bottom: 130,
          left: 40,
          child: Text(
            '🦇',
            style: TextStyle(fontSize: 22),
          ),
        ),
      ],
    );
  }
}

// ☀️ DECORAZIONE ESTATE - SOLO EMOJI
class _SummerDecoration extends StatelessWidget {
  const _SummerDecoration();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          top: 60,
          right: 16,
          child: Text(
            '☀️',
            style: TextStyle(
              fontSize: 28,
              shadows: [
                Shadow(
                  color: Colors.yellow.withOpacity(0.7),
                  blurRadius: 15,
                )
              ],
            ),
          ),
        ),
        Positioned(
          top: 60,
          left: 16,
          child: Text(
            '🏖️',
            style: TextStyle(fontSize: 24),
          ),
        ),
        Positioned(
          bottom: 100,
          left: 30,
          child: Text(
            '🌊',
            style: TextStyle(fontSize: 24),
          ),
        ),
        Positioned(
          bottom: 130,
          right: 40,
          child: Text(
            '🍹',
            style: TextStyle(fontSize: 20),
          ),
        ),
      ],
    );
  }
}