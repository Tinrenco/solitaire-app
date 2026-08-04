import 'package:flutter/material.dart';

import '../models/card_model.dart';
import '../models/game_state.dart';
import 'playing_card_widget.dart';

/// The stock pile (tap to deal to waste, tap again when empty to recycle).
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
    final hasStock = gameState.stock.isNotEmpty;
    return GestureDetector(
      onTap: gameState.drawFromStock,
      child: hasStock
          ? PlayingCardWidget(
              card: PlayingCard(suit: Suit.spades, rank: Rank.ace, faceUp: false),
              width: width,
              height: height,
            )
          : EmptyPileSlot(
              width: width,
              height: height,
              child: gameState.waste.isNotEmpty
                  ? const Center(
                      child: Icon(Icons.replay, color: Colors.white54),
                    )
                  : null,
            ),
    );
  }
}

/// The waste pile: shows the top (most recently drawn) card, which can be
/// dragged out to a tableau column or a foundation.
class WastePileWidget extends StatelessWidget {
  final GameState gameState;
  final double width;
  final double height;

  const WastePileWidget({
    super.key,
    required this.gameState,
    required this.width,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    if (gameState.waste.isEmpty) {
      return EmptyPileSlot(width: width, height: height);
    }

    final card = gameState.waste.last;
    final payload = DragPayload(origin: MoveOrigin.waste, cards: [card]);

    return GestureDetector(
      onDoubleTap: () => gameState.tryAutoMoveToFoundation(MoveOrigin.waste, card),
      child: Draggable<DragPayload>(
        data: payload,
        feedback: Opacity(
          opacity: 0.85,
          child: PlayingCardWidget(card: card, width: width, height: height),
        ),
        childWhenDragging: EmptyPileSlot(width: width, height: height),
        child: PlayingCardWidget(card: card, width: width, height: height),
      ),
    );
  }
}
