import 'package:flutter/material.dart';

import 'models/game_state.dart';
import 'widgets/foundation_view.dart';
import 'widgets/stock_waste_view.dart';
import 'widgets/tableau_view.dart';

/// Top level screen: builds the board layout and reacts to game state
/// changes (including showing a "you win" dialog).
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
    setState(() {});
    if (_gameState.won && !_winDialogShown) {
      _winDialogShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _showWinDialog());
    }
  }

  void _newGame() {
    _winDialogShown = false;
    _gameState.startNewGame();
  }

  void _showWinDialog() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('You win!'),
        content: const Text('All four foundations are complete. Well played.'),
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
        title: const Text('Solitaire'),
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
            const columns = 7;
            const horizontalPadding = 8.0;
            const spacing = 4.0;
            final availableWidth = constraints.maxWidth - horizontalPadding * 2 - spacing * (columns - 1);
            var cardWidth = availableWidth / columns;
            cardWidth = cardWidth.clamp(36.0, 90.0);
            final cardHeight = cardWidth * 1.45;

            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Stock / waste on the left, four foundations on the right.
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          StockPileWidget(gameState: _gameState, width: cardWidth, height: cardHeight),
                          SizedBox(width: spacing),
                          WastePileWidget(gameState: _gameState, width: cardWidth, height: cardHeight),
                        ],
                      ),
                      Row(
                        children: [
                          for (var i = 0; i < 4; i++) ...[
                            if (i > 0) SizedBox(width: spacing),
                            FoundationPileWidget(
                              gameState: _gameState,
                              foundationIndex: i,
                              width: cardWidth,
                              height: cardHeight,
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Seven tableau columns.
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var i = 0; i < 7; i++) ...[
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
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
