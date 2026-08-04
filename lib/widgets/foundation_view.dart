import 'package:flutter/material.dart';

import '../models/card_model.dart';
import '../models/game_state.dart';
import 'playing_card_widget.dart';

/// One foundation pile (Ace up to King) for a single suit.
class FoundationPileWidget extends StatelessWidget {
  final GameState gameState;
  final int foundationIndex; // matches Suit.index
  final double width;
  final double height;

  const FoundationPileWidget({
    super.key,
    required this.gameState,
    required this.foundationIndex,
    required this.width,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    final pile = gameState.foundations[foundationIndex];
    final suit = Suit.values[foundationIndex];

    return DragTarget<DragPayload>(
      onWillAcceptWithDetails: (details) =>
          gameState.canDropOnFoundation(details.data, foundationIndex),
      onAcceptWithDetails: (details) =>
          gameState.dropOnFoundation(details.data, foundationIndex),
      builder: (context, candidateData, rejectedData) {
        final highlight = candidateData.isNotEmpty;
        if (pile.isEmpty) {
          return EmptyPileSlot(
            width: width,
            height: height,
            child: Center(
              child: Text(
                suit.symbol,
                style: TextStyle(
                  color: highlight
                      ? Colors.white
                      : (suit.isRed ? Colors.red.shade200 : Colors.white38),
                  fontSize: width * 0.4,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          );
        }
        return Stack(
          children: [
            PlayingCardWidget(card: pile.last, width: width, height: height),
            if (highlight)
              Container(
                width: width,
                height: height,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(width * 0.12),
                  border: Border.all(color: Colors.yellowAccent, width: 2.5),
                ),
              ),
          ],
        );
      },
    );
  }
}
