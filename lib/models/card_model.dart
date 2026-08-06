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

/// A single playing card.
///
/// This variant plays with two combined standard decks (104 cards), so the
/// same (suit, rank) pair exists twice at once. [copyIndex] (0 or 1) makes
/// each physical card instance distinguishable/unique (used for stable
/// widget [Key]s) even though both copies of e.g. King of Hearts render the
/// exact same portrait asset — there is only one photo per role+suit, not
/// per role+suit+deck-copy.
///
/// [faceUp] is kept (rather than removed) because [PlayingCardWidget]
/// already renders it generically; this variant simply always deals cards
/// with faceUp == true and never flips one down.
class PlayingCard {
  final Suit suit;
  final Rank rank;
  final int copyIndex;
  bool faceUp;

  PlayingCard({
    required this.suit,
    required this.rank,
    this.copyIndex = 0,
    this.faceUp = true,
  });

  bool get isRed => suit.isRed;

  /// Stable identity string, unique per physical card instance (including
  /// across the two decks). Handy for Flutter `Key`s.
  String get id => '${rank.name}_${suit.name}_$copyIndex';

  /// Path to the custom portrait asset for King/Queen/Jack cards.
  /// Only valid when [Rank.hasPortrait] is true. Both deck-copies of a
  /// given rank+suit intentionally point at the same image file.
  String get portraitAssetPath =>
      'assets/cards/${rank.frenchAssetName}_${suit.frenchAssetName}.jpg';

  @override
  String toString() => id;
}

/// Builds two combined, shuffled standard 52-card decks (104 cards total,
/// all face-up) as used by this Spider-style variant.
List<PlayingCard> buildDoubleDeckShuffled({Random? random}) {
  final deck = <PlayingCard>[
    for (var copy = 0; copy < 2; copy++)
      for (final suit in Suit.values)
        for (final rank in Rank.values)
          PlayingCard(suit: suit, rank: rank, copyIndex: copy, faceUp: true),
  ];
  deck.shuffle(random ?? Random());
  return deck;
}
