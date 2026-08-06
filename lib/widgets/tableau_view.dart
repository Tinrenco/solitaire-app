import 'package:flutter/material.dart';

import '../models/card_model.dart';
import '../models/game_state.dart';
import 'playing_card_widget.dart';

/// Data carried by a Flutter `Draggable` while the user drags a card (or a
/// contiguous run of cards) off the end of a tableau column. This is enough
/// for the drop target to know the exact sub-sequence being moved:
/// `tableau[fromColumn].sublist(startIndex)`.
@immutable
class TableauDragData {
  final int fromColumn;
  final int startIndex;

  const TableauDragData({required this.fromColumn, required this.startIndex});
}

/// One of the ten tableau columns. All cards are always face up in this
/// variant. A contiguous same-suit descending run at the end of the column
/// can be dragged as a unit; any card not part of such a run (or covered by
/// one) can still be dragged alone if it is itself the last card, but
/// otherwise offers no drag handle of its own — see
/// [GameState.runStartIndex] / [GameState.canDragFrom].
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
  // Index (within this column) that the user is currently dragging from,
  // if any. Everything from this index onward is part of the drag and is
  // replaced with an invisible placeholder while the drag is in flight.
  int? _draggingFromIndex;

  double get _faceUpStep => widget.cardHeight * 0.30;

  @override
  Widget build(BuildContext context) {
    final column = widget.gameState.tableau[widget.columnIndex];
    final runStart = widget.gameState.runStartIndex(widget.columnIndex);

    final positions = <double>[];
    var y = 0.0;
    for (var i = 0; i < column.length; i++) {
      positions.add(y);
      y += _faceUpStep;
    }
    final totalHeight =
        column.isEmpty ? widget.cardHeight : y - _faceUpStep + widget.cardHeight;

    final children = <Widget>[];
    for (var i = 0; i < column.length; i++) {
      final card = column[i];
      // IMPORTANT: strictly-greater, not >=. The card at _draggingFromIndex
      // itself must stay mounted as the *same* Draggable widget (so Flutter
      // keeps its element/state alive across the setState-triggered
      // rebuild below and the in-flight drag isn't torn down); only the
      // cards *after* it in the run are swapped for an invisible
      // placeholder, since they're visually carried along in the feedback.
      final hiddenByDrag = _draggingFromIndex != null && i > _draggingFromIndex!;
      final isDraggable = i >= runStart;

      Widget cardWidget;
      if (hiddenByDrag) {
        cardWidget = SizedBox(width: widget.cardWidth, height: widget.cardHeight);
      } else if (!isDraggable) {
        cardWidget = PlayingCardWidget(card: card, width: widget.cardWidth, height: widget.cardHeight);
      } else {
        final dragCards = column.sublist(i);
        final data = TableauDragData(fromColumn: widget.columnIndex, startIndex: i);

        cardWidget = GestureDetector(
          onDoubleTap: () => widget.gameState.tryAutoMove(widget.columnIndex, i),
          // LongPressDraggable (rather than plain Draggable) is deliberate:
          // the board is wrapped in nested horizontal/vertical scroll views
          // (10 columns rarely fit one phone screen), and a plain Draggable
          // competes with those scroll gestures for a quick horizontal/
          // vertical swipe. Requiring a brief press-and-hold before the
          // drag engages cleanly disambiguates "scroll the board" from
          // "pick up this card", while a deliberate press-then-drag still
          // feels natural for moving cards.
          child: LongPressDraggable<TableauDragData>(
            data: data,
            delay: const Duration(milliseconds: 200),
            onDragStarted: () => setState(() => _draggingFromIndex = i),
            onDragEnd: (_) => setState(() => _draggingFromIndex = null),
            feedback: Material(
              color: Colors.transparent,
              child: Opacity(
                opacity: 0.9,
                child: _StackFeedback(
                  cards: dragCards,
                  width: widget.cardWidth,
                  height: widget.cardHeight,
                  step: _faceUpStep,
                ),
              ),
            ),
            childWhenDragging: SizedBox(width: widget.cardWidth, height: widget.cardHeight),
            child: PlayingCardWidget(card: card, width: widget.cardWidth, height: widget.cardHeight),
          ),
        );
      }

      children.add(Positioned(
        key: ValueKey(card.id),
        top: positions[i],
        left: 0,
        child: cardWidget,
      ));
    }

    return DragTarget<TableauDragData>(
      onWillAcceptWithDetails: (details) => widget.gameState.canDropOnTableau(
        details.data.fromColumn,
        details.data.startIndex,
        widget.columnIndex,
      ),
      onAcceptWithDetails: (details) => widget.gameState.moveCards(
        details.data.fromColumn,
        details.data.startIndex,
        widget.columnIndex,
      ),
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
                  child: IgnorePointer(
                    child: Container(
                      width: widget.cardWidth,
                      height: totalHeight,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(widget.cardWidth * 0.12),
                        border: Border.all(color: Colors.yellowAccent, width: 3),
                      ),
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
