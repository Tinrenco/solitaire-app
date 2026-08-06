import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'card_model.dart';
import 'game_history_entry.dart';

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
///  * A card or contiguous descending run can be dragged from the end of a
///    column onto another column whose bottom-most card is exactly one rank
///    higher than the moved group's top card. Whether the run must also be
///    same-suit to be picked up as a group together is a user-configurable
///    setting (classic Spider rule vs. a relaxed rule matching most popular
///    digital implementations, e.g. Microsoft Solitaire Collection) — see
///    the settings toggle. Suit always matters for the completed-sequence
///    check below, regardless of this setting.
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

  /// Most recent games kept in [history]; the 21st-oldest entry is dropped
  /// whenever a new one would exceed this cap.
  static const int maxHistoryEntries = 20;

  static const String _relaxedMoveRuleKey = 'relaxedMoveRule';
  static const String _historyKey = 'gameHistory';

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

  /// Whether a dragged run only needs to be strictly descending by rank
  /// (suit irrelevant, `true`, the default/"relaxed" behaviour matching
  /// most popular digital Spider implementations) or must also be same-suit
  /// throughout (`false`, classic Spider). Only affects what can be picked
  /// up as a group with [runStartIndex]/[canDragFrom] — the completed
  /// King-to-Ace sequence check is always same-suit regardless of this
  /// setting. Persisted across app restarts via [SharedPreferences].
  bool relaxedMoveRule = true;

  /// Number of moves made in the current game: incremented once per
  /// successful [moveCards] call and once per [dealFromStock] call.
  int moveCount = 0;

  /// Whether the current game is paused. While paused, [elapsed] stops
  /// advancing (the active-time "stopwatch" is frozen). Interaction is
  /// disabled at the UI layer (a full-screen overlay captures all touches);
  /// this flag is what drives that overlay.
  bool isPaused = false;

  /// The most recently finished games, newest first, capped at
  /// [maxHistoryEntries]. Populated synchronously as games finish and
  /// asynchronously from disk on startup (see [_loadPersisted]).
  List<GameHistoryEntry> history = <GameHistoryEntry>[];

  /// Total active (non-paused) duration accumulated before the current
  /// running segment (i.e. before the most recent resume/game-start).
  Duration _accumulatedDuration = Duration.zero;

  /// Wall-clock time the current active segment started, or `null` while
  /// paused. Combined with [_accumulatedDuration] to compute [elapsed].
  DateTime? _segmentStart;

  /// Whether a history entry has already been logged for the game
  /// currently in progress (set once it's won, so starting a new game
  /// afterwards doesn't log a second, duplicate entry).
  bool _historyRecordedForCurrentGame = false;

  GameState() {
    startNewGame();
    // Fire-and-forget: GameState's constructor can't be async, and the UI
    // needs a fully-dealt default game to show on the very first frame
    // regardless of how long loading prefs takes. Once this resolves it
    // applies the persisted rule/history and calls notifyListeners(), so
    // the UI picks up the change a moment later rather than blocking on it.
    _loadPersisted();
  }

  /// Elapsed *active* time for the current game — wall-clock time since the
  /// game started or was last resumed, plus whatever had already
  /// accumulated across prior pause/resume cycles. Frozen while [isPaused].
  Duration get elapsed {
    if (isPaused || _segmentStart == null) return _accumulatedDuration;
    return _accumulatedDuration + DateTime.now().difference(_segmentStart!);
  }

  void startNewGame() {
    // A completely fresh, untouched game (0 moves) being replaced by
    // another new game isn't a "played session" — only log if the player
    // actually made progress and it wasn't already logged (e.g. via a win).
    if (!_historyRecordedForCurrentGame && moveCount > 0) {
      _recordHistoryEntry(won: false);
    }

    won = false;
    completedSequences = <Suit>[];
    moveCount = 0;
    isPaused = false;
    _accumulatedDuration = Duration.zero;
    _segmentStart = DateTime.now();
    _historyRecordedForCurrentGame = false;

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
    moveCount++;
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
  /// contiguous, strictly-descending run all the way to the end of the
  /// column — same-suit throughout as well when [relaxedMoveRule] is
  /// `false` (classic Spider), suit-irrelevant when it's `true` (the
  /// default). Always well defined (at worst it's `column.length - 1`,
  /// i.e. just the last card, which is trivially a "run" of one).
  int runStartIndex(int col) {
    final column = tableau[col];
    if (column.isEmpty) return 0;
    var start = column.length - 1;
    while (start > 0) {
      final upper = column[start - 1];
      final lower = column[start];
      final suitOk = relaxedMoveRule || upper.suit == lower.suit;
      if (suitOk && upper.rank.value == lower.rank.value + 1) {
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

    moveCount++;
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

  /// Pauses the current game: freezes [elapsed] and (via the UI's overlay)
  /// disables tableau/stock interaction. No-op if already paused.
  void pause() {
    if (isPaused) return;
    _accumulatedDuration = elapsed;
    isPaused = true;
    _segmentStart = null;
    notifyListeners();
  }

  /// Resumes a paused game: [elapsed] starts advancing again from where it
  /// left off. No-op if not currently paused.
  void resume() {
    if (!isPaused) return;
    isPaused = false;
    _segmentStart = DateTime.now();
    notifyListeners();
  }

  /// Sets the classic-vs-relaxed grouping rule (see [relaxedMoveRule]) and
  /// persists the new value.
  void setRelaxedMoveRule(bool value) {
    if (relaxedMoveRule == value) return;
    relaxedMoveRule = value;
    notifyListeners();
    _fireAndForget(_persistRelaxedMoveRule());
  }

  /// Scans every column and removes any complete King-to-Ace same-suit run
  /// sitting at the end of it, adding one entry to [completedSequences] per
  /// run removed. Called after every move and every stock deal. Always
  /// requires same-suit regardless of [relaxedMoveRule] — see class doc.
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
    final wasWon = won;
    won = completedSequences.length >= totalSequencesToWin;
    if (won && !wasWon) {
      _recordHistoryEntry(won: true);
    }
  }

  /// Appends one entry to [history] for the game that just finished
  /// (either won, or abandoned via "New game" after at least one move),
  /// capping the list at [maxHistoryEntries] and persisting it.
  void _recordHistoryEntry({required bool won}) {
    final entry = GameHistoryEntry(
      endedAt: DateTime.now(),
      duration: elapsed,
      moveCount: moveCount,
      won: won,
      finished: true,
    );
    history.insert(0, entry);
    if (history.length > maxHistoryEntries) {
      history.removeRange(maxHistoryEntries, history.length);
    }
    _historyRecordedForCurrentGame = true;
    notifyListeners();
    _fireAndForget(_persistHistory());
  }

  /// Loads the persisted [relaxedMoveRule] setting and [history] list from
  /// [SharedPreferences], if present, applying whichever of them were
  /// actually saved on a previous run. Safe to call even if nothing has
  /// ever been persisted yet (keeps the constructor's defaults).
  Future<void> _loadPersisted() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final storedRelaxed = prefs.getBool(_relaxedMoveRuleKey);
      if (storedRelaxed != null) {
        relaxedMoveRule = storedRelaxed;
      }

      final historyJson = prefs.getString(_historyKey);
      if (historyJson != null) {
        final decoded = jsonDecode(historyJson);
        if (decoded is List) {
          history = decoded
              .whereType<Map<String, dynamic>>()
              .map(GameHistoryEntry.fromJson)
              .toList();
        }
      }

      notifyListeners();
    } catch (_) {
      // Missing/corrupt prefs shouldn't crash the app — just keep whatever
      // defaults startNewGame() already set up.
    }
  }

  Future<void> _persistRelaxedMoveRule() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_relaxedMoveRuleKey, relaxedMoveRule);
  }

  Future<void> _persistHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(history.map((e) => e.toJson()).toList());
    await prefs.setString(_historyKey, encoded);
  }
}

/// Explicitly discards a `Future` we intentionally don't await (fire and
/// forget persistence writes) without upsetting analyzers that flag
/// unawaited futures. Kept as a small private local helper (rather than
/// importing `dart:async`'s `unawaited`) to sidestep any doubt about
/// exactly what `package:flutter/foundation.dart` re-exports.
void _fireAndForget(Future<void> future) {}
