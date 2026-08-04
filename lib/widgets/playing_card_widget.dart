import 'package:flutter/material.dart';

import '../models/card_model.dart';

/// Renders a single playing card.
///
/// * Face-down cards show a plain patterned back (no image asset needed).
/// * Ace..10 are drawn procedurally: rank text + suit glyph on a white card.
/// * Jack/Queen/King use the custom AI-generated portrait JPGs bundled
///   under `assets/cards/`, with a small rank/suit badge overlaid in the
///   corner so the card is still readable during play.
class PlayingCardWidget extends StatelessWidget {
  final PlayingCard card;
  final double width;
  final double height;

  const PlayingCardWidget({
    super.key,
    required this.card,
    required this.width,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(width * 0.12);

    if (!card.faceUp) {
      return _CardBack(width: width, height: height, radius: radius);
    }

    if (card.rank.hasPortrait) {
      return _PortraitFace(card: card, width: width, height: height, radius: radius);
    }

    return _PipFace(card: card, width: width, height: height, radius: radius);
  }
}

/// Empty pile outline, used for empty foundation/tableau/stock/waste slots
/// so the board always shows 13 stable "slots".
class EmptyPileSlot extends StatelessWidget {
  final double width;
  final double height;
  final Widget? child;

  const EmptyPileSlot({super.key, required this.width, required this.height, this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(width * 0.12),
        border: Border.all(color: Colors.white38, width: 1.5),
      ),
      child: child,
    );
  }
}

class _CardBack extends StatelessWidget {
  final double width;
  final double height;
  final BorderRadius radius;

  const _CardBack({required this.width, required this.height, required this.radius});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(color: Colors.white, width: 1.5),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1B3A6B), Color(0xFF0D1B33)],
        ),
      ),
      child: Center(
        child: Container(
          width: width * 0.55,
          height: height * 0.55,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(width * 0.08),
            border: Border.all(color: Colors.white54, width: 1),
          ),
        ),
      ),
    );
  }
}

class _PipFace extends StatelessWidget {
  final PlayingCard card;
  final double width;
  final double height;
  final BorderRadius radius;

  const _PipFace({
    required this.card,
    required this.width,
    required this.height,
    required this.radius,
  });

  @override
  Widget build(BuildContext context) {
    final color = card.isRed ? const Color(0xFFC62828) : const Color(0xFF212121);
    final fontSize = width * 0.28;

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: radius,
        border: Border.all(color: Colors.black26, width: 1),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 1.5, offset: Offset(0, 1))],
      ),
      child: Stack(
        children: [
          Positioned(
            left: 3,
            top: 2,
            child: _CornerLabel(card: card, color: color, fontSize: fontSize * 0.55),
          ),
          Center(
            child: Text(
              card.suit.symbol,
              style: TextStyle(color: color, fontSize: fontSize, fontWeight: FontWeight.bold),
            ),
          ),
          Positioned(
            right: 3,
            bottom: 2,
            child: Transform.rotate(
              angle: 3.14159,
              child: _CornerLabel(card: card, color: color, fontSize: fontSize * 0.55),
            ),
          ),
        ],
      ),
    );
  }
}

class _CornerLabel extends StatelessWidget {
  final PlayingCard card;
  final Color color;
  final double fontSize;

  const _CornerLabel({required this.card, required this.color, required this.fontSize});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          card.rank.shortLabel,
          style: TextStyle(color: color, fontSize: fontSize, fontWeight: FontWeight.bold, height: 1),
        ),
        Text(
          card.suit.symbol,
          style: TextStyle(color: color, fontSize: fontSize * 0.85, height: 1),
        ),
      ],
    );
  }
}

class _PortraitFace extends StatelessWidget {
  final PlayingCard card;
  final double width;
  final double height;
  final BorderRadius radius;

  const _PortraitFace({
    required this.card,
    required this.width,
    required this.height,
    required this.radius,
  });

  @override
  Widget build(BuildContext context) {
    final color = card.isRed ? const Color(0xFFC62828) : const Color(0xFF212121);
    final fontSize = width * 0.28 * 0.55;

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(color: Colors.black26, width: 1),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 1.5, offset: Offset(0, 1))],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              card.portraitAssetPath,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                color: Colors.white,
                alignment: Alignment.center,
                child: Text(
                  '${card.rank.shortLabel}${card.suit.symbol}',
                  style: TextStyle(color: color, fontSize: width * 0.28, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            Positioned(
              left: 2,
              top: 2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: const Color(0xD9FFFFFF),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: _CornerLabel(card: card, color: color, fontSize: fontSize),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
