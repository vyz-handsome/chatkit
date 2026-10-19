import 'package:flutter/material.dart';

import '../theme.dart';

/// Emoji reaksi gambar sendiri (vector, 6 buah). Kodenya tetap karakter emoji
/// biasa (lihat [reactionEmojis]) supaya data proyek lama tetap terbaca.
class FakeEmoji extends StatelessWidget {
  const FakeEmoji(this.code, {super.key, this.size = 28});

  final String code;
  final double size;

  static const _kinds = ['like', 'heart', 'laugh', 'wow', 'sad', 'pray'];

  @override
  Widget build(BuildContext context) {
    final i = reactionEmojis.indexOf(code);
    if (i < 0) return Text(code, style: TextStyle(fontSize: size * 0.85));
    return CustomPaint(
      size: Size.square(size),
      painter: _EmojiPainter(_kinds[i]),
    );
  }
}

class _EmojiPainter extends CustomPainter {
  _EmojiPainter(this.kind);
  final String kind;

  static const _ink = Color(0xFF4A2C12);
  static const _mouth = Color(0xFF6B1F14);
  static const _tongue = Color(0xFFFF7A8A);

  Paint _fill(Color col) => Paint()
    ..color = col
    ..isAntiAlias = true;

  Paint _stroke(Color col, double w) => Paint()
    ..color = col
    ..style = PaintingStyle.stroke
    ..strokeWidth = w
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..isAntiAlias = true;

  Paint _grad(Rect r, List<Color> colors,
      {Alignment begin = Alignment.topLeft,
      Alignment end = Alignment.bottomRight}) {
    return Paint()
      ..isAntiAlias = true
      ..shader = LinearGradient(begin: begin, end: end, colors: colors)
          .createShader(r);
  }

  @override
  void paint(Canvas c, Size size) {
    c.save();
    c.scale(size.width / 100, size.height / 100);
    switch (kind) {
      case 'like':
        _like(c);
        break;
      case 'heart':
        _heart(c);
        break;
      case 'laugh':
        _laugh(c);
        break;
      case 'wow':
        _wow(c);
        break;
      case 'sad':
        _sad(c);
        break;
      case 'pray':
        _pray(c);
        break;
    }
    c.restore();
  }

  // ----------------------------------------------------------------- bagian

  void _face(Canvas c) {
    final r = Rect.fromCircle(center: const Offset(50, 50), radius: 46);
    c.drawCircle(
      const Offset(50, 50),
      46,
      Paint()
        ..isAntiAlias = true
        ..shader = const RadialGradient(
          center: Alignment(-0.35, -0.45),
          radius: 1.05,
          colors: [Color(0xFFFFE98A), Color(0xFFFFC83D), Color(0xFFF0A000)],
          stops: [0.0, 0.62, 1.0],
        ).createShader(r),
    );
    c.drawCircle(const Offset(50, 50), 45.3, _stroke(const Color(0x40B36A00), 1.6));
    final g = Rect.fromLTWH(24, 8, 52, 26);
    c.drawOval(
      g,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x66FFFFFF), Color(0x00FFFFFF)],
        ).createShader(g),
    );
  }

  void _eye(Canvas c, Offset o, double rx, double ry) {
    c.drawOval(
      Rect.fromCenter(center: o, width: rx * 2, height: ry * 2),
      _fill(_ink),
    );
    c.drawCircle(
      o.translate(-rx * 0.3, -ry * 0.35),
      rx * 0.32,
      _fill(Colors.white.withAlpha(230)),
    );
  }

  void _drop(Canvas c, Offset o, double s) {
    final p = Path()
      ..moveTo(o.dx, o.dy - 9 * s)
      ..quadraticBezierTo(o.dx + 8 * s, o.dy + 3 * s, o.dx, o.dy + 8 * s)
      ..quadraticBezierTo(o.dx - 8 * s, o.dy + 3 * s, o.dx, o.dy - 9 * s)
      ..close();
    c.drawPath(
      p,
      _grad(
        p.getBounds(),
        const [Color(0xFF8FE0FF), Color(0xFF2A9BEA)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ),
    );
    c.drawCircle(
      Offset(o.dx - 2 * s, o.dy + 1 * s),
      1.6 * s,
      _fill(Colors.white.withAlpha(200)),
    );
  }

  // ------------------------------------------------------------------ emoji

  void _laugh(Canvas c) {
    _face(c);
    final eye = _stroke(_ink, 5);
    c.drawPath(
      Path()
        ..moveTo(21, 42)
        ..quadraticBezierTo(31, 29, 41, 42),
      eye,
    );
    c.drawPath(
      Path()
        ..moveTo(59, 42)
        ..quadraticBezierTo(69, 29, 79, 42),
      eye,
    );
    final mouth = Path()
      ..moveTo(23, 55)
      ..quadraticBezierTo(50, 62, 77, 55)
      ..quadraticBezierTo(72, 86, 50, 86)
      ..quadraticBezierTo(28, 86, 23, 55)
      ..close();
    c.drawPath(mouth, _fill(_mouth));
    c.save();
    c.clipPath(mouth);
    c.drawRect(Rect.fromLTRB(20, 54, 80, 65), _fill(Colors.white));
    c.drawOval(
      Rect.fromCenter(center: const Offset(50, 86), width: 34, height: 22),
      _fill(_tongue),
    );
    c.restore();
    _drop(c, const Offset(11, 50), 1.0);
    _drop(c, const Offset(89, 50), 1.0);
  }

  void _wow(Canvas c) {
    _face(c);
    final brow = _stroke(_ink, 3.6);
    c.drawPath(
      Path()
        ..moveTo(23, 27)
        ..quadraticBezierTo(33, 18, 43, 25),
      brow,
    );
    c.drawPath(
      Path()
        ..moveTo(57, 25)
        ..quadraticBezierTo(67, 18, 77, 27),
      brow,
    );
    _eye(c, const Offset(34, 44), 5.5, 8);
    _eye(c, const Offset(66, 44), 5.5, 8);
    final mouth =
        Rect.fromCenter(center: const Offset(50, 70), width: 17, height: 24);
    c.drawOval(mouth, _fill(_mouth));
    c.save();
    c.clipPath(Path()..addOval(mouth));
    c.drawOval(
      Rect.fromCenter(center: const Offset(50, 80), width: 14, height: 10),
      _fill(_tongue),
    );
    c.restore();
  }

  void _sad(Canvas c) {
    _face(c);
    final brow = _stroke(_ink, 3.6);
    c.drawLine(const Offset(23, 37), const Offset(42, 29), brow);
    c.drawLine(const Offset(58, 29), const Offset(77, 37), brow);
    _eye(c, const Offset(33, 47), 5.2, 6.5);
    _eye(c, const Offset(67, 47), 5.2, 6.5);
    c.drawPath(
      Path()
        ..moveTo(35, 76)
        ..quadraticBezierTo(50, 64, 65, 76),
      _stroke(_ink, 4.2),
    );
    _drop(c, const Offset(24, 62), 1.3);
  }

  void _heart(Canvas c) {
    final p = Path()
      ..moveTo(50, 90)
      ..cubicTo(8, 60, 4, 30, 27, 19)
      ..cubicTo(40, 13, 50, 23, 50, 32)
      ..cubicTo(50, 23, 60, 13, 73, 19)
      ..cubicTo(96, 30, 92, 60, 50, 90)
      ..close();
    c.drawPath(
      p,
      _grad(p.getBounds(), const [Color(0xFFFF7A7A), Color(0xFFE0102B)]),
    );
    c.drawPath(p, _stroke(const Color(0x40800010), 1.4));
    c.save();
    c.translate(31, 33);
    c.rotate(-0.6);
    c.drawOval(
      Rect.fromCenter(center: Offset.zero, width: 14, height: 8),
      _fill(Colors.white.withAlpha(120)),
    );
    c.restore();
  }

  void _like(Canvas c) {
    final cuff = Rect.fromLTRB(5, 48, 27, 92);
    c.drawRRect(
      RRect.fromRectAndRadius(cuff, const Radius.circular(6)),
      _grad(
        cuff,
        const [Color(0xFF6C9BFF), Color(0xFF3A66D8)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ),
    );
    final palm = RRect.fromRectAndRadius(
      Rect.fromLTRB(26, 46, 92, 92),
      const Radius.circular(14),
    );
    final thumb = Path()
      ..moveTo(30, 50)
      ..lineTo(41, 20)
      ..quadraticBezierTo(46, 6, 57, 11)
      ..quadraticBezierTo(66, 16, 60, 32)
      ..lineTo(56, 48)
      ..close();
    final skin = _grad(
      Rect.fromLTRB(26, 8, 92, 92),
      const [Color(0xFFFFE27A), Color(0xFFF2A413)],
    );
    c.drawRRect(palm, skin);
    c.drawPath(thumb, skin);
    final line = _stroke(const Color(0x55A05A00), 2.6);
    for (final y in const [60.0, 72.0, 84.0]) {
      c.drawLine(Offset(60, y), Offset(88, y), line);
    }
  }

  void _pray(Canvas c) {
    c.save();
    c.translate(50, 55);
    c.rotate(0.28);
    c.translate(-50, -55);
    final back = Path()
      ..moveTo(24, 90)
      ..lineTo(24, 34)
      ..quadraticBezierTo(24, 14, 36, 12)
      ..quadraticBezierTo(47, 10, 50, 20)
      ..lineTo(50, 90)
      ..close();
    final front = Path()
      ..moveTo(50, 92)
      ..lineTo(50, 22)
      ..quadraticBezierTo(53, 8, 64, 10)
      ..quadraticBezierTo(76, 12, 76, 32)
      ..lineTo(76, 90)
      ..close();
    c.drawPath(
      back,
      _grad(back.getBounds(), const [Color(0xFFF3B33C), Color(0xFFE08F08)]),
    );
    c.drawPath(
      front,
      _grad(front.getBounds(), const [Color(0xFFFFE98A), Color(0xFFF5AF2C)]),
    );
    final fin = _stroke(const Color(0x59A05A00), 2);
    c.drawLine(const Offset(60, 14), const Offset(60, 38), fin);
    c.drawLine(const Offset(68, 18), const Offset(68, 40), fin);
    c.drawLine(const Offset(37, 18), const Offset(37, 40), fin);
    c.drawLine(
      const Offset(50, 22),
      const Offset(50, 90),
      _stroke(const Color(0x80A05A00), 2.2),
    );
    c.drawOval(
      Rect.fromCenter(center: const Offset(36, 72), width: 14, height: 26),
      _fill(const Color(0x8CFFE98A)),
    );
    c.drawOval(
      Rect.fromCenter(center: const Offset(36, 72), width: 14, height: 26),
      _stroke(const Color(0x4DA05A00), 1.6),
    );
    c.restore();
    final cuff = Rect.fromLTRB(26, 89, 74, 100);
    c.drawRRect(
      RRect.fromRectAndRadius(cuff, const Radius.circular(4)),
      _grad(
        cuff,
        const [Color(0xFF6C9BFF), Color(0xFF3A66D8)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ),
    );
  }

  @override
  bool shouldRepaint(_EmojiPainter old) => old.kind != kind;
}
