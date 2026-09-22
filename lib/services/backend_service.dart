import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'api_config.dart';

/// Calls the PlanMate FastAPI backend for booking, payment, and agent actions.
class BackendService {
  BackendService._();
  static final instance = BackendService._();

  final _base = ApiConfig.backendUrl;
  static const _timeout = Duration(seconds: 20);

  // The backend runs on a free tier that cold-starts (~30-60s) after idle, and
  // the agent/itinerary endpoints also wait on an LLM call. Give those a longer
  // budget so the very first request after a cold start doesn't time out.
  static const _longTimeout = Duration(seconds: 60);

  bool _warmedUp = false;

  /// Best-effort ping to wake a cold-started backend. Safe to call repeatedly;
  /// only the first call does real work. Never throws.
  Future<void> warmUp() async {
    if (_warmedUp) return;
    try {
      final resp = await http
          .get(Uri.parse('$_base/health'))
          .timeout(_longTimeout);
      if (resp.statusCode == 200) _warmedUp = true;
    } catch (_) {
      // Server still waking or unreachable — callers will retry on demand.
    }
  }

  /// Confirm a pending booking for a group.
  Future<Map<String, dynamic>> confirmBooking(String channelId) async {
    final resp = await http.post(
      Uri.parse('$_base/webhooks/confirm/$channelId'),
      headers: {'Content-Type': 'application/json'},
    ).timeout(_timeout);
    if (resp.statusCode != 200) {
      throw Exception('Confirm booking failed: ${resp.body}');
    }
    return jsonDecode(resp.body);
  }

  /// Fetch health status of the backend.
  Future<Map<String, dynamic>> healthCheck() async {
    final resp = await http.get(Uri.parse('$_base/health')).timeout(const Duration(seconds: 15));
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
    ).timeout(_timeout);
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
    ).timeout(_timeout);
  }

  /// Send a direct agent command (poll, summarize, restaurants, or general chat).
  Future<Map<String, dynamic>> sendAgentCommand({
    required String channelId,
    required String command,
    required String text,
  }) async {
    final resp = await http.post(
      Uri.parse('$_base/webhooks/agent/command'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'channel_id': channelId,
        'command': command,
        'text': text,
      }),
    ).timeout(_longTimeout);
    if (resp.statusCode != 200) {
      throw Exception('Agent command failed: ${resp.statusCode} ${resp.body}');
    }
    return jsonDecode(resp.body);
  }

  /// Fetch all polls for a channel.
  Future<Map<String, dynamic>> getPolls(String channelId) async {
    final resp = await http.get(
      Uri.parse('$_base/webhooks/polls/$channelId'),
    ).timeout(_timeout);
    if (resp.statusCode != 200) {
      throw Exception('Failed to fetch polls: ${resp.body}');
    }
    return jsonDecode(resp.body);
  }

  /// Upload an image to the backend.
  Future<Map<String, dynamic>> uploadImage(String filePath) async {
    final file = File(filePath);
    if (!file.existsSync()) {
      throw Exception('File not found');
    }
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$_base/webhooks/upload/image'),
    );
    request.files.add(await http.MultipartFile.fromPath('file', filePath));
    final streamed = await request.send().timeout(_timeout);
    final resp = await http.Response.fromStream(streamed);
    if (resp.statusCode != 200) {
      throw Exception('Upload failed: ${resp.body}');
    }
    return jsonDecode(resp.body);
  }

  /// Generate a trip itinerary based on group conversation.
  Future<Map<String, dynamic>> generateItinerary({
    required String channelId,
    int days = 3,
  }) async {
    final resp = await http.post(
      Uri.parse('$_base/webhooks/itinerary/generate'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'channel_id': channelId, 'days': days}),
    ).timeout(_longTimeout);
    if (resp.statusCode != 200) {
      throw Exception('Itinerary generation failed: ${resp.body}');
    }
    return jsonDecode(resp.body);
  }
}
