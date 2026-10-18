import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models.dart';
import '../playback.dart';
import '../store.dart';
import '../theme.dart';
import 'bubbles.dart';
import 'glass.dart';

/// Tampilan chat penuh (header kaca, daftar pesan, kolom ketik kaca).
/// Dipakai di editor, preview, dan export.
class ChatView extends StatelessWidget {
  const ChatView({
    super.key,
    required this.project,
    required this.playback,
    this.messages,
    this.editable = false,
    this.scroll,
    this.onTapMessage,
    this.onLongPressMessage,
    this.onVoiceTap,
    this.onHeaderTap,
    this.onPlus,
    this.onCamera,
    this.onMic,
    this.onSendText,
    this.textController,
    this.senderBar,
    this.replyingTo,
    this.onClearReply,
  });

  final ChatProject project;
  final PlaybackState playback;
  final List<ChatMessage>? messages;
  final bool editable;
  final ScrollController? scroll;
  final void Function(ChatMessage)? onTapMessage;
  final void Function(ChatMessage)? onLongPressMessage;
  final void Function(ChatMessage)? onVoiceTap;
  final VoidCallback? onHeaderTap;
  final VoidCallback? onPlus;
  final VoidCallback? onCamera;
  final VoidCallback? onMic;
  final VoidCallback? onSendText;
  final TextEditingController? textController;
  final Widget? senderBar;
  final ChatMessage? replyingTo;
  final VoidCallback? onClearReply;

  static const double headerH = 58;
  static const double inputH = 44;

  @override
  Widget build(BuildContext context) {
    final pal = Palette(project.dark);
    final mq = MediaQuery.of(context);
    final top = mq.padding.top;
    final bottomSafe = math.max(mq.padding.bottom, 10.0);
    final kb = editable ? mq.viewInsets.bottom : 0.0;
    final msgs = messages ?? project.messages;
    final inputBottom = kb > 0 ? kb + 8 : bottomSafe;
    double listBottom = inputBottom + inputH + 14;
    if (replyingTo != null) listBottom += 54;
    if (senderBar != null) listBottom += 44;
    final listTop = top + 6 + headerH + 24;

    return Material(
      type: MaterialType.transparency,
      child: DefaultTextStyle(
        style: TextStyle(color: pal.textOther, fontSize: 16),
        child: ClipRect(
          child: LayoutBuilder(
            builder: (context, c) {
              final maxBubble = c.maxWidth * 0.78 - (project.isGroup ? 36 : 0);
              return Stack(
                children: [
                  Positioned.fill(
                    child: RepaintBoundary(child: _Background(project: project)),
                  ),
                  Positioned.fill(
                    child: IgnorePointer(
                      child: RepaintBoundary(
                        child: CustomPaint(
                          painter: _WatermarkPainter(
                            pal.dark
                                ? Colors.white.withAlpha(26)
                                : Colors.black.withAlpha(22),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: ListView.builder(
                      reverse: true,
                      controller: scroll,
                      physics:
                          editable ? null : const NeverScrollableScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(12, listTop, 12, listBottom),
                      itemCount: msgs.length,
                      itemBuilder: (context, ri) {
                        final i = msgs.length - 1 - ri;
                        return MessageRow(
                          key: ValueKey(msgs[i].id),
                          project: project,
                          m: msgs[i],
                          prev: i > 0 ? msgs[i - 1] : null,
                          next: i < msgs.length - 1 ? msgs[i + 1] : null,
                          playback: playback,
                          maxWidth: maxBubble,
                          onTap: onTapMessage,
                          onLongPress: onLongPressMessage,
                          onVoiceTap: onVoiceTap,
                        );
                      },
                    ),
                  ),
                  Positioned(
                    top: top + 6,
                    left: 10,
                    right: 10,
                    child: _Header(
                      project: project,
                      pal: pal,
                      onTap: onHeaderTap,
                    ),
                  ),
                  Positioned(
                    top: top + 6 + headerH + 4,
                    left: 0,
                    right: 0,
                    child: IgnorePointer(
                      child: Center(
                        child: Text(
                          'Chat Simulasi',
                          style: TextStyle(
                            fontSize: 9.5,
                            letterSpacing: 0.8,
                            fontWeight: FontWeight.w600,
                            color: pal.ink.withAlpha(105),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 10,
                    right: 10,
                    bottom: inputBottom,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (senderBar != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: senderBar,
                          ),
                        if (replyingTo != null)
                          _ReplyBar(
                            project: project,
                            pal: pal,
                            target: replyingTo!,
                            onClose: onClearReply,
                          ),
                        _InputBar(
                          pal: pal,
                          editable: editable,
                          controller: textController,
                          onPlus: onPlus,
                          onCamera: onCamera,
                          onMic: onMic,
                          onSend: onSendText,
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Background extends StatelessWidget {
  const _Background({required this.project});
  final ChatProject project;

  @override
  Widget build(BuildContext context) {
    final preset =
        wallPresets[project.bgPreset.clamp(0, wallPresets.length - 1)];
    final colors = project.dark ? preset.dark : preset.light;
    final gradient = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: colors,
        ),
      ),
    );
    final path = Store.resolve(project.bgFile);
    if (path == null || !File(path).existsSync()) return gradient;
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.file(File(path), fit: BoxFit.cover, cacheWidth: 1170),
        if (project.dark) Container(color: Colors.black.withAlpha(70)),
      ],
    );
  }
}

class _WatermarkPainter extends CustomPainter {
  _WatermarkPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final tp = TextPainter(
      text: TextSpan(
        text: 'ChatKit · simulasi',
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.6,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final span = size.height + size.width;
    canvas.save();
    canvas.rotate(-0.45);
    int row = 0;
    for (double y = -span; y < span; y += 95) {
      final off = (row++ % 2 == 0) ? 0.0 : 75.0;
      for (double x = -span + off; x < span; x += 150) {
        tp.paint(canvas, Offset(x, y));
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_WatermarkPainter old) => old.color != color;
}

class _Header extends StatelessWidget {
  const _Header({required this.project, required this.pal, this.onTap});
  final ChatProject project;
  final Palette pal;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ink = pal.ink;
    return Glass(
      radius: 29,
      dark: pal.dark,
      child: SizedBox(
        height: ChatView.headerH,
        child: Row(
          children: [
            const SizedBox(width: 10),
            Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: ink),
            if (project.unread > 0) ...[
              const SizedBox(width: 4),
              Text(
                '${project.unread}',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: ink,
                ),
              ),
            ],
            const SizedBox(width: 8),
            Avatar(
              file: project.avatar,
              name: project.title,
              color: const Color(0xFF2F9BFF),
              size: 38,
            ),
            const SizedBox(width: 9),
            Expanded(
              child: GestureDetector(
                onTap: onTap,
                behavior: HitTestBehavior.opaque,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      project.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w700,
                        color: ink,
                        height: 1.15,
                      ),
                    ),
                    Text(
                      project.statusText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: pal.metaOther,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Icon(Icons.videocam_rounded, size: 26, color: ink),
            const SizedBox(width: 16),
            Icon(Icons.call_rounded, size: 22, color: ink),
            const SizedBox(width: 16),
          ],
        ),
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  const _InputBar({
    required this.pal,
    required this.editable,
    this.controller,
    this.onPlus,
    this.onCamera,
    this.onMic,
    this.onSend,
  });

  final Palette pal;
  final bool editable;
  final TextEditingController? controller;
  final VoidCallback? onPlus;
  final VoidCallback? onCamera;
  final VoidCallback? onMic;
  final VoidCallback? onSend;

  @override
  Widget build(BuildContext context) {
    final hint = pal.metaOther;
    return Row(
      children: [
        GlassCircle(icon: Icons.add_rounded, dark: pal.dark, onTap: onPlus),
        const SizedBox(width: 8),
        Expanded(
          child: Glass(
            radius: 24,
            dark: pal.dark,
            child: SizedBox(
              height: ChatView.inputH,
              child: Row(
                children: [
                  const SizedBox(width: 14),
                  Expanded(
                    child: editable && controller != null
                        ? TextField(
                            controller: controller,
                            minLines: 1,
                            maxLines: 1,
                            style: TextStyle(color: pal.ink, fontSize: 16),
                            cursorColor: pal.accent,
                            decoration: InputDecoration(
                              border: InputBorder.none,
                              isCollapsed: true,
                              hintText: 'Pesan',
                              hintStyle: TextStyle(color: hint, fontSize: 16),
                            ),
                            onSubmitted: (_) => onSend?.call(),
                          )
                        : Text(
                            'Pesan',
                            style: TextStyle(color: hint, fontSize: 16),
                          ),
                  ),
                  Icon(Icons.sticky_note_2_outlined, size: 22, color: hint),
                  const SizedBox(width: 12),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        if (editable && controller != null)
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller!,
            builder: (context, v, _) {
              if (v.text.trim().isNotEmpty) {
                return GlassCircle(
                  icon: Icons.arrow_upward_rounded,
                  dark: pal.dark,
                  onTap: onSend,
                  iconColor: Colors.white,
                  tint: pal.accent,
                );
              }
              return _cameraMic();
            },
          )
        else
          _cameraMic(),
      ],
    );
  }

  Widget _cameraMic() => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GlassCircle(
            icon: Icons.camera_alt_rounded,
            dark: pal.dark,
            onTap: onCamera,
          ),
          const SizedBox(width: 8),
          GlassCircle(icon: Icons.mic_rounded, dark: pal.dark, onTap: onMic),
        ],
      );
}

class _ReplyBar extends StatelessWidget {
  const _ReplyBar({
    required this.project,
    required this.pal,
    required this.target,
    this.onClose,
  });

  final ChatProject project;
  final Palette pal;
  final ChatMessage target;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Glass(
        radius: 18,
        dark: pal.dark,
        padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
        child: Row(
          children: [
            Container(width: 3, height: 34, color: pal.accent),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Membalas ${project.nameOf(target.senderId)}',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: pal.accent,
                    ),
                  ),
                  Text(
                    previewOf(target),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13.5, color: pal.ink),
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: onClose,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Icon(Icons.close_rounded, size: 20, color: pal.metaOther),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
