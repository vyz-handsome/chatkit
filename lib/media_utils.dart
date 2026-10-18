import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// Rasio lebar/tinggi gambar (untuk ukuran bubble foto).
Future<double> imageAspect(String path) async {
  final bytes = await File(path).readAsBytes();
  final codec = await ui.instantiateImageCodec(bytes);
  final frame = await codec.getNextFrame();
  final aspect = frame.image.width / frame.image.height;
  frame.image.dispose();
  codec.dispose();
  return aspect;
}

/// Ubah foto jadi stiker: kotak 512x512 transparan dengan sudut membulat.
Future<String> makeSticker(String srcPath, String outPath) =>
    compute(_stickerJob, <String>[srcPath, outPath]);

String _stickerJob(List<String> a) {
  final decoded = img.decodeImage(File(a[0]).readAsBytesSync());
  if (decoded == null) throw Exception('Gambar tidak bisa dibaca');
  var im = decoded.convert(numChannels: 4);
  im = img.copyResize(
    im,
    width: 512,
    height: 512,
    maintainAspect: true,
    backgroundColor: img.ColorRgba8(0, 0, 0, 0),
    interpolation: img.Interpolation.average,
  );
  const r = 70;
  const last = 511;
  for (int x = 0; x < r; x++) {
    for (int y = 0; y < r; y++) {
      final dx = r - x - 0.5;
      final dy = r - y - 0.5;
      if (dx * dx + dy * dy > r * r) {
        im.getPixel(x, y).a = 0;
        im.getPixel(last - x, y).a = 0;
        im.getPixel(x, last - y).a = 0;
        im.getPixel(last - x, last - y).a = 0;
      }
    }
  }
  File(a[1]).writeAsBytesSync(img.encodePng(im));
  return a[1];
}

/// PNG -> JPG (kualitas tinggi) untuk export gambar.
Uint8List pngToJpg(Uint8List png) {
  final im = img.decodePng(png);
  if (im == null) throw Exception('Gagal mengubah ke JPG');
  return Uint8List.fromList(img.encodeJpg(im, quality: 95));
}
