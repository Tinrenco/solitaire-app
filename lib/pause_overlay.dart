import 'package:flutter/material.dart';

/// Full-screen overlay shown while the game is paused. Meant to be placed
/// as a `Positioned.fill` (or otherwise sized to cover the whole board) on
/// top of the game screen's body: being opaque and above everything else in
/// the stack is what actually disables tableau/stock interaction — there's
/// no need to separately disable every widget underneath.
class PauseOverlay extends StatelessWidget {
  final VoidCallback onResume;

  const PauseOverlay({super.key, required this.onResume});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black87,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.pause_circle_filled, color: Colors.white, size: 64),
            const SizedBox(height: 16),
            const Text(
              'Paused',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onResume,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Resume'),
            ),
          ],
        ),
      ),
    );
  }
}
