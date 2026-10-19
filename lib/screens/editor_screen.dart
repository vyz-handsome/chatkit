import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:record/record.dart';

import '../audio_utils.dart';
import '../media_utils.dart';
import '../models.dart';
import '../playback.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/bubbles.dart';
import '../widgets/chat_view.dart';
import '../widgets/emoji.dart';
import '../widgets/glass.dart';
import 'export_screen.dart';
import 'sheets.dart';

class EditorScreen extends StatefulWidget {
  const EditorScreen({super.key, required this.project});
  final ChatProject project;

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  ChatProject get pr => widget.project;
  final live = LivePlayback();
  final text = TextEditingController();
  final scroll = ScrollController();
  String sender = ChatProject.meId;
  ChatMessage? replyTo;
  bool hideChrome = false;
  Timer? _saveTimer;

  @override
  void dispose() {
    _saveTimer?.cancel();
    Store.save(pr);
    live.dispose();
    text.dispose();
    scroll.dispose();
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 500), () => Store.save(pr));
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  int _defaultMinutes() {
    final list = pr.messages.where((m) => m.type != MsgType.divider);
    if (list.isEmpty) {
      final n = DateTime.now();
      return n.hour * 60 + n.minute;
    }
    return list.last.minutes;
  }

  ChatMessage _newMsg(
    MsgType type, {
    String text = '',
    String? media,
    double aspect = 1,
    int durationMs = 0,
    List<double> waveform = const <double>[],
  }) {
    return ChatMessage(
      id: newId(),
      senderId: sender,
      type: type,
      text: text,
      media: media,
      aspect: aspect,
      durationMs: durationMs,
      waveform: waveform,
      minutes: _defaultMinutes(),
      replyToId: replyTo?.id,
    );
  }

  void _add(ChatMessage m) {
    pr.messages.add(m);
    replyTo = null;
    _changed();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scroll.hasClients) {
        scroll.animateTo(
          0,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendText() {
    final t = text.text.trim();
    if (t.isEmpty) return;
    _add(_newMsg(MsgType.text, text: t));
    text.clear();
  }

  Future<void> _busy(String label, Future<void> Function() job) async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: AlertDialog(
          content: Row(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(width: 20),
              Expanded(child: Text(label)),
            ],
          ),
        ),
      ),
    );
    try {
      await job();
    } catch (e) {
      if (mounted) _snack(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
    }
  }

  // ------------------------------------------------------------ tambah pesan

  Future<void> _addPhotos() async {
    final xs = await ImagePicker().pickMultiImage();
    if (xs.isEmpty) return;
    await _busy('Menambahkan foto...', () async {
      for (final x in xs) {
        final name = await Store.importFile(x.path);
        final aspect = await imageAspect(Store.resolve(name)!);
        _add(_newMsg(MsgType.image, media: name, aspect: aspect));
      }
    });
  }

  Future<void> _addSticker() async {
    final x = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (x == null) return;
    await _busy('Membuat stiker...', () async {
      final name = '${newId()}.png';
      await makeSticker(x.path, Store.resolve(name)!);
      _add(_newMsg(MsgType.sticker, media: name));
    });
  }

  void _addVoice(VoiceInfo info) {
    _add(
      _newMsg(
        MsgType.voice,
        media: info.file,
        durationMs: info.durationMs,
        waveform: info.waveform,
      ),
    );
  }

  Future<void> _voiceFromVideo() async {
    final x = await ImagePicker().pickVideo(source: ImageSource.gallery);
    if (x == null) return;
    await _busy('Mengubah video jadi voice note...', () async {
      _addVoice(await AudioUtils.importAudio(x.path));
    });
  }

  Future<void> _voiceFromFile() async {
    final r = await FilePicker.platform.pickFiles(type: FileType.audio);
    final path = r?.files.single.path;
    if (path == null) return;
    await _busy('Memproses audio...', () async {
      _addVoice(await AudioUtils.importAudio(path));
    });
  }

  Future<void> _record() async {
    final path = await showDialog<String?>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _RecordDialog(),
    );
    if (path == null) return;
    await _busy('Memproses rekaman...', () async {
      _addVoice(await AudioUtils.importAudio(path));
    });
  }

  Future<void> _addDivider() async {
    final c = TextEditingController(text: 'Hari ini');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Pemisah tanggal'),
        content: TextField(
          controller: c,
          decoration: const InputDecoration(hintText: 'mis. Hari ini, Kemarin'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Tambah'),
          ),
        ],
      ),
    );
    final t = c.text.trim();
    c.dispose();
    if (ok == true && t.isNotEmpty) {
      pr.messages.add(
        ChatMessage(
          id: newId(),
          senderId: '',
          type: MsgType.divider,
          text: t,
          minutes: 0,
        ),
      );
      _changed();
    }
  }

  // ------------------------------------------------------------------- sheet

  void _showPlus() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        Widget tile(IconData i, String t, VoidCallback f) => ListTile(
              leading: Icon(i),
              title: Text(t),
              onTap: () {
                Navigator.pop(ctx);
                f();
              },
            );
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              tile(Icons.photo_rounded, 'Foto', _addPhotos),
              tile(Icons.emoji_emotions_rounded, 'Stiker (dari foto)', _addSticker),
              tile(Icons.videocam_rounded, 'Voice note dari video', _voiceFromVideo),
              tile(Icons.audio_file_rounded, 'Voice note dari file audio', _voiceFromFile),
              tile(Icons.mic_rounded, 'Rekam voice note', _record),
              tile(Icons.calendar_today_rounded, 'Pemisah tanggal', _addDivider),
            ],
          ),
        );
      },
    );
  }

  void _showTools() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        Widget tile(IconData i, String t, VoidCallback f) => ListTile(
              leading: Icon(i),
              title: Text(t),
              onTap: () {
                Navigator.pop(ctx);
                f();
              },
            );
        return SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                tile(Icons.settings_rounded, 'Pengaturan chat',
                    () => showSettingsSheet(context, pr, _changed)),
                tile(Icons.wallpaper_rounded, 'Latar belakang',
                    () => showBackgroundSheet(context, pr, _changed)),
                tile(
                  pr.dark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                  pr.dark ? 'Mode terang' : 'Mode gelap',
                  () {
                    pr.dark = !pr.dark;
                    _changed();
                  },
                ),
                tile(Icons.calendar_today_rounded, 'Tambah pemisah tanggal',
                    _addDivider),
                tile(Icons.visibility_off_rounded,
                    'Mode rekam layar (sembunyikan kontrol)', () {
                  setState(() => hideChrome = true);
                  _snack('Ketuk dua kali pojok kiri atas untuk menampilkan lagi');
                }),
                tile(Icons.ios_share_rounded, 'Export (gambar / video)', () async {
                  await Store.save(pr);
                  if (!mounted) return;
                  await live.stop();
                  if (!mounted) return;
                  Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => ExportScreen(project: pr),
                    ),
                  );
                }),
                tile(Icons.delete_sweep_rounded, 'Hapus semua pesan', _confirmClear),
                tile(Icons.arrow_back_rounded, 'Kembali ke daftar proyek',
                    () => Navigator.pop(context)),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmClear() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus semua pesan?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (ok == true) {
      pr.messages.clear();
      replyTo = null;
      _changed();
    }
  }

  // --------------------------------------------------------- menu tahan pesan

  Future<void> _contextMenu(ChatMessage m) async {
    if (m.type == MsgType.divider) {
      _editMessage(m);
      return;
    }
    final isMe = m.senderId == ChatProject.meId;
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Tutup',
      barrierColor: Colors.black.withAlpha(120),
      transitionDuration: const Duration(milliseconds: 140),
      pageBuilder: (ctx, a1, a2) {
        void act(VoidCallback f) {
          Navigator.pop(ctx);
          f();
        }

        Widget item(String label, IconData icon, VoidCallback f,
            {bool danger = false}) {
          final c = danger ? const Color(0xFFFF6B6B) : Colors.white;
          return InkWell(
            onTap: () => act(f),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              child: Row(
                children: [
                  Expanded(
                    child: Text(label, style: TextStyle(fontSize: 17, color: c)),
                  ),
                  Icon(icon, size: 21, color: c),
                ],
              ),
            ),
          );
        }

        final divider = Container(height: 0.6, color: Colors.white24);
        final entries = <Widget>[
          item('Balas', Icons.reply_rounded, () => setState(() => replyTo = m)),
          divider,
          item('Teruskan', Icons.forward_rounded, () {}),
          divider,
          item('Salin', Icons.copy_rounded, () {
            if (m.text.isNotEmpty) Clipboard.setData(ClipboardData(text: m.text));
          }),
          divider,
          item(
            m.starred ? 'Hapus Bintang' : 'Beri Bintang',
            m.starred ? Icons.star_rounded : Icons.star_border_rounded,
            () {
              m.starred = !m.starred;
              _changed();
            },
          ),
          divider,
          item('Sematkan', Icons.push_pin_outlined, () {}),
          divider,
          item('Laporkan', Icons.warning_amber_rounded, () {}),
          divider,
          item('Hapus', Icons.delete_outline_rounded, () {
            pr.messages.remove(m);
            _changed();
          }, danger: true),
        ];

        return Material(
          type: MaterialType.transparency,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.pop(ctx),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment:
                        isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                    children: [
                      Glass(
                        radius: 28,
                        dark: true,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (final e in reactionEmojis)
                              GestureDetector(
                                onTap: () => act(() {
                                  m.reaction = m.reaction == e ? null : e;
                                  _changed();
                                }),
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: m.reaction == e
                                        ? Colors.white24
                                        : Colors.transparent,
                                  ),
                                  child: FakeEmoji(e, size: 30),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      IgnorePointer(
                        child: MessageRow(
                          project: pr,
                          m: m,
                          prev: null,
                          next: null,
                          playback: live,
                          maxWidth: MediaQuery.of(ctx).size.width * 0.72,
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: 250,
                        child: Glass(
                          radius: 18,
                          dark: true,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: entries,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ------------------------------------------------------------- ubah pesan

  Future<void> _editMessage(ChatMessage m) async {
    final textC = TextEditingController(text: m.text);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          void upd(VoidCallback fn) {
            setS(fn);
            _changed();
          }

          final idx = pr.messages.indexOf(m);
          final isDivider = m.type == MsgType.divider;
          final hasText = isDivider ||
              m.type == MsgType.text ||
              m.type == MsgType.image;
          final senders = <MapEntry<String, String>>[
            const MapEntry(ChatProject.meId, 'Gue'),
            ...pr.members.map((e) => MapEntry(e.id, e.name)),
          ];
          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              children: [
                Text('Ubah pesan', style: Theme.of(ctx).textTheme.titleLarge),
                const SizedBox(height: 12),
                if (hasText)
                  TextField(
                    controller: textC,
                    maxLines: null,
                    decoration: InputDecoration(
                      border: const OutlineInputBorder(),
                      labelText: isDivider
                          ? 'Teks pemisah'
                          : (m.type == MsgType.image ? 'Keterangan foto' : 'Isi pesan'),
                    ),
                    onChanged: (v) {
                      m.text = v;
                      _changed();
                    },
                  ),
                if (!isDivider) ...[
                  const SizedBox(height: 14),
                  Text('Pengirim', style: Theme.of(ctx).textTheme.titleSmall),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final s in senders)
                        ChoiceChip(
                          label: Text(s.value),
                          selected: m.senderId == s.key,
                          onSelected: (_) => upd(() => m.senderId = s.key),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Text('Jam', style: Theme.of(ctx).textTheme.titleSmall),
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.schedule_rounded),
                        label: Text(fmtTime(m.minutes, pr.use24h)),
                        onPressed: () async {
                          final t = await showTimePicker(
                            context: ctx,
                            initialTime: TimeOfDay(
                              hour: (m.minutes ~/ 60) % 24,
                              minute: m.minutes % 60,
                            ),
                          );
                          if (t != null) upd(() => m.minutes = t.hour * 60 + t.minute);
                        },
                      ),
                    ],
                  ),
                  if (m.senderId == ChatProject.meId) ...[
                    const SizedBox(height: 10),
                    Text('Status', style: Theme.of(ctx).textTheme.titleSmall),
                    Wrap(
                      spacing: 8,
                      children: [
                        ChoiceChip(
                          label: const Text('Terkirim'),
                          selected: m.status == MsgStatus.sent,
                          onSelected: (_) => upd(() => m.status = MsgStatus.sent),
                        ),
                        ChoiceChip(
                          label: const Text('Diterima'),
                          selected: m.status == MsgStatus.delivered,
                          onSelected: (_) =>
                              upd(() => m.status = MsgStatus.delivered),
                        ),
                        ChoiceChip(
                          label: const Text('Dibaca'),
                          selected: m.status == MsgStatus.read,
                          onSelected: (_) => upd(() => m.status = MsgStatus.read),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 10),
                  Text('Reaksi', style: Theme.of(ctx).textTheme.titleSmall),
                  Wrap(
                    spacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('Tanpa'),
                        selected: m.reaction == null,
                        onSelected: (_) => upd(() => m.reaction = null),
                      ),
                      for (final e in reactionEmojis)
                        ChoiceChip(
                          label: FakeEmoji(e, size: 22),
                          selected: m.reaction == e,
                          onSelected: (_) => upd(() => m.reaction = e),
                        ),
                    ],
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Bintang'),
                    value: m.starred,
                    onChanged: (v) => upd(() => m.starred = v),
                  ),
                ],
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    OutlinedButton.icon(
                      onPressed: idx > 0
                          ? () => upd(() {
                                final t = pr.messages[idx];
                                pr.messages[idx] = pr.messages[idx - 1];
                                pr.messages[idx - 1] = t;
                              })
                          : null,
                      icon: const Icon(Icons.arrow_upward_rounded),
                      label: const Text('Naik'),
                    ),
                    OutlinedButton.icon(
                      onPressed: idx >= 0 && idx < pr.messages.length - 1
                          ? () => upd(() {
                                final t = pr.messages[idx];
                                pr.messages[idx] = pr.messages[idx + 1];
                                pr.messages[idx + 1] = t;
                              })
                          : null,
                      icon: const Icon(Icons.arrow_downward_rounded),
                      label: const Text('Turun'),
                    ),
                    if (!isDivider && m.type != MsgType.deleted)
                      OutlinedButton.icon(
                        onPressed: () {
                          m.type = MsgType.deleted;
                          _changed();
                          Navigator.pop(ctx);
                        },
                        icon: const Icon(Icons.block_rounded),
                        label: const Text('Jadikan dihapus'),
                      ),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFD32F2F),
                      ),
                      onPressed: () {
                        pr.messages.remove(m);
                        _changed();
                        Navigator.pop(ctx);
                      },
                      icon: const Icon(Icons.delete_rounded),
                      label: const Text('Hapus'),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
    textC.dispose();
  }

  // ------------------------------------------------------------------- build

  Widget _senderBar() {
    final pal = Palette(pr.dark);
    final entries = <MapEntry<String, String>>[
      const MapEntry(ChatProject.meId, 'Gue'),
      ...pr.members.map((m) => MapEntry(m.id, m.name)),
    ];
    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (final e in entries)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: GestureDetector(
                onTap: () => setState(() => sender = e.key),
                child: Glass(
                  radius: 18,
                  dark: pal.dark,
                  blur: 14,
                  child: Container(
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: sender == e.key ? pal.accent : Colors.transparent,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Text(
                      e.value,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: sender == e.key ? Colors.white : pal.ink,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (sender != ChatProject.meId && pr.member(sender) == null) {
      sender = ChatProject.meId;
    }
    final top = MediaQuery.of(context).padding.top;
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          Positioned.fill(
            child: ChatView(
              project: pr,
              playback: live,
              editable: true,
              scroll: scroll,
              textController: text,
              onTapMessage: _editMessage,
              onLongPressMessage: _contextMenu,
              onVoiceTap: live.toggle,
              onHeaderTap: () => showSettingsSheet(context, pr, _changed),
              onPlus: _showPlus,
              onCamera: _addPhotos,
              onMic: _record,
              onSendText: _sendText,
              senderBar: hideChrome ? null : _senderBar(),
              replyingTo: replyTo,
              onClearReply: () => setState(() => replyTo = null),
            ),
          ),
          if (!hideChrome)
            Positioned(
              right: 12,
              top: top + 6 + ChatView.headerH + 22,
              child: GlassCircle(
                icon: Icons.tune_rounded,
                dark: pr.dark,
                size: 40,
                onTap: _showTools,
              ),
            ),
          if (hideChrome)
            Positioned(
              left: 0,
              top: 0,
              width: 70,
              height: 50,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onDoubleTap: () => setState(() => hideChrome = false),
              ),
            ),
        ],
      ),
    );
  }
}

class _RecordDialog extends StatefulWidget {
  const _RecordDialog();

  @override
  State<_RecordDialog> createState() => _RecordDialogState();
}

class _RecordDialogState extends State<_RecordDialog> {
  final rec = AudioRecorder();
  int sec = 0;
  Timer? timer;
  String? error;
  String? path;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    if (!await rec.hasPermission()) {
      if (mounted) setState(() => error = 'Izin mikrofon ditolak');
      return;
    }
    path = p.join(Store.tempDir.path, 'rec_${newId()}.m4a');
    await rec.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: path!);
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => sec++);
    });
  }

  Future<void> _stop() async {
    timer?.cancel();
    final out = await rec.stop();
    if (mounted) Navigator.pop(context, out ?? path);
  }

  Future<void> _cancel() async {
    timer?.cancel();
    try {
      await rec.cancel();
    } catch (_) {}
    if (mounted) Navigator.pop(context, null);
  }

  @override
  void dispose() {
    timer?.cancel();
    rec.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: AlertDialog(
        title: const Text('Merekam voice note'),
        content: Row(
          children: [
            Icon(
              error == null ? Icons.fiber_manual_record : Icons.error_outline,
              color: Colors.red,
            ),
            const SizedBox(width: 10),
            Text(error ?? fmtDur(sec * 1000), style: const TextStyle(fontSize: 22)),
          ],
        ),
        actions: [
          TextButton(onPressed: _cancel, child: const Text('Batal')),
          if (error == null) FilledButton(onPressed: _stop, child: const Text('Selesai')),
        ],
      ),
    );
  }
}
