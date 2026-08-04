import 'package:flutter/material.dart';

import '../models/card_model.dart';
import '../models/game_state.dart';
import 'playing_card_widget.dart';

/// One of the seven tableau columns. Any face-up card, together with every
/// card on top of it, can be dragged as a unit onto another column (or, if
/// it is a single card, onto a foundation).
class TableauColumnWidget extends StatefulWidget {
  final GameState gameState;
  final int columnIndex;
  final double cardWidth;
  final double cardHeight;

  const TableauColumnWidget({
    super.key,
    required this.gameState,
    required this.columnIndex,
    required this.cardWidth,
    required this.cardHeight,
  });

  @override
  State<TableauColumnWidget> createState() => _TableauColumnWidgetState();
}

class _TableauColumnWidgetState extends State<TableauColumnWidget> {
  int? _draggingFrom;

  double get _faceDownStep => widget.cardHeight * 0.20;
  double get _faceUpStep => widget.cardHeight * 0.32;

  @override
  Widget build(BuildContext context) {
    final column = widget.gameState.tableau[widget.columnIndex];

    final positions = <double>[];
    var y = 0.0;
    for (var i = 0; i < column.length; i++) {
      positions.add(y);
      y += column[i].faceUp ? _faceUpStep : _faceDownStep;
    }
    final totalHeight = column.isEmpty ? widget.cardHeight : y - _faceUpStep + widget.cardHeight;

    final children = <Widget>[];
    for (var i = 0; i < column.length; i++) {
      final card = column[i];
      final hiddenByDrag = _draggingFrom != null && i > _draggingFrom!;

      Widget cardWidget;
      if (hiddenByDrag) {
        cardWidget = SizedBox(width: widget.cardWidth, height: widget.cardHeight);
      } else if (!card.faceUp) {
        cardWidget = PlayingCardWidget(card: card, width: widget.cardWidth, height: widget.cardHeight);
      } else {
        final payload = DragPayload(
          origin: MoveOrigin(type: PileType.tableau, index: widget.columnIndex),
          cards: column.sublist(i),
        );
        cardWidget = GestureDetector(
          onDoubleTap: () => widget.gameState.tryAutoMoveToFoundation(
            MoveOrigin(type: PileType.tableau, index: widget.columnIndex),
            card,
          ),
          child: Draggable<DragPayload>(
            data: payload,
            onDragStarted: () => setState(() => _draggingFrom = i),
            onDragEnd: (_) => setState(() => _draggingFrom = null),
            feedback: Opacity(
              opacity: 0.85,
              child: _StackFeedback(
                cards: payload.cards,
                width: widget.cardWidth,
                height: widget.cardHeight,
                step: _faceUpStep,
              ),
            ),
            childWhenDragging: SizedBox(width: widget.cardWidth, height: widget.cardHeight),
            child: PlayingCardWidget(card: card, width: widget.cardWidth, height: widget.cardHeight),
          ),
        );
      }

      children.add(Positioned(top: positions[i], left: 0, child: cardWidget));
    }

    return DragTarget<DragPayload>(
      onWillAcceptWithDetails: (details) =>
          widget.gameState.canDropOnTableau(details.data, widget.columnIndex),
      onAcceptWithDetails: (details) =>
          widget.gameState.dropOnTableau(details.data, widget.columnIndex),
      builder: (context, candidateData, rejectedData) {
        final highlight = candidateData.isNotEmpty;
        return SizedBox(
          width: widget.cardWidth,
          height: totalHeight,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              EmptyPileSlot(width: widget.cardWidth, height: widget.cardHeight),
              ...children,
              if (highlight)
                Positioned(
                  top: 0,
                  left: 0,
                  child: Container(
                    width: widget.cardWidth,
                    height: totalHeight,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(widget.cardWidth * 0.12),
                      border: Border.all(color: Colors.yellowAccent, width: 2.5),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Small offset stack used as the drag feedback when moving several cards
/// at once from a tableau column.
class _StackFeedback extends StatelessWidget {
  final List<PlayingCard> cards;
  final double width;
  final double height;
  final double step;

  const _StackFeedback({
    required this.cards,
    required this.width,
    required this.height,
    required this.step,
  });

  @override
  Widget build(BuildContext context) {
    final totalHeight = height + step * (cards.length - 1);
    return SizedBox(
      width: width,
      height: totalHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (var i = 0; i < cards.length; i++)
            Positioned(
              top: step * i,
              left: 0,
              child: PlayingCardWidget(card: cards[i], width: width, height: height),
            ),
        ],
      ),
    );
  }
}
