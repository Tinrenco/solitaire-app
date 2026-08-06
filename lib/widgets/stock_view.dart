import 'package:flutter/material.dart';

import '../models/card_model.dart';
import '../models/game_state.dart';
import 'playing_card_widget.dart';

/// The single stock pile for this Spider-style variant (no waste pile: a
/// tap deals one card face up onto the top of every tableau column at
/// once). Shown as a small offset stack of card-backs, one per remaining
/// 10-card batch (up to 5), plus a count of cards left.
///
/// Per the standard Spider rule, dealing is disabled (and visually dimmed)
/// whenever any tableau column is currently empty, and once the stock is
/// fully dealt it shows as empty and no longer responds to taps.
class StockPileWidget extends StatelessWidget {
  final GameState gameState;
  final double width;
  final double height;

  const StockPileWidget({
    super.key,
    required this.gameState,
    required this.width,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    final batches = gameState.stockBatchesRemaining;
    final canDeal = gameState.canDealFromStock;
    const offset = 4.0;

    Widget pile;
    if (batches == 0) {
      pile = EmptyPileSlot(
        width: width,
        height: height,
        child: const Center(
          child: Icon(Icons.block, color: Colors.white38),
        ),
      );
    } else {
      pile = SizedBox(
        width: width + offset * (batches - 1),
        height: height + offset * (batches - 1),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            for (var i = 0; i < batches; i++)
              Positioned(
                left: i * offset,
                top: i * offset,
                child: PlayingCardWidget(
                  card: PlayingCard(
                    suit: Suit.spades,
                    rank: Rank.ace,
                    faceUp: false,
                  ),
                  width: width,
                  height: height,
                ),
              ),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: canDeal ? gameState.dealFromStock : null,
      child: Opacity(
        opacity: canDeal ? 1.0 : 0.55,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            pile,
            const SizedBox(height: 4),
            Text(
              '${gameState.stock.length} left',
              style: const TextStyle(color: Colors.white70, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}
