import 'package:flutter/foundation.dart';

import 'card_model.dart';

/// Identifies the kind of pile a card (or stack of cards) is coming from.
enum PileType { tableau, foundation, waste, stock }

/// Where a drag gesture started. [index] is the tableau/foundation index
/// (unused, -1, for waste/stock).
@immutable
class MoveOrigin {
  final PileType type;
  final int index;

  const MoveOrigin({required this.type, this.index = -1});

  static const waste = MoveOrigin(type: PileType.waste);
}

/// Payload carried by a Flutter `Draggable` while the user drags one or
/// more cards across the board.
@immutable
class DragPayload {
  final MoveOrigin origin;
  final List<PlayingCard> cards;

  const DragPayload({required this.origin, required this.cards});
}

/// Holds the full state of a Klondike game and all the rules for moving
/// cards between piles. Pure Dart aside from [ChangeNotifier], so it is
/// easy to reason about and does not depend on any extra package.
class GameState extends ChangeNotifier {
  late List<List<PlayingCard>> tableau; // 7 columns
  late List<List<PlayingCard>> foundations; // index == Suit.index
  late List<PlayingCard> stock;
  late List<PlayingCard> waste;
  bool won = false;

  GameState() {
    startNewGame();
  }

  void startNewGame() {
    won = false;
    final deck = buildShuffledDeck();

    tableau = List.generate(7, (_) => <PlayingCard>[]);
    foundations = List.generate(4, (_) => <PlayingCard>[]);
    waste = <PlayingCard>[];

    var cursor = 0;
    for (var col = 0; col < 7; col++) {
      for (var row = 0; row <= col; row++) {
        final card = deck[cursor++];
        card.faceUp = row == col;
        tableau[col].add(card);
      }
    }

    stock = deck.sublist(cursor);
    for (final card in stock) {
      card.faceUp = false;
    }

    notifyListeners();
  }

  /// Draws one card from stock to waste, or recycles waste back into
  /// stock when stock is empty.
  void drawFromStock() {
    if (stock.isEmpty) {
      if (waste.isEmpty) return;
      stock = waste.reversed.toList();
      for (final card in stock) {
        card.faceUp = false;
      }
      waste = <PlayingCard>[];
    } else {
      final card = stock.removeLast();
      card.faceUp = true;
      waste.add(card);
    }
    notifyListeners();
  }

  bool _canStackOnTableau(PlayingCard moving, List<PlayingCard> dest) {
    if (dest.isEmpty) return moving.rank == Rank.king;
    final top = dest.last;
    if (!top.faceUp) return false;
    return top.rank.value == moving.rank.value + 1 && top.isRed != moving.isRed;
  }

  bool _canStackOnFoundation(PlayingCard moving, int foundationIndex) {
    if (moving.suit.index != foundationIndex) return false;
    final pile = foundations[foundationIndex];
    if (pile.isEmpty) return moving.rank == Rank.ace;
    return pile.last.rank.value + 1 == moving.rank.value;
  }

  bool canDropOnTableau(DragPayload payload, int columnIndex) {
    if (payload.cards.isEmpty) return false;
    if (payload.origin.type == PileType.tableau &&
        payload.origin.index == columnIndex) {
      return false;
    }
    return _canStackOnTableau(payload.cards.first, tableau[columnIndex]);
  }

  bool canDropOnFoundation(DragPayload payload, int foundationIndex) {
    if (payload.cards.length != 1) return false;
    if (payload.origin.type == PileType.foundation &&
        payload.origin.index == foundationIndex) {
      return false;
    }
    return _canStackOnFoundation(payload.cards.first, foundationIndex);
  }

  void _removeFromOrigin(MoveOrigin origin, int count) {
    switch (origin.type) {
      case PileType.tableau:
        final col = tableau[origin.index];
        col.removeRange(col.length - count, col.length);
        if (col.isNotEmpty) col.last.faceUp = true;
        break;
      case PileType.waste:
        waste.removeLast();
        break;
      case PileType.foundation:
        foundations[origin.index].removeLast();
        break;
      case PileType.stock:
        // Stock cards are never dragged directly.
        break;
    }
  }

  void dropOnTableau(DragPayload payload, int columnIndex) {
    if (!canDropOnTableau(payload, columnIndex)) return;
    tableau[columnIndex].addAll(payload.cards);
    _removeFromOrigin(payload.origin, payload.cards.length);
    _checkWin();
    notifyListeners();
  }

  void dropOnFoundation(DragPayload payload, int foundationIndex) {
    if (!canDropOnFoundation(payload, foundationIndex)) return;
    foundations[foundationIndex].add(payload.cards.first);
    _removeFromOrigin(payload.origin, 1);
    _checkWin();
    notifyListeners();
  }

  /// Convenience used for double-tap: send [card] to the first valid
  /// foundation pile, if any. Returns true if a move happened.
  bool tryAutoMoveToFoundation(MoveOrigin origin, PlayingCard card) {
    for (var i = 0; i < 4; i++) {
      if (_canStackOnFoundation(card, i)) {
        foundations[i].add(card);
        _removeFromOrigin(origin, 1);
        _checkWin();
        notifyListeners();
        return true;
      }
    }
    return false;
  }

  void _checkWin() {
    won = foundations.every((pile) => pile.length == 13);
  }
}
