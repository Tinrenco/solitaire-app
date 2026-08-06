import 'package:flutter/material.dart';

import '../models/card_model.dart';
import '../models/game_state.dart';

/// Replaces the old Klondike per-suit foundation piles. There is no
/// foundation-by-suit concept in this variant: instead this shows a simple
/// counter/badge for how many of the 8 possible King-to-Ace same-suit
/// sequences (2 decks x 4 suits) have been completed and removed from the
/// tableau, plus a small glyph per suit completed so far.
class CompletedSequencesView extends StatelessWidget {
  final GameState gameState;

  const CompletedSequencesView({super.key, required this.gameState});

  @override
  Widget build(BuildContext context) {
    final completed = gameState.completedSequences;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.style, color: Colors.white70, size: 18),
          const SizedBox(width: 6),
          Text(
            '${completed.length} / ${GameState.totalSequencesToWin}',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          if (completed.isNotEmpty) ...[
            const SizedBox(width: 8),
            Flexible(
              child: Wrap(
                spacing: 2,
                runSpacing: 2,
                children: [
                  for (final suit in completed)
                    Text(
                      suit.symbol,
                      style: TextStyle(
                        color: suit.isRed ? Colors.red.shade200 : Colors.white,
                        fontSize: 14,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
