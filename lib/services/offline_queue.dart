import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Queues messages sent while offline and replays them when the network returns.
class OfflineMessageQueue {
  OfflineMessageQueue._();
  static final OfflineMessageQueue instance = OfflineMessageQueue._();

  static const _key = 'offline_message_queue';
  bool _processing = false;

  Future<List<Map<String, dynamic>>> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  Future<void> _save(List<Map<String, dynamic>> queue) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(queue));
  }

  Future<int> length() async {
    final queue = await _load();
    return queue.length;
  }

  Future<void> enqueue(Map<String, dynamic> message) async {
    final queue = await _load();
    message['_queued_at'] = DateTime.now().toIso8601String();
    queue.add(message);
    await _save(queue);
  }

  /// Attempt to drain the queue. Caller provides a function to send each message.
  Future<int> drain(Future<bool> Function(Map<String, dynamic> msg) sender) async {
    if (_processing) return 0;
    _processing = true;
    try {
      final queue = await _load();
      if (queue.isEmpty) return 0;

      final remaining = <Map<String, dynamic>>[];
      int sent = 0;
      for (final msg in queue) {
        try {
          final ok = await sender(msg);
          if (ok) {
            sent++;
          } else {
            remaining.add(msg);
          }
        } catch (_) {
          remaining.add(msg);
        }
      }
      await _save(remaining);
      return sent;
    } finally {
      _processing = false;
    }
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
