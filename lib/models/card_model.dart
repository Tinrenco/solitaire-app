import 'dart:math';

/// The four suits of a standard 52 card deck.
enum Suit { hearts, diamonds, clubs, spades }

extension SuitProperties on Suit {
  bool get isRed => this == Suit.hearts || this == Suit.diamonds;

  /// Unicode glyph used when rendering procedurally-drawn cards
  /// (everything except Jack/Queen/King, which use portrait images).
  String get symbol {
    switch (this) {
      case Suit.hearts:
        return '♥';
      case Suit.diamonds:
        return '♦';
      case Suit.clubs:
        return '♣';
      case Suit.spades:
        return '♠';
    }
  }

  /// French filename fragment used for the custom portrait assets,
  /// e.g. "coeur", "carreau", "trefle", "pique".
  String get frenchAssetName {
    switch (this) {
      case Suit.hearts:
        return 'coeur';
      case Suit.diamonds:
        return 'carreau';
      case Suit.clubs:
        return 'trefle';
      case Suit.spades:
        return 'pique';
    }
  }
}

/// The thirteen ranks of a suit, in ascending order (Ace low).
enum Rank {
  ace,
  two,
  three,
  four,
  five,
  six,
  seven,
  eight,
  nine,
  ten,
  jack,
  queen,
  king,
}

extension RankProperties on Rank {
  /// Numeric value, Ace = 1 ... King = 13.
  int get value => index + 1;

  /// Short label used on procedurally drawn cards ("A", "2".."10", "J", "Q", "K").
  String get shortLabel {
    switch (this) {
      case Rank.ace:
        return 'A';
      case Rank.jack:
        return 'J';
      case Rank.queen:
        return 'Q';
      case Rank.king:
        return 'K';
      default:
        return value.toString();
    }
  }

  bool get hasPortrait =>
      this == Rank.jack || this == Rank.queen || this == Rank.king;

  /// French filename fragment used for the custom portrait assets,
  /// e.g. "roi", "reine", "valet". Only meaningful when [hasPortrait] is true.
  String get frenchAssetName {
    switch (this) {
      case Rank.king:
        return 'roi';
      case Rank.queen:
        return 'reine';
      case Rank.jack:
        return 'valet';
      default:
        return '';
    }
  }
}

/// A single playing card. Mutable [faceUp] flag so the same card object
/// can be flipped in place as it moves between piles.
class PlayingCard {
  final Suit suit;
  final Rank rank;
  bool faceUp;

  PlayingCard({
    required this.suit,
    required this.rank,
    this.faceUp = false,
  });

  bool get isRed => suit.isRed;

  /// Stable identity string, handy for Flutter `Key`s.
  String get id => '${rank.name}_${suit.name}';

  /// Path to the custom portrait asset for King/Queen/Jack cards.
  /// Only valid when [Rank.hasPortrait] is true.
  String get portraitAssetPath =>
      'assets/cards/${rank.frenchAssetName}_${suit.frenchAssetName}.jpg';

  @override
  String toString() => id;
}

/// Builds a standard 52 card deck (all face-down) and shuffles it.
List<PlayingCard> buildShuffledDeck({Random? random}) {
  final deck = <PlayingCard>[
    for (final suit in Suit.values)
      for (final rank in Rank.values) PlayingCard(suit: suit, rank: rank),
  ];
  deck.shuffle(random ?? Random());
  return deck;
}
