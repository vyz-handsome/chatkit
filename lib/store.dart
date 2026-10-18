import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'models.dart';

/// Penyimpanan proyek (JSON) dan media (foto, audio, stiker) di folder app.
class Store {
  static late Directory root;
  static late Directory projectsDir;
  static late Directory mediaDir;
  static late Directory tempDir;

  static Future<void> init() async {
    final docs = await getApplicationDocumentsDirectory();
    root = Directory(p.join(docs.path, 'chatkit'));
    projectsDir = Directory(p.join(root.path, 'projects'));
    mediaDir = Directory(p.join(root.path, 'media'));
    tempDir = Directory(p.join((await getTemporaryDirectory()).path, 'chatkit'));
    for (final d in [projectsDir, mediaDir, tempDir]) {
      await d.create(recursive: true);
    }
  }

  static Future<List<ChatProject>> loadAll() async {
    final list = <ChatProject>[];
    await for (final e in projectsDir.list()) {
      if (e is File && e.path.endsWith('.json')) {
        try {
          final data = jsonDecode(await e.readAsString()) as Map<String, dynamic>;
          list.add(ChatProject.fromJson(data));
        } catch (_) {
          // File rusak dilewati.
        }
      }
    }
    list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return list;
  }

  static Future<void> save(ChatProject pr) async {
    pr.updatedAt = DateTime.now().millisecondsSinceEpoch;
    final f = File(p.join(projectsDir.path, '${pr.id}.json'));
    await f.writeAsString(jsonEncode(pr.toJson()));
  }

  static Future<void> delete(String id) async {
    final f = File(p.join(projectsDir.path, '$id.json'));
    if (await f.exists()) await f.delete();
  }

  /// Nama file media -> path absolut.
  static String? resolve(String? name) =>
      name == null ? null : p.join(mediaDir.path, name);

  /// Salin file ke folder media, kembalikan nama file barunya.
  static Future<String> importFile(String src, {String? ext}) async {
    final e = ext ?? p.extension(src);
    final name = '${newId()}$e';
    await File(src).copy(p.join(mediaDir.path, name));
    return name;
  }
}
