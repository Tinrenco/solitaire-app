import 'package:flutter/material.dart';

import 'models/game_state.dart';

/// Simple settings screen reachable from the game screen's app bar.
/// Currently holds a single toggle for the classic-vs-relaxed card
/// grouping rule (see `GameState.relaxedMoveRule`).
class SettingsScreen extends StatelessWidget {
  final GameState gameState;

  const SettingsScreen({super.key, required this.gameState});

  @override
  Widget build(BuildContext context) {
    // AnimatedBuilder keeps the switch in sync if relaxedMoveRule changes
    // from elsewhere (e.g. a persisted value finishing its async load)
    // while this screen is open.
    return AnimatedBuilder(
      animation: gameState,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Settings'),
          ),
          body: ListView(
            children: [
              SwitchListTile(
                title: const Text('Strict Spider rules (same suit only)'),
                subtitle: const Text(
                  'On: only same-suit descending runs can be dragged '
                  'together as a group (classic Spider). Off: any strictly '
                  'descending run can be dragged as a group regardless of '
                  'suit (relaxed rule used by most popular digital Spider '
                  'implementations).',
                ),
                value: !gameState.relaxedMoveRule,
                onChanged: (value) => gameState.setRelaxedMoveRule(!value),
              ),
            ],
          ),
        );
      },
    );
  }
}
