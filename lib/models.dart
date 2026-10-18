import 'dart:math';

int _idCounter = 0;

String newId() {
  _idCounter++;
  return '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}'
      '${_idCounter.toRadixString(36)}'
      '${Random().nextInt(46656).toRadixString(36)}';
}

enum MsgType { text, image, sticker, voice, deleted, divider }

enum MsgStatus { sent, delivered, read }

enum Presence { online, typing, custom }

T _byName<T extends Enum>(List<T> values, Object? name, T fallback) {
  for (final v in values) {
    if (v.name == name) return v;
  }
  return fallback;
}

class Member {
  String id;
  String name;
  int color;
  String? avatar;

  Member({
    required this.id,
    required this.name,
    required this.color,
    this.avatar,
  });

  Map<String, dynamic> toJson() =>
      {'id': id, 'name': name, 'color': color, 'avatar': avatar};

  factory Member.fromJson(Map<String, dynamic> j) => Member(
        id: j['id'] as String,
        name: j['name'] as String? ?? 'Kontak',
        color: j['color'] as int? ?? 0xFF2F9BFF,
        avatar: j['avatar'] as String?,
      );
}

class ChatMessage {
  String id;
  String senderId;
  MsgType type;
  String text;
  String? media;
  double aspect;
  int durationMs;
  List<double> waveform;
  int minutes;
  MsgStatus status;
  String? replyToId;
  String? reaction;
  bool starred;

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.type,
    this.text = '',
    this.media,
    this.aspect = 1,
    this.durationMs = 0,
    this.waveform = const <double>[],
    required this.minutes,
    this.status = MsgStatus.read,
    this.replyToId,
    this.reaction,
    this.starred = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'senderId': senderId,
        'type': type.name,
        'text': text,
        'media': media,
        'aspect': aspect,
        'durationMs': durationMs,
        'waveform': waveform.map((e) => double.parse(e.toStringAsFixed(3))).toList(),
        'minutes': minutes,
        'status': status.name,
        'replyToId': replyToId,
        'reaction': reaction,
        'starred': starred,
      };

  factory ChatMessage.fromJson(Map<String, dynamic> j) => ChatMessage(
        id: j['id'] as String,
        senderId: j['senderId'] as String? ?? ChatProject.meId,
        type: _byName(MsgType.values, j['type'], MsgType.text),
        text: j['text'] as String? ?? '',
        media: j['media'] as String?,
        aspect: (j['aspect'] as num?)?.toDouble() ?? 1,
        durationMs: j['durationMs'] as int? ?? 0,
        waveform: ((j['waveform'] as List?) ?? const [])
            .map((e) => (e as num).toDouble())
            .toList(),
        minutes: j['minutes'] as int? ?? 0,
        status: _byName(MsgStatus.values, j['status'], MsgStatus.read),
        replyToId: j['replyToId'] as String?,
        reaction: j['reaction'] as String?,
        starred: j['starred'] as bool? ?? false,
      );
}

class ChatProject {
  static const meId = 'me';

  String id;
  String name;
  bool isGroup;
  String title;
  String? avatar;
  Presence presence;
  String customStatus;
  int unread;
  int bgPreset;
  String? bgFile;
  bool dark;
  bool use24h;
  List<Member> members;
  List<ChatMessage> messages;
  int updatedAt;

  ChatProject({
    required this.id,
    required this.name,
    required this.isGroup,
    required this.title,
    this.avatar,
    this.presence = Presence.online,
    this.customStatus = '',
    this.unread = 0,
    this.bgPreset = 0,
    this.bgFile,
    this.dark = false,
    this.use24h = true,
    required this.members,
    required this.messages,
    required this.updatedAt,
  });

  factory ChatProject.create(String name, {required bool group}) {
    final members = group
        ? [
            Member(id: newId(), name: 'Anggota 1', color: 0xFF2F9BFF),
            Member(id: newId(), name: 'Anggota 2', color: 0xFFFF9F0A),
            Member(id: newId(), name: 'Anggota 3', color: 0xFFBF5AF2),
          ]
        : [Member(id: newId(), name: 'Nama Kontak', color: 0xFF2F9BFF)];
    return ChatProject(
      id: newId(),
      name: name,
      isGroup: group,
      title: group ? name : 'Nama Kontak',
      presence: group ? Presence.custom : Presence.online,
      members: members,
      messages: [],
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
  }

  Member? member(String id) {
    for (final m in members) {
      if (m.id == id) return m;
    }
    return null;
  }

  String nameOf(String id) =>
      id == meId ? 'Anda' : (member(id)?.name ?? members.first.name);

  String get statusText {
    switch (presence) {
      case Presence.online:
        return 'online';
      case Presence.typing:
        return isGroup && members.isNotEmpty
            ? '${members.first.name} sedang mengetik...'
            : 'mengetik...';
      case Presence.custom:
        if (customStatus.trim().isNotEmpty) return customStatus;
        return isGroup ? [...members.map((m) => m.name), 'Anda'].join(', ') : '';
    }
  }

  ChatMessage? messageById(String? id) {
    if (id == null) return null;
    for (final m in messages) {
      if (m.id == id) return m;
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'isGroup': isGroup,
        'title': title,
        'avatar': avatar,
        'presence': presence.name,
        'customStatus': customStatus,
        'unread': unread,
        'bgPreset': bgPreset,
        'bgFile': bgFile,
        'dark': dark,
        'use24h': use24h,
        'members': members.map((e) => e.toJson()).toList(),
        'messages': messages.map((e) => e.toJson()).toList(),
        'updatedAt': updatedAt,
      };

  factory ChatProject.fromJson(Map<String, dynamic> j) => ChatProject(
        id: j['id'] as String,
        name: j['name'] as String? ?? 'Proyek',
        isGroup: j['isGroup'] as bool? ?? false,
        title: j['title'] as String? ?? 'Kontak',
        avatar: j['avatar'] as String?,
        presence: _byName(Presence.values, j['presence'], Presence.online),
        customStatus: j['customStatus'] as String? ?? '',
        unread: j['unread'] as int? ?? 0,
        bgPreset: j['bgPreset'] as int? ?? 0,
        bgFile: j['bgFile'] as String?,
        dark: j['dark'] as bool? ?? false,
        use24h: j['use24h'] as bool? ?? true,
        members: ((j['members'] as List?) ?? const [])
            .map((e) => Member.fromJson(e as Map<String, dynamic>))
            .toList(),
        messages: ((j['messages'] as List?) ?? const [])
            .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
            .toList(),
        updatedAt: j['updatedAt'] as int? ?? 0,
      );
}
