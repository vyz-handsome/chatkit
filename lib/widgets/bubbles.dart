import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models.dart';
import '../playback.dart';
import '../store.dart';
import '../theme.dart';
import 'glass.dart';

String fmtTime(int minutes, bool use24h) {
  final h = (minutes ~/ 60) % 24;
  final m = minutes % 60;
  final mm = m.toString().padLeft(2, '0');
  if (use24h) return '${h.toString().padLeft(2, '0')}.$mm';
  final h12 = h % 12 == 0 ? 12 : h % 12;
  return '$h12.$mm ${h < 12 ? 'AM' : 'PM'}';
}

String fmtDur(int ms) {
  final s = (ms / 1000).round();
  return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
}

String previewOf(ChatMessage m) {
  switch (m.type) {
    case MsgType.text:
      return m.text;
    case MsgType.image:
      return m.text.isEmpty ? '📷 Foto' : '📷 ${m.text}';
    case MsgType.sticker:
      return 'Stiker';
    case MsgType.voice:
      return '🎤 Pesan suara (${fmtDur(m.durationMs)})';
    case MsgType.deleted:
      return 'Pesan ini telah dihapus';
    case MsgType.divider:
      return m.text;
  }
}

/// Centang status gaya sendiri (garis bulat, bukan ikon app lain).
class TickPainter extends CustomPainter {
  TickPainter(this.status, this.base, this.read);
  final MsgStatus status;
  final Color base;
  final Color read;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = status == MsgStatus.read ? read : base
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.7
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    Path check(double dx) => Path()
      ..moveTo(1.5 + dx, 5.5)
      ..lineTo(4.5 + dx, 8.5)
      ..lineTo(10.5 + dx, 1.5);
    canvas.drawPath(check(0), paint);
    if (status != MsgStatus.sent) canvas.drawPath(check(5), paint);
  }

  @override
  bool shouldRepaint(TickPainter old) =>
      old.status != status || old.base != base || old.read != read;
}

class WaveformPainter extends CustomPainter {
  WaveformPainter(this.data, this.progress, this.played, this.rest);
  final List<double> data;
  final double progress;
  final Color played;
  final Color rest;

  @override
  void paint(Canvas canvas, Size size) {
    final n = data.length;
    if (n == 0) return;
    final slot = size.width / n;
    final bw = slot * 0.58;
    for (int i = 0; i < n; i++) {
      final h = math.max(3.0, data[i] * size.height);
      final x = i * slot + (slot - bw) / 2;
      final y = (size.height - h) / 2;
      final paint = Paint()..color = (i + 0.5) / n <= progress ? played : rest;
      canvas.drawRRect(
        RRect.fromLTRBR(x, y, x + bw, y + h, Radius.circular(bw / 2)),
        paint,
      );
    }
    if (progress > 0 && progress < 1) {
      canvas.drawCircle(
        Offset(progress * size.width, size.height / 2),
        4.6,
        Paint()..color = played,
      );
    }
  }

  @override
  bool shouldRepaint(WaveformPainter old) =>
      old.progress != progress ||
      old.data != data ||
      old.played != played ||
      old.rest != rest;
}

class MessageRow extends StatelessWidget {
  const MessageRow({
    super.key,
    required this.project,
    required this.m,
    required this.prev,
    required this.next,
    required this.playback,
    required this.maxWidth,
    this.onTap,
    this.onLongPress,
    this.onVoiceTap,
  });

  final ChatProject project;
  final ChatMessage m;
  final ChatMessage? prev;
  final ChatMessage? next;
  final PlaybackState playback;
  final double maxWidth;
  final void Function(ChatMessage)? onTap;
  final void Function(ChatMessage)? onLongPress;
  final void Function(ChatMessage)? onVoiceTap;

  @override
  Widget build(BuildContext context) {
    final pal = Palette(project.dark);

    if (m.type == MsgType.divider) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Center(
          child: GestureDetector(
            onTap: () => onTap?.call(m),
            child: Glass(
              radius: 14,
              dark: pal.dark,
              blur: 14,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              child: Text(
                m.text,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: pal.ink.withAlpha(200),
                ),
              ),
            ),
          ),
        ),
      );
    }

    final isMe = m.senderId == ChatProject.meId;
    final firstRun = prev == null ||
        prev!.type == MsgType.divider ||
        prev!.senderId != m.senderId;
    final lastRun = next == null ||
        next!.type == MsgType.divider ||
        next!.senderId != m.senderId;
    final showName = project.isGroup &&
        !isMe &&
        firstRun &&
        (m.type == MsgType.text ||
            m.type == MsgType.voice ||
            m.type == MsgType.deleted);

    final bubble = _bubble(context, pal, isMe, lastRun, showName);

    Widget content = bubble;
    if (m.reaction != null) {
      content = Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            bubble,
            Positioned(
              bottom: -13,
              right: isMe ? 10 : null,
              left: isMe ? null : 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: pal.dark ? const Color(0xFF3A3A3C) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: pal.dark
                        ? const Color(0xFF1C1C1E)
                        : const Color(0xFFE2E2E6),
                  ),
                ),
                child: Text(m.reaction!, style: const TextStyle(fontSize: 14)),
              ),
            ),
          ],
        ),
      );
    }

    Widget row;
    if (project.isGroup && !isMe) {
      final member = project.member(m.senderId);
      row = Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 30,
            height: 30,
            child: lastRun
                ? Avatar(
                    file: member?.avatar,
                    name: member?.name ?? '?',
                    color: Color(member?.color ?? 0xFF2F9BFF),
                    size: 30,
                  )
                : null,
          ),
          const SizedBox(width: 6),
          Flexible(child: content),
        ],
      );
    } else {
      row = content;
    }

    return Padding(
      padding: EdgeInsets.only(top: firstRun ? 9 : 2),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: GestureDetector(
          onTap: () => onTap?.call(m),
          onLongPress: onLongPress == null ? null : () => onLongPress!(m),
          child: row,
        ),
      ),
    );
  }

  Widget _meta(Palette pal, bool isMe, {Color? color}) {
    final c = color ?? (isMe ? pal.metaMe : pal.metaOther);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (m.starred) ...[
          Icon(Icons.star_rounded, size: 12, color: c),
          const SizedBox(width: 2),
        ],
        Text(
          fmtTime(m.minutes, project.use24h),
          style: TextStyle(fontSize: 11, color: c, height: 1),
        ),
        if (isMe) ...[
          const SizedBox(width: 4),
          CustomPaint(
            size: const Size(17, 10),
            painter: TickPainter(
              m.status,
              color ?? pal.metaMe,
              color == null ? pal.tickRead : color,
            ),
          ),
        ],
      ],
    );
  }

  Widget _textWithMeta(
    Palette pal,
    bool isMe,
    List<InlineSpan> spans,
    TextStyle style,
  ) {
    final metaW = (isMe ? 62.0 : 38.0) + (m.starred ? 14 : 0);
    return Stack(
      children: [
        Text.rich(
          TextSpan(
            style: style,
            children: [
              ...spans,
              WidgetSpan(child: SizedBox(width: metaW, height: 12)),
            ],
          ),
        ),
        Positioned(right: 0, bottom: 0, child: _meta(pal, isMe)),
      ],
    );
  }

  Widget _quote(Palette pal, bool isMe, ChatMessage target) {
    final senderIsMe = target.senderId == ChatProject.meId;
    final member = project.member(target.senderId);
    final accent = senderIsMe
        ? (isMe ? Colors.white : pal.accent)
        : Color(member?.color ?? 0xFF2F9BFF);
    return Container(
      constraints: const BoxConstraints(minWidth: 130),
      margin: const EdgeInsets.only(bottom: 5),
      padding: const EdgeInsets.fromLTRB(8, 5, 8, 5),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(isMe ? 32 : 16),
        borderRadius: BorderRadius.circular(8),
        border: Border(left: BorderSide(color: accent, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            project.nameOf(target.senderId),
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: accent,
            ),
          ),
          Text(
            previewOf(target),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13.5,
              color: (isMe ? pal.textMe : pal.textOther).withAlpha(210),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bubble(
    BuildContext context,
    Palette pal,
    bool isMe,
    bool lastRun,
    bool showName,
  ) {
    final fg = isMe ? pal.textMe : pal.textOther;
    final metaColor = isMe ? pal.metaMe : pal.metaOther;
    final reply = project.messageById(m.replyToId);
    final children = <Widget>[];

    if (m.type == MsgType.sticker) {
      final path = Store.resolve(m.media);
      return ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (path != null)
              Image.file(
                File(path),
                width: 150,
                height: 150,
                fit: BoxFit.contain,
                cacheWidth: 400,
              ),
            Container(
              margin: const EdgeInsets.only(top: 2),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black.withAlpha(80),
                borderRadius: BorderRadius.circular(10),
              ),
              child: _meta(pal, isMe, color: Colors.white),
            ),
          ],
        ),
      );
    }

    if (showName) {
      final member = project.member(m.senderId);
      children.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: Text(
            project.nameOf(m.senderId),
            style: TextStyle(
              color: Color(member?.color ?? 0xFF2F9BFF),
              fontWeight: FontWeight.w700,
              fontSize: 13.5,
            ),
          ),
        ),
      );
    }
    if (reply != null) children.add(_quote(pal, isMe, reply));

    EdgeInsets padding = const EdgeInsets.fromLTRB(11, 7, 11, 6);

    switch (m.type) {
      case MsgType.text:
        children.add(
          _textWithMeta(
            pal,
            isMe,
            [TextSpan(text: m.text)],
            TextStyle(color: fg, fontSize: 16.5, height: 1.25),
          ),
        );
        break;
      case MsgType.deleted:
        children.add(
          _textWithMeta(
            pal,
            isMe,
            [
              WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: Icon(Icons.block, size: 15, color: metaColor),
              ),
              const TextSpan(text: ' Pesan ini telah dihapus'),
            ],
            TextStyle(
              color: fg.withAlpha(200),
              fontSize: 15.5,
              fontStyle: FontStyle.italic,
            ),
          ),
        );
        break;
      case MsgType.image:
        padding = const EdgeInsets.all(3);
        final path = Store.resolve(m.media);
        final w = math.min(maxWidth - 6, 240.0);
        final h = (w / (m.aspect <= 0 ? 1.0 : m.aspect))
            .clamp(120.0, 340.0)
            .toDouble();
        children.add(
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: path == null
                    ? SizedBox(width: w, height: h)
                    : Image.file(
                        File(path),
                        width: w,
                        height: h,
                        fit: BoxFit.cover,
                        cacheWidth: 720,
                      ),
              ),
              if (m.text.isEmpty)
                Positioned(
                  right: 8,
                  bottom: 6,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black.withAlpha(90),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: _meta(pal, isMe, color: Colors.white),
                  ),
                ),
            ],
          ),
        );
        if (m.text.isNotEmpty) {
          children.add(
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 5, 8, 3),
              child: SizedBox(
                width: w - 16,
                child: _textWithMeta(
                  pal,
                  isMe,
                  [TextSpan(text: m.text)],
                  TextStyle(color: fg, fontSize: 16, height: 1.25),
                ),
              ),
            ),
          );
        }
        break;
      case MsgType.voice:
        children.add(
          AnimatedBuilder(
            animation: playback,
            builder: (context, _) {
              final active = playback.activeId == m.id;
              final pos = active ? playback.positionMs : 0;
              final prog = m.durationMs > 0
                  ? (pos / m.durationMs).clamp(0.0, 1.0).toDouble()
                  : 0.0;
              final playing = active && playback.playing;
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: () => onVoiceTap?.call(m),
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: fg.withAlpha(isMe ? 60 : 30),
                      ),
                      child: Icon(
                        playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                        color: fg,
                        size: 24,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 130,
                    height: 30,
                    child: CustomPaint(
                      painter: WaveformPainter(
                        m.waveform,
                        prog,
                        isMe ? Colors.white : pal.accent,
                        isMe ? Colors.white.withAlpha(110) : metaColor.withAlpha(150),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 34,
                    child: Text(
                      fmtDur(active && pos > 0 ? pos : m.durationMs),
                      style: TextStyle(fontSize: 12.5, color: metaColor),
                    ),
                  ),
                ],
              );
            },
          ),
        );
        children.add(
          Align(alignment: Alignment.centerRight, child: _meta(pal, isMe)),
        );
        break;
      case MsgType.sticker:
      case MsgType.divider:
        break;
    }

    final r = BorderRadius.only(
      topLeft: const Radius.circular(18),
      topRight: const Radius.circular(18),
      bottomLeft: Radius.circular(isMe ? 18 : (lastRun ? 5 : 18)),
      bottomRight: Radius.circular(isMe ? (lastRun ? 5 : 18) : 18),
    );

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          borderRadius: r,
          color: isMe ? null : pal.otherBubble,
          gradient: isMe
              ? LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: pal.meBubble,
                )
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: children,
        ),
      ),
    );
  }
}
