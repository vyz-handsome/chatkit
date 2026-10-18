import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/glass.dart';

Future<String?> _pickImageFile() async {
  final x = await ImagePicker().pickImage(source: ImageSource.gallery);
  if (x == null) return null;
  return Store.importFile(x.path);
}

// ---------------------------------------------------------------- Pengaturan

Future<void> showSettingsSheet(
  BuildContext context,
  ChatProject pr,
  VoidCallback changed,
) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (ctx) => _SettingsSheet(pr: pr, changed: changed),
  );
}

class _SettingsSheet extends StatefulWidget {
  const _SettingsSheet({required this.pr, required this.changed});
  final ChatProject pr;
  final VoidCallback changed;

  @override
  State<_SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<_SettingsSheet> {
  ChatProject get pr => widget.pr;
  late final title = TextEditingController(text: pr.title);
  late final custom = TextEditingController(text: pr.customStatus);
  late final unread = TextEditingController(text: pr.unread.toString());

  void _upd(VoidCallback fn) {
    setState(fn);
    widget.changed();
  }

  @override
  void dispose() {
    title.dispose();
    custom.dispose();
    unread.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final f = await _pickImageFile();
    if (f != null) _upd(() => pr.avatar = f);
  }

  Future<void> _editMember(Member? existing) async {
    final nameC = TextEditingController(text: existing?.name ?? '');
    int color = existing?.color ?? memberColors[pr.members.length % memberColors.length];
    String? avatar = existing?.avatar;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text(existing == null ? 'Tambah anggota' : 'Ubah anggota'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameC,
                decoration: const InputDecoration(labelText: 'Nama'),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  for (final c in memberColors)
                    GestureDetector(
                      onTap: () => setD(() => color = c),
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: Color(c),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: color == c ? Colors.black : Colors.transparent,
                            width: 2.5,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Avatar(
                    file: avatar,
                    name: nameC.text,
                    color: Color(color),
                    size: 40,
                  ),
                  const SizedBox(width: 12),
                  TextButton(
                    onPressed: () async {
                      final f = await _pickImageFile();
                      if (f != null) setD(() => avatar = f);
                    },
                    child: const Text('Foto'),
                  ),
                  if (avatar != null)
                    TextButton(
                      onPressed: () => setD(() => avatar = null),
                      child: const Text('Hapus'),
                    ),
                ],
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
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    final name = nameC.text.trim().isEmpty ? 'Anggota' : nameC.text.trim();
    _upd(() {
      if (existing == null) {
        pr.members.add(
          Member(id: newId(), name: name, color: color, avatar: avatar),
        );
      } else {
        existing.name = name;
        existing.color = color;
        existing.avatar = avatar;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: [
          Text('Pengaturan chat', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 14),
          TextField(
            controller: title,
            decoration: InputDecoration(
              labelText: pr.isGroup ? 'Nama grup' : 'Nama kontak',
              border: const OutlineInputBorder(),
            ),
            onChanged: (v) {
              pr.title = v;
              if (!pr.isGroup && pr.members.isNotEmpty) pr.members.first.name = v;
              widget.changed();
            },
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Avatar(
                file: pr.avatar,
                name: pr.title,
                color: const Color(0xFF2F9BFF),
                size: 52,
              ),
              const SizedBox(width: 14),
              FilledButton.tonal(
                onPressed: _pickAvatar,
                child: const Text('Pilih foto profil'),
              ),
              const SizedBox(width: 8),
              if (pr.avatar != null)
                TextButton(
                  onPressed: () => _upd(() => pr.avatar = null),
                  child: const Text('Hapus'),
                ),
            ],
          ),
          const SizedBox(height: 18),
          Text('Status di header', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Online'),
                selected: pr.presence == Presence.online,
                onSelected: (_) => _upd(() => pr.presence = Presence.online),
              ),
              ChoiceChip(
                label: const Text('Mengetik...'),
                selected: pr.presence == Presence.typing,
                onSelected: (_) => _upd(() => pr.presence = Presence.typing),
              ),
              ChoiceChip(
                label: const Text('Teks sendiri'),
                selected: pr.presence == Presence.custom,
                onSelected: (_) => _upd(() => pr.presence = Presence.custom),
              ),
            ],
          ),
          if (pr.presence == Presence.custom) ...[
            const SizedBox(height: 10),
            TextField(
              controller: custom,
              decoration: const InputDecoration(
                labelText: 'Teks status (kosong = otomatis)',
                border: OutlineInputBorder(),
              ),
              onChanged: (v) {
                pr.customStatus = v;
                widget.changed();
              },
            ),
          ],
          const SizedBox(height: 14),
          TextField(
            controller: unread,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Angka badge di samping tombol kembali (0 = sembunyi)',
              border: OutlineInputBorder(),
            ),
            onChanged: (v) {
              pr.unread = int.tryParse(v) ?? 0;
              widget.changed();
            },
          ),
          const SizedBox(height: 6),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Chat grup'),
            value: pr.isGroup,
            onChanged: (v) => _upd(() => pr.isGroup = v),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Format jam 24 jam'),
            value: pr.use24h,
            onChanged: (v) => _upd(() => pr.use24h = v),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Mode gelap'),
            value: pr.dark,
            onChanged: (v) => _upd(() => pr.dark = v),
          ),
          const Divider(),
          Row(
            children: [
              Text(
                pr.isGroup ? 'Anggota grup' : 'Lawan chat',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const Spacer(),
              if (pr.isGroup)
                TextButton.icon(
                  onPressed: () => _editMember(null),
                  icon: const Icon(Icons.person_add_alt_1_rounded),
                  label: const Text('Tambah'),
                ),
            ],
          ),
          for (final m in List<Member>.of(pr.members))
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Avatar(
                file: m.avatar,
                name: m.name,
                color: Color(m.color),
                size: 38,
              ),
              title: Text(m.name),
              onTap: () => _editMember(m),
              trailing: pr.isGroup && pr.members.length > 1
                  ? IconButton(
                      icon: const Icon(Icons.delete_outline_rounded),
                      onPressed: () => _upd(() => pr.members.remove(m)),
                    )
                  : null,
            ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------ Latar belakang

Future<void> showBackgroundSheet(
  BuildContext context,
  ChatProject pr,
  VoidCallback changed,
) {
  return showModalBottomSheet(
    context: context,
    showDragHandle: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setS) {
        void upd(VoidCallback fn) {
          setS(fn);
          changed();
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Latar belakang', style: Theme.of(ctx).textTheme.titleLarge),
              const SizedBox(height: 14),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (int i = 0; i < wallPresets.length; i++)
                    GestureDetector(
                      onTap: () => upd(() {
                        pr.bgPreset = i;
                        pr.bgFile = null;
                      }),
                      child: Column(
                        children: [
                          Container(
                            width: 64,
                            height: 96,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: pr.dark
                                    ? wallPresets[i].dark
                                    : wallPresets[i].light,
                              ),
                              border: Border.all(
                                width: 2.5,
                                color: pr.bgFile == null && pr.bgPreset == i
                                    ? const Color(0xFF30B84A)
                                    : Colors.black12,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(wallPresets[i].name,
                              style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  FilledButton.icon(
                    onPressed: () async {
                      final f = await _pickImageFile();
                      if (f != null) upd(() => pr.bgFile = f);
                    },
                    icon: const Icon(Icons.photo_library_rounded),
                    label: const Text('Import dari galeri'),
                  ),
                  const SizedBox(width: 8),
                  if (pr.bgFile != null)
                    TextButton(
                      onPressed: () => upd(() => pr.bgFile = null),
                      child: const Text('Hapus gambar'),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    ),
  );
}
