import 'package:flutter/material.dart';

/// Emoji reaksi memakai gambar di assets/emoji/ (dipotong dari gambar yang
/// diberikan user). Kode emoji tetap karakter biasa, supaya data proyek
/// mudah dibaca. Kode yang tidak dikenal (mis. reaksi dari proyek lama)
/// ditampilkan sebagai teks emoji bawaan HP.
const reactionAssets = <String, String>{
  '😍': 'assets/emoji/love.png',
  '😂': 'assets/emoji/laugh.png',
  '😮': 'assets/emoji/wow.png',
  '😢': 'assets/emoji/sad.png',
  '🥺': 'assets/emoji/plead.png',
  '😡': 'assets/emoji/angry.png',
};

/// Urutan emoji di menu tahan pesan dan pilihan reaksi.
final reactionEmojis = reactionAssets.keys.toList(growable: false);

class FakeEmoji extends StatelessWidget {
  const FakeEmoji(this.code, {super.key, this.size = 28});

  final String code;
  final double size;

  @override
  Widget build(BuildContext context) {
    final asset = reactionAssets[code];
    if (asset == null) {
      return Text(code, style: TextStyle(fontSize: size * 0.85));
    }
    return Image.asset(
      asset,
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
    );
  }
}
