import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import 'models.dart';
import 'store.dart';

/// Status pemutaran voice note yang dibaca oleh bubble.
/// Dipakai langsung saat export (diatur frame demi frame).
class PlaybackState extends ChangeNotifier {
  String? activeId;
  int positionMs = 0;
  bool playing = false;

  void set(String? id, int pos, bool isPlaying) {
    activeId = id;
    positionMs = pos;
    playing = isPlaying;
    notifyListeners();
  }
}

/// Pemutar audio sungguhan untuk editor/preview.
class LivePlayback extends PlaybackState {
  final AudioPlayer _player = AudioPlayer();

  LivePlayback() {
    _player.onPositionChanged.listen((d) {
      positionMs = d.inMilliseconds;
      notifyListeners();
    });
    _player.onPlayerComplete.listen((_) {
      playing = false;
      positionMs = 0;
      notifyListeners();
    });
  }

  Future<void> toggle(ChatMessage m) async {
    if (m.media == null) return;
    if (activeId == m.id && playing) {
      await _player.pause();
      playing = false;
      notifyListeners();
      return;
    }
    if (activeId == m.id && positionMs > 0) {
      await _player.resume();
      playing = true;
      notifyListeners();
      return;
    }
    await _player.stop();
    activeId = m.id;
    positionMs = 0;
    playing = true;
    notifyListeners();
    await _player.play(DeviceFileSource(Store.resolve(m.media)!));
  }

  Future<void> stop() async {
    await _player.stop();
    playing = false;
    positionMs = 0;
    notifyListeners();
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }
}
