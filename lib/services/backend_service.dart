import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_config.dart';

/// Calls the PlanMate FastAPI backend for booking, payment, and agent actions.
class BackendService {
  BackendService._();
  static final instance = BackendService._();

  final _base = ApiConfig.backendUrl;

  /// Confirm a pending booking for a group.
  Future<Map<String, dynamic>> confirmBooking(String channelId) async {
    final resp = await http.post(
      Uri.parse('$_base/webhooks/confirm/$channelId'),
      headers: {'Content-Type': 'application/json'},
    );
    if (resp.statusCode != 200) {
      throw Exception('Confirm booking failed: ${resp.body}');
    }
    return jsonDecode(resp.body);
  }

  /// Fetch health status of the backend.
  Future<Map<String, dynamic>> healthCheck() async {
    final resp = await http.get(Uri.parse('$_base/health'));
    return jsonDecode(resp.body);
  }

  /// Cast a vote in a poll.
  Future<Map<String, dynamic>> castPollVote({
    required String channelId,
    required String pollId,
    required int optionIndex,
  }) async {
    final resp = await http.post(
      Uri.parse('$_base/webhooks/poll/vote'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'channel_id': channelId,
        'poll_id': pollId,
        'option_index': optionIndex,
      }),
    );
    if (resp.statusCode != 200) {
      throw Exception('Vote failed: ${resp.body}');
    }
    return jsonDecode(resp.body);
  }

  /// Send an SOS alert.
  Future<void> sendSosAlert({
    required String channelId,
    required String userId,
    required String userName,
    required double latitude,
    required double longitude,
  }) async {
    await http.post(
      Uri.parse('$_base/webhooks/sos'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'channel_id': channelId,
        'user_id': userId,
        'user_name': userName,
        'latitude': latitude,
        'longitude': longitude,
      }),
    );
  }

  /// Send a direct agent command (poll, summarize, restaurants, or general chat).
  Future<Map<String, dynamic>> sendAgentCommand({
    required String channelId,
    required String command,
    required String text,
  }) async {
    final resp = await http.post(
      Uri.parse('$_base/agent/command'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'channel_id': channelId,
        'command': command,
        'text': text,
      }),
    );
    if (resp.statusCode != 200) {
      throw Exception('Agent command failed: ${resp.body}');
    }
    return jsonDecode(resp.body);
  }
}
