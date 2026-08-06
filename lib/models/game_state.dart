import 'package:flutter/foundation.dart';

import 'card_model.dart';

/// Holds the full state of this Spider-style solitaire variant and all the
/// rules for dealing and moving cards. Pure Dart aside from [ChangeNotifier],
/// so it is easy to reason about and does not depend on any extra package.
///
/// Rules summary (see project brief for full detail):
///  * 10 tableau columns, 2 combined standard decks (104 cards).
///  * ALL tableau cards are dealt face up from the start (no hidden cards).
///  * Initial deal: columns 0-3 get 6 cards, columns 4-9 get 5 cards (54
///    cards), the remaining 50 cards sit in the stock as 5 batches of 10.
///  * Tapping the stock deals one card face up onto the top of every
///    tableau column at once, but only if no column is currently empty.
///  * A card or contiguous same-suit descending run can be dragged from the
///    end of a column onto another column whose bottom-most card is exactly
///    one rank higher than the moved group's top card (suit irrelevant for
///    placement). Any card/run may be placed on an empty column.
///  * Whenever the last 13 cards of a column form a complete King-to-Ace
///    same-suit run, they are removed as a "completed sequence".
///  * The game is won once all 8 possible sequences (2 decks x 4 suits)
///    have been completed.
class GameState extends ChangeNotifier {
  static const int columnCount = 10;
  static const int initialLongColumns = 4; // columns 0..3 get 6 cards
  static const int cardsInLongColumn = 6;
  static const int cardsInShortColumn = 5;
  static const int batchSize = 10;
  static const int totalSequencesToWin = 8;
  static const int sequenceLength = 13;

  /// The 10 tableau columns, each ordered from the bottom of the pile
  /// (dealt first, index 0) to the front/most-recently-placed card (last
  /// index) — the last index is the card closest to the player and the one
  /// any drag/placement logic treats as "the end of the column".
  late List<List<PlayingCard>> tableau;

  /// Cards not yet dealt to the tableau. Always a multiple of [batchSize]
  /// (or empty) since batches are dealt as a whole.
  late List<PlayingCard> stock;

  /// One entry per completed (removed) King-to-Ace same-suit run, recording
  /// which suit it was — purely for the completed-sequences display.
  late List<Suit> completedSequences;

  bool won = false;

  GameState() {
    startNewGame();
  }

  void startNewGame() {
    won = false;
    completedSequences = <Suit>[];
    final deck = buildDoubleDeckShuffled();

    tableau = List.generate(columnCount, (_) => <PlayingCard>[]);

    var cursor = 0;
    for (var col = 0; col < columnCount; col++) {
      final count = col < initialLongColumns ? cardsInLongColumn : cardsInShortColumn;
      for (var i = 0; i < count; i++) {
        final card = deck[cursor++];
        card.faceUp = true;
        tableau[col].add(card);
      }
    }

    stock = deck.sublist(cursor);
    for (final card in stock) {
      card.faceUp = false; // only relevant if ever rendered directly
    }

    notifyListeners();
  }

  /// How many 10-card batches are still waiting in the stock (0-5).
  int get stockBatchesRemaining => stock.length ~/ batchSize;

  /// Standard Spider rule: a stock deal is only allowed when no tableau
  /// column is currently empty, and only while cards remain in the stock.
  bool get canDealFromStock =>
      stock.isNotEmpty && tableau.every((column) => column.isNotEmpty);

  /// Deals one card face up onto the top of every tableau column at once
  /// (i.e. one 10-card batch). No-op (does not crash / does not deal a
  /// partial round) if [canDealFromStock] is false.
  void dealFromStock() {
    if (!canDealFromStock) return;
    for (var col = 0; col < columnCount; col++) {
      final card = stock.removeLast();
      card.faceUp = true;
      tableau[col].add(card);
    }
    _removeCompletedSequences();
    _checkWin();
    notifyListeners();
  }

  bool _isDescendingSameSuitRun(List<PlayingCard> cards) {
    for (var i = 0; i < cards.length - 1; i++) {
      final upper = cards[i];
      final lower = cards[i + 1];
      if (upper.suit != lower.suit) return false;
      if (upper.rank.value != lower.rank.value + 1) return false;
    }
    return true;
  }

  /// The smallest index such that `tableau[col].sublist(index)` is a valid
  /// contiguous, strictly-descending, same-suit run all the way to the end
  /// of the column. Always well defined (at worst it's `column.length - 1`,
  /// i.e. just the last card, which is trivially a "run" of one).
  int runStartIndex(int col) {
    final column = tableau[col];
    if (column.isEmpty) return 0;
    var start = column.length - 1;
    while (start > 0) {
      final upper = column[start - 1];
      final lower = column[start];
      if (upper.suit == lower.suit && upper.rank.value == lower.rank.value + 1) {
        start--;
      } else {
        break;
      }
    }
    return start;
  }

  /// Whether the run starting at [startIndex] in column [col] (extending to
  /// the end of the column) is legal to pick up as a group.
  bool canDragFrom(int col, int startIndex) {
    final column = tableau[col];
    if (startIndex < 0 || startIndex >= column.length) return false;
    return startIndex >= runStartIndex(col);
  }

  /// Whether the run `tableau[fromCol].sublist(startIndex)` may legally be
  /// dropped onto [toCol].
  bool canDropOnTableau(int fromCol, int startIndex, int toCol) {
    if (fromCol == toCol) return false;
    if (fromCol < 0 || fromCol >= columnCount) return false;
    if (toCol < 0 || toCol >= columnCount) return false;
    if (!canDragFrom(fromCol, startIndex)) return false;

    final group = tableau[fromCol].sublist(startIndex);
    final dest = tableau[toCol];
    if (dest.isEmpty) return true;
    return dest.last.rank.value == group.first.rank.value + 1;
  }

  /// Attempts to move `tableau[fromCol].sublist(startIndex)` onto [toCol].
  /// Returns true if the move happened. Validates the move itself (so it is
  /// safe to call directly from a `DragTarget.onAcceptWithDetails`).
  bool moveCards(int fromCol, int startIndex, int toCol) {
    if (!canDropOnTableau(fromCol, startIndex, toCol)) return false;

    final column = tableau[fromCol];
    final group = column.sublist(startIndex);
    column.removeRange(startIndex, column.length);
    tableau[toCol].addAll(group);

    _removeCompletedSequences();
    _checkWin();
    notifyListeners();
    return true;
  }

  /// Convenience for double-tap: move the run starting at [startIndex] in
  /// [fromCol] onto the first tableau column that will legally accept it.
  /// Returns true if a move happened.
  bool tryAutoMove(int fromCol, int startIndex) {
    if (!canDragFrom(fromCol, startIndex)) return false;
    for (var col = 0; col < columnCount; col++) {
      if (col == fromCol) continue;
      if (canDropOnTableau(fromCol, startIndex, col)) {
        return moveCards(fromCol, startIndex, col);
      }
    }
    return false;
  }

  /// Scans every column and removes any complete King-to-Ace same-suit run
  /// sitting at the end of it, adding one entry to [completedSequences] per
  /// run removed. Called after every move and every stock deal.
  void _removeCompletedSequences() {
    for (var col = 0; col < columnCount; col++) {
      final column = tableau[col];
      while (column.length >= sequenceLength) {
        final start = column.length - sequenceLength;
        final slice = column.sublist(start);
        final isComplete = slice.first.rank == Rank.king &&
            slice.last.rank == Rank.ace &&
            _isDescendingSameSuitRun(slice);
        if (!isComplete) break;
        column.removeRange(start, column.length);
        completedSequences.add(slice.first.suit);
      }
    }
  }

  void _checkWin() {
    won = completedSequences.length >= totalSequencesToWin;
  }
}
