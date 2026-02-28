import 'dart:async';
import 'dart:collection';
import '../../audio/audio_playback_engine.dart';

enum SpeechPriority { p0, p1, p2 }

class _SpeechEntry {
  final String text;
  final SpeechPriority priority;
  final DateTime enqueuedAt;

  _SpeechEntry(this.text, this.priority) : enqueuedAt = DateTime.now();

  bool get isStale =>
      DateTime.now().difference(enqueuedAt).inMilliseconds > 3000;
}

class SpeechQueue {
  final AudioPlaybackEngine _engine;
  final Queue<_SpeechEntry> _queue = Queue<_SpeechEntry>();
  bool _isProcessing = false;

  static const Duration _gapBetweenUtterances = Duration(milliseconds: 300);

  SpeechQueue(this._engine);

  /// Enqueue speech with the given priority.
  /// P0: clears queue, stops engine, plays immediately.
  /// P1: queues behind current speech.
  /// P2: queues but dropped if >3s stale when dequeued.
  void enqueue(String text, SpeechPriority priority) {
    if (text.trim().isEmpty) return;

    if (priority == SpeechPriority.p0) {
      _queue.clear();
      _engine.stop();
      _isProcessing = false;
      _queue.addFirst(_SpeechEntry(text, priority));
      _processQueue();
      return;
    }

    _queue.addLast(_SpeechEntry(text, priority));
    _processQueue();
  }

  Future<void> _processQueue() async {
    if (_isProcessing) return;
    _isProcessing = true;

    while (_queue.isNotEmpty) {
      final entry = _queue.removeFirst();

      // Drop stale P2 entries
      if (entry.priority == SpeechPriority.p2 && entry.isStale) {
        continue;
      }

      await _engine.speakAndWait(entry.text);

      // Gap between consecutive utterances
      if (_queue.isNotEmpty) {
        await Future.delayed(_gapBetweenUtterances);
      }
    }

    _isProcessing = false;
  }

  void clear() {
    _queue.clear();
    _engine.stop();
    _isProcessing = false;
  }

  void dispose() {
    clear();
  }
}
