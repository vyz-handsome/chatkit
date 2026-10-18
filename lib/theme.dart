import 'package:flutter/material.dart';

/// Warna ChatKit. Bubble hijau, lawan abu terang, tampilan sendiri
/// (bukan salinan app chat mana pun).
class Palette {
  final bool dark;
  const Palette(this.dark);

  Color get otherBubble =>
      dark ? const Color(0xFF2C2C2E) : const Color(0xFFE9E9EB);
  List<Color> get meBubble => dark
      ? const [Color(0xFF2FA24F), Color(0xFF1F7A39)]
      : const [Color(0xFF5CD66C), Color(0xFF2FB44A)];
  Color get textOther => dark ? Colors.white : const Color(0xFF111111);
  Color get textMe => Colors.white;
  Color get metaOther =>
      dark ? const Color(0xFF9A9AA0) : const Color(0xFF7C7C82);
  Color get metaMe => const Color(0xFFE6FBE9);
  Color get tickRead => const Color(0xFF8FE8FF);
  Color get ink => dark ? Colors.white : const Color(0xFF111111);
  Color get accent => const Color(0xFF30B84A);
}

class WallPreset {
  final String name;
  final List<Color> light;
  final List<Color> dark;
  const WallPreset(this.name, this.light, this.dark);
}

const wallPresets = <WallPreset>[
  WallPreset('Mint', [Color(0xFFE8F7EE), Color(0xFFD2F0E0)],
      [Color(0xFF0E1A14), Color(0xFF12261C)]),
  WallPreset('Langit', [Color(0xFFE6F1FF), Color(0xFFD6E4FA)],
      [Color(0xFF0D1626), Color(0xFF11213A)]),
  WallPreset('Senja', [Color(0xFFFFEFE0), Color(0xFFFBD9E4)],
      [Color(0xFF231418), Color(0xFF2B1A2E)]),
  WallPreset('Putih', [Color(0xFFF6F6F8), Color(0xFFF6F6F8)],
      [Color(0xFF101012), Color(0xFF101012)]),
  WallPreset('Lavender', [Color(0xFFEEE9FF), Color(0xFFE1E6FF)],
      [Color(0xFF16122A), Color(0xFF1B1B3A)]),
  WallPreset('Pasir', [Color(0xFFF7F0E3), Color(0xFFEFE3CC)],
      [Color(0xFF1E1A12), Color(0xFF262014)]),
];

const reactionEmojis = ['👍', '❤️', '😂', '😮', '😢', '🙏'];

const memberColors = <int>[
  0xFF2F9BFF,
  0xFFFF9F0A,
  0xFFBF5AF2,
  0xFFFF375F,
  0xFF30B84A,
  0xFF64D2FF,
  0xFFFFD60A,
  0xFFAC8E68,
];
