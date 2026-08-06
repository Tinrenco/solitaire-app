import 'package:flutter/material.dart';

import 'models/game_history_entry.dart';
import 'models/game_state.dart';

/// Simple history screen: the most recent finished games (newest first),
/// one row each with date/time, duration, move count, and won/finished
/// status. Pushed via `Navigator.push` from the game screen's app bar.
class StatsScreen extends StatelessWidget {
  final GameState gameState;

  const StatsScreen({super.key, required this.gameState});

  @override
  Widget build(BuildContext context) {
    // AnimatedBuilder so the list stays live if a persisted history load
    // finishes while this screen happens to already be open.
    return AnimatedBuilder(
      animation: gameState,
      builder: (context, _) {
        final history = gameState.history;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Game history'),
          ),
          body: history.isEmpty
              ? const Center(
                  child: Text(
                    'No finished games yet.',
                    style: TextStyle(color: Colors.black54),
                  ),
                )
              : ListView.separated(
                  itemCount: history.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) => _HistoryRow(entry: history[index]),
                ),
        );
      },
    );
  }
}

class _HistoryRow extends StatelessWidget {
  final GameHistoryEntry entry;

  const _HistoryRow({required this.entry});

  static String _formatDate(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${dt.year}-${two(dt.month)}-${two(dt.day)} ${two(dt.hour)}:${two(dt.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        entry.won ? Icons.emoji_events : Icons.flag_outlined,
        color: entry.won ? Colors.amber.shade700 : Colors.grey,
      ),
      title: Text(_formatDate(entry.endedAt)),
      subtitle: Text(
        'Duration: ${formatDuration(entry.duration)}   Moves: ${entry.moveCount}',
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                entry.won ? Icons.check_circle : Icons.cancel,
                color: entry.won ? Colors.green : Colors.redAccent,
                size: 16,
              ),
              const SizedBox(width: 4),
              Text(
                entry.won ? 'Won' : 'Ended',
                style: TextStyle(
                  fontSize: 12,
                  color: entry.won ? Colors.green : Colors.redAccent,
                ),
              ),
            ],
          ),
          Text(
            entry.finished ? 'Finished' : 'Unfinished',
            style: const TextStyle(fontSize: 11, color: Colors.black45),
          ),
        ],
      ),
    );
  }
}
