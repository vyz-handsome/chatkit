import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:gal/gal.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';

import '../media_utils.dart';
import '../models.dart';
import '../playback.dart';
import '../store.dart';
import '../widgets/chat_view.dart';

/// Export: gambar (PNG/JPG) untuk chat biasa, video (MP4) kalau ada voice note.
class ExportScreen extends StatefulWidget {
  const ExportScreen({super.key, required this.project});
  final ChatProject project;

  @override
  State<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends State<ExportScreen> {
  static const double _w = 390;
  static const double _h = 844;

  ChatProject get pr => widget.project;
  final key = GlobalKey();
  final pb = PlaybackState();

  int mode = 0; // 0 = gambar, 1 = video
  bool png = true;
  int quality = 1; // 0 = standar (2x), 1 = tinggi (3x)
  int fps = 20;
  late int limit = pr.messages.length;

  bool busy = false;
  double progress = 0;
  String status = '';
  String? resultPath;
  String? resultNote;

  List<ChatMessage> get visible => pr.messages.take(limit).toList();

  List<ChatMessage> get voices => visible
      .where((m) => m.type == MsgType.voice && m.media != null)
      .toList();

  @override
  void dispose() {
    pb.dispose();
    super.dispose();
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<Uint8List> _capture(double ratio) async {
    final boundary = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: ratio);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return data!.buffer.asUint8List();
  }

  Future<String?> _saveToGallery(String path, {required bool video}) async {
    try {
      if (!await Gal.hasAccess(toAlbum: true)) {
        await Gal.requestAccess(toAlbum: true);
      }
      if (video) {
        await Gal.putVideo(path, album: 'ChatKit');
      } else {
        await Gal.putImage(path, album: 'ChatKit');
      }
      return 'Tersimpan di galeri (album ChatKit).';
    } catch (_) {
      return 'Gagal simpan ke galeri. Pakai tombol Bagikan.';
    }
  }

  // ------------------------------------------------------------------ gambar

  Future<void> _exportImage() async {
    setState(() {
      busy = true;
      progress = 0;
      status = 'Membuat gambar...';
      resultPath = null;
    });
    try {
      pb.set(null, 0, false);
      await WidgetsBinding.instance.endOfFrame;
      var bytes = await _capture(quality == 0 ? 2.0 : 3.0);
      var ext = 'png';
      if (!png) {
        bytes = await compute(pngToJpg, bytes);
        ext = 'jpg';
      }
      final path = p.join(
        Store.tempDir.path,
        'chatkit_${DateTime.now().millisecondsSinceEpoch}.$ext',
      );
      await File(path).writeAsBytes(bytes);
      final note = await _saveToGallery(path, video: false);
      if (!mounted) return;
      setState(() {
        resultPath = path;
        resultNote = note;
      });
    } catch (e) {
      if (mounted) _snack('Gagal export: $e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  // ------------------------------------------------------------------- video

  List<String> _ffmpegArgs({
    required String framesDir,
    required List<ChatMessage> vs,
    required List<int> starts,
    required String out,
    required double totalSec,
    required bool x264,
  }) {
    final args = <String>[
      '-y',
      '-framerate', '$fps',
      '-i', p.join(framesDir, 'f_%05d.png'),
    ];
    for (final v in vs) {
      args..add('-i')..add(Store.resolve(v.media)!);
    }
    final filters = <String>[];
    for (int i = 0; i < vs.length; i++) {
      filters.add('[${i + 1}:a]adelay=${starts[i]}:all=1[a$i]');
    }
    if (vs.length == 1) {
      filters.add('[a0]anull[aout]');
    } else {
      final ins = List.generate(vs.length, (i) => '[a$i]').join();
      filters.add('${ins}amix=inputs=${vs.length}:duration=longest:normalize=0[aout]');
    }
    args.addAll([
      '-filter_complex', filters.join(';'),
      '-map', '0:v',
      '-map', '[aout]',
      ...(x264
          ? ['-c:v', 'libx264', '-preset', 'veryfast', '-crf', '20']
          : ['-c:v', 'mpeg4', '-q:v', '3']),
      '-pix_fmt', 'yuv420p',
      '-r', '$fps',
      '-c:a', 'aac',
      '-b:a', '128k',
      '-t', totalSec.toStringAsFixed(2),
      '-movflags', '+faststart',
      out,
    ]);
    return args;
  }

  Future<void> _exportVideo() async {
    final vs = voices;
    if (vs.isEmpty) {
      _snack('Belum ada voice note. Pakai export gambar.');
      return;
    }
    setState(() {
      busy = true;
      progress = 0;
      status = 'Merender frame...';
      resultPath = null;
    });
    final ts = DateTime.now().millisecondsSinceEpoch;
    final dir = Directory(p.join(Store.tempDir.path, 'frames_$ts'))
      ..createSync(recursive: true);
    try {
      const lead = 800, gap = 600, tail = 1000;
      final starts = <int>[];
      int t = lead;
      for (final v in vs) {
        starts.add(t);
        t += v.durationMs + gap;
      }
      final totalMs = t - gap + tail;
      final frames = (totalMs / 1000 * fps).ceil();
      final ratio = quality == 0 ? 2.0 : 3.0;

      for (int f = 0; f < frames; f++) {
        if (!mounted) return;
        final ms = (f * 1000 / fps).round();
        String? active;
        int pos = 0;
        for (int i = 0; i < vs.length; i++) {
          if (ms >= starts[i] && ms < starts[i] + vs[i].durationMs) {
            active = vs[i].id;
            pos = ms - starts[i];
            break;
          }
        }
        pb.set(active, pos, active != null);
        await WidgetsBinding.instance.endOfFrame;
        final bytes = await _capture(ratio);
        await File(p.join(dir.path, 'f_${f.toString().padLeft(5, '0')}.png'))
            .writeAsBytes(bytes);
        if (f % 3 == 0 && mounted) setState(() => progress = f / frames * 0.9);
      }
      pb.set(null, 0, false);

      if (mounted) {
        setState(() {
          status = 'Menggabungkan video dan audio...';
          progress = 0.92;
        });
      }
      final out = p.join(Store.tempDir.path, 'chatkit_$ts.mp4');
      final totalSec = totalMs / 1000;
      var session = await FFmpegKit.executeWithArguments(_ffmpegArgs(
        framesDir: dir.path,
        vs: vs,
        starts: starts,
        out: out,
        totalSec: totalSec,
        x264: true,
      ));
      if (!ReturnCode.isSuccess(await session.getReturnCode())) {
        session = await FFmpegKit.executeWithArguments(_ffmpegArgs(
          framesDir: dir.path,
          vs: vs,
          starts: starts,
          out: out,
          totalSec: totalSec,
          x264: false,
        ));
        if (!ReturnCode.isSuccess(await session.getReturnCode())) {
          throw Exception('Gagal membuat video');
        }
      }
      final note = await _saveToGallery(out, video: true);
      if (!mounted) return;
      setState(() {
        resultPath = out;
        resultNote = note;
        progress = 1;
      });
    } catch (e) {
      if (mounted) _snack('Gagal export: $e');
    } finally {
      try {
        dir.deleteSync(recursive: true);
      } catch (_) {}
      pb.set(null, 0, false);
      if (mounted) setState(() => busy = false);
    }
  }

  // ------------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final len = pr.messages.length;
    final mq = MediaQuery.of(context);
    return PopScope(
      canPop: !busy,
      child: Scaffold(
        appBar: AppBar(title: const Text('Export')),
        body: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Center(
                  child: AspectRatio(
                    aspectRatio: _w / _h,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: FittedBox(
                        fit: BoxFit.contain,
                        child: SizedBox(
                          width: _w,
                          height: _h,
                          child: RepaintBoundary(
                            key: key,
                            child: MediaQuery(
                              data: mq.copyWith(
                                size: const Size(_w, _h),
                                padding: const EdgeInsets.only(top: 30, bottom: 20),
                                viewPadding: const EdgeInsets.only(top: 30, bottom: 20),
                                viewInsets: EdgeInsets.zero,
                                textScaler: TextScaler.noScaling,
                              ),
                              child: ChatView(
                                project: pr,
                                playback: pb,
                                messages: visible,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SegmentedButton<int>(
                      segments: const [
                        ButtonSegment(
                          value: 0,
                          icon: Icon(Icons.image_rounded),
                          label: Text('Gambar'),
                        ),
                        ButtonSegment(
                          value: 1,
                          icon: Icon(Icons.movie_rounded),
                          label: Text('Video + audio'),
                        ),
                      ],
                      selected: {mode},
                      onSelectionChanged:
                          busy ? null : (s) => setState(() => mode = s.first),
                    ),
                    if (len > 1) ...[
                      const SizedBox(height: 6),
                      Text('Tampilkan sampai pesan ke-$limit dari $len'),
                      Slider(
                        value: limit.clamp(1, len).toDouble(),
                        min: 1,
                        max: len.toDouble(),
                        divisions: len - 1,
                        onChanged: busy
                            ? null
                            : (v) => setState(() => limit = v.round()),
                      ),
                    ],
                    Wrap(
                      spacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        ChoiceChip(
                          label: const Text('Kualitas standar'),
                          selected: quality == 0,
                          onSelected:
                              busy ? null : (_) => setState(() => quality = 0),
                        ),
                        ChoiceChip(
                          label: const Text('Kualitas tinggi'),
                          selected: quality == 1,
                          onSelected:
                              busy ? null : (_) => setState(() => quality = 1),
                        ),
                        if (mode == 0) ...[
                          ChoiceChip(
                            label: const Text('PNG'),
                            selected: png,
                            onSelected: busy ? null : (_) => setState(() => png = true),
                          ),
                          ChoiceChip(
                            label: const Text('JPG'),
                            selected: !png,
                            onSelected: busy ? null : (_) => setState(() => png = false),
                          ),
                        ] else
                          for (final f in const [15, 20, 30])
                            ChoiceChip(
                              label: Text('$f fps'),
                              selected: fps == f,
                              onSelected: busy ? null : (_) => setState(() => fps = f),
                            ),
                      ],
                    ),
                    if (mode == 1)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          voices.isEmpty
                              ? 'Belum ada voice note di chat ini.'
                              : '${voices.length} voice note diputar berurutan, durasi video mengikuti audio.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    const SizedBox(height: 10),
                    if (busy) ...[
                      Text(status),
                      const SizedBox(height: 6),
                      LinearProgressIndicator(
                        value: status.startsWith('Merender') ? progress : null,
                      ),
                    ] else
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: mode == 0 ? _exportImage : _exportVideo,
                          icon: const Icon(Icons.download_rounded),
                          label: Text(mode == 0 ? 'Export gambar' : 'Export video'),
                        ),
                      ),
                    if (resultPath != null && !busy) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(child: Text(resultNote ?? 'Selesai.')),
                          TextButton.icon(
                            onPressed: () => Share.shareXFiles([XFile(resultPath!)]),
                            icon: const Icon(Icons.ios_share_rounded),
                            label: const Text('Bagikan'),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
