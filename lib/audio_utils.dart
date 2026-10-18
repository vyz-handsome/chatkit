import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:path/path.dart' as p;

import 'models.dart';
import 'store.dart';

class VoiceInfo {
  final String file;
  final int durationMs;
  final List<double> waveform;
  VoiceInfo(this.file, this.durationMs, this.waveform);
}

class AudioUtils {
  static const bars = 56;

  /// Ambil audio dari video/file audio, simpan sebagai .m4a, hitung durasi
  /// dan bentuk gelombang dari data audio aslinya.
  static Future<VoiceInfo> importAudio(String input) async {
    final id = newId();
    final name = '$id.m4a';
    final out = p.join(Store.mediaDir.path, name);
    final pcm = p.join(Store.tempDir.path, '$id.pcm');

    final s1 = await FFmpegKit.executeWithArguments([
      '-y', '-i', input, '-vn', '-ac', '1', '-c:a', 'aac', '-b:a', '96k', out,
    ]);
    if (!ReturnCode.isSuccess(await s1.getReturnCode())) {
      throw Exception('Gagal mengambil audio. Pastikan file punya suara.');
    }

    final s2 = await FFmpegKit.executeWithArguments([
      '-y', '-i', out, '-vn', '-ac', '1', '-ar', '8000', '-f', 's16le', pcm,
    ]);
    if (!ReturnCode.isSuccess(await s2.getReturnCode())) {
      throw Exception('Gagal membaca gelombang audio.');
    }

    final bytes = await File(pcm).readAsBytes();
    await File(pcm).delete();
    final n = bytes.length ~/ 2;
    if (n == 0) throw Exception('Audio kosong.');

    final bd = ByteData.sublistView(bytes);
    final durationMs = (n * 1000 / 8000).round();
    final peaks = List<double>.filled(bars, 0);
    for (int b = 0; b < bars; b++) {
      final s = n * b ~/ bars;
      final e = math.max(s + 1, n * (b + 1) ~/ bars);
      final step = math.max(1, (e - s) ~/ 200);
      double mx = 0;
      for (int i = s; i < e && i < n; i += step) {
        final v = bd.getInt16(i * 2, Endian.little).abs() / 32768.0;
        if (v > mx) mx = v;
      }
      peaks[b] = mx;
    }
    final top = peaks.reduce(math.max);
    final norm = top <= 0 ? 1.0 : top;
    final wave = peaks
        .map((v) => math.pow(v / norm, 0.7).toDouble().clamp(0.08, 1.0).toDouble())
        .toList();
    return VoiceInfo(name, durationMs, wave);
  }
}
