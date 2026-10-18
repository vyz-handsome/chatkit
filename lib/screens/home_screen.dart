import 'dart:convert';

import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';
import 'editor_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<ChatProject> projects = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await Store.loadAll();
    if (!mounted) return;
    setState(() {
      projects = list;
      loading = false;
    });
  }

  Future<void> _open(ChatProject pr) async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => EditorScreen(project: pr)),
    );
    _load();
  }

  Future<void> _create() async {
    final nameC = TextEditingController();
    bool group = false;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('Proyek baru'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameC,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Nama proyek'),
              ),
              const SizedBox(height: 14),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('Pribadi')),
                  ButtonSegment(value: true, label: Text('Grup')),
                ],
                selected: {group},
                onSelectionChanged: (s) => setD(() => group = s.first),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Buat'),
            ),
          ],
        ),
      ),
    );
    final name = nameC.text.trim().isEmpty ? 'Proyek baru' : nameC.text.trim();
    nameC.dispose();
    if (ok != true) return;
    final pr = ChatProject.create(name, group: group);
    await Store.save(pr);
    if (mounted) await _open(pr);
  }

  Future<void> _duplicate(ChatProject pr) async {
    final copy = ChatProject.fromJson(
      jsonDecode(jsonEncode(pr.toJson())) as Map<String, dynamic>,
    )
      ..id = newId()
      ..name = '${pr.name} (salinan)';
    await Store.save(copy);
    _load();
  }

  Future<void> _delete(ChatProject pr) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Hapus "${pr.name}"?'),
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
      await Store.delete(pr.id);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ChatKit')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _create,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Proyek baru'),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : projects.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Text(
                      'Belum ada proyek.\nBuat proyek baru untuk mulai bikin chat simulasi.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
                  itemCount: projects.length,
                  itemBuilder: (context, i) {
                    final pr = projects[i];
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: const Color(0xFF30B84A),
                          child: Icon(
                            pr.isGroup ? Icons.groups_rounded : Icons.person_rounded,
                            color: Colors.white,
                          ),
                        ),
                        title: Text(pr.name),
                        subtitle: Text(
                          '${pr.title} · ${pr.messages.where((m) => m.type != MsgType.divider).length} pesan',
                        ),
                        onTap: () => _open(pr),
                        trailing: PopupMenuButton<String>(
                          onSelected: (v) {
                            if (v == 'dup') _duplicate(pr);
                            if (v == 'del') _delete(pr);
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(value: 'dup', child: Text('Duplikat')),
                            PopupMenuItem(value: 'del', child: Text('Hapus')),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
