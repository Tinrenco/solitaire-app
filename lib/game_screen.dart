import 'package:flutter/material.dart';

import 'models/game_state.dart';
import 'widgets/completed_view.dart';
import 'widgets/stock_view.dart';
import 'widgets/tableau_view.dart';

/// Top level screen: builds the 10-column board layout and reacts to game
/// state changes (including showing a "you win" dialog).
class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late final GameState _gameState;
  bool _winDialogShown = false;

  @override
  void initState() {
    super.initState();
    _gameState = GameState();
    _gameState.addListener(_onGameStateChanged);
  }

  @override
  void dispose() {
    _gameState.removeListener(_onGameStateChanged);
    super.dispose();
  }

  void _onGameStateChanged() {
    if (!mounted) return;
    setState(() {});
    if (_gameState.won && !_winDialogShown) {
      _winDialogShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _showWinDialog());
    }
  }

  void _newGame() {
    setState(() {
      _winDialogShown = false;
      _gameState.startNewGame();
    });
  }

  void _showWinDialog() {
    if (!mounted) return;
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('You win!'),
        content: const Text(
          'All 8 King-to-Ace sequences are complete. Well played.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _newGame();
            },
            child: const Text('New game'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B6623),
      appBar: AppBar(
        title: const Text('Spider Solitaire'),
        backgroundColor: const Color(0xFF07401A),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'New game',
            onPressed: _newGame,
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            const columns = GameState.columnCount;
            const horizontalPadding = 8.0;
            const spacing = 6.0;

            // Card width is derived from the available screen width so it
            // scales up meaningfully on tablets rather than being capped
            // to a small phone-sized max: on a phone (~360-420dp wide) 10
            // columns clamp to the minimum and the board scrolls
            // horizontally; on a tablet (~700-1400dp wide) columns/width
            // grows well past phone size, giving visibly larger, more
            // legible cards instead of just more empty space around
            // small ones. The upper clamp only guards against absurdly
            // huge cards on ultra-wide displays.
            final availableWidth =
                constraints.maxWidth - horizontalPadding * 2 - spacing * (columns - 1);
            var cardWidth = availableWidth / columns;
            // `num.clamp` returns `num`, not `double` (a well-known Dart
            // gotcha) — `.toDouble()` keeps `cardWidth` a `double` so it
            // type-checks against the rest of this method.
            cardWidth = cardWidth.clamp(60.0, 190.0).toDouble();
            final cardHeight = cardWidth * 1.45;
            final faceUpStep = cardHeight * 0.30;

            var maxColumnLength = 1;
            for (final column in _gameState.tableau) {
              if (column.length > maxColumnLength) maxColumnLength = column.length;
            }
            final tableauContentHeight =
                cardHeight + faceUpStep * (maxColumnLength - 1);

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 12),
              child: Column(
                // `stretch` (rather than `start`) is deliberate: it gives
                // the Expanded scroll area below a definite, full-width
                // constraint to hand down to its nested vertical/horizontal
                // SingleChildScrollViews. Without it, a scrollable nested
                // inside a Column's loose cross-axis constraint has an
                // ambiguous width, which risks collapsing the whole
                // tableau to zero width instead of the intended
                // screen-filling, horizontally-scrollable board.
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Stock pile on the left, completed-sequences counter on
                  // the right.
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      StockPileWidget(
                        gameState: _gameState,
                        width: cardWidth * 0.75,
                        height: cardHeight * 0.75,
                      ),
                      CompletedSequencesView(gameState: _gameState),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Ten tableau columns. Wrapped in an inner vertical
                  // scroll (safety net for short screens / deep columns
                  // after several stock deals) around an inner horizontal
                  // scroll (10 columns rarely fit a single phone width).
                  // Keeping these scrolls scoped to just the tableau -
                  // rather than wrapping the whole page - keeps the top
                  // bar always visible and limits how much the tableau's
                  // own scroll gestures can compete with dragging a card
                  // (see tableau_view.dart for why cards use
                  // LongPressDraggable for the same reason).
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: SizedBox(
                        height: tableauContentHeight,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (var i = 0; i < columns; i++) ...[
                                if (i > 0) SizedBox(width: spacing),
                                TableauColumnWidget(
                                  gameState: _gameState,
                                  columnIndex: i,
                                  cardWidth: cardWidth,
                                  cardHeight: cardHeight,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
