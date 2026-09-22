import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:stream_chat_flutter/stream_chat_flutter.dart';
import 'package:stream_chat_persistence/stream_chat_persistence.dart';
import 'api_config.dart';

/// Wraps the Stream Chat client lifecycle.
class StreamChatService {
  StreamChatService._();
  static final instance = StreamChatService._();

  late final StreamChatClient client;

  /// Initialize the Stream Chat client.
  Future<void> init() async {
    final chatPersistentClient = StreamChatPersistenceClient(
      logLevel: Level.SEVERE,
      connectionMode: ConnectionMode.regular,
    );

    client = StreamChatClient(
      ApiConfig.streamApiKey,
      logLevel: Level.INFO,
    );

    // Set the persistent client on the chat client
    client.chatPersistenceClient = chatPersistentClient;
  }

  /// Fetch a real Stream connection token from the backend for [userId].
  ///
  /// The backend upserts the Stream user and signs a JWT with the API secret.
  /// Falls back to a dev token only if the backend is unreachable, so the app
  /// still works in local/dev setups where Stream auth is disabled.
  Future<String> _fetchToken({required String userId, required String name}) async {
    try {
      final resp = await http
          .post(
            Uri.parse('${ApiConfig.backendUrl}/stream/token'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'user_id': userId, 'name': name}),
          )
          .timeout(const Duration(seconds: 30));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final token = data['token'] as String?;
        if (token != null && token.isNotEmpty) return token;
      }
    } catch (_) {
      // Fall through to dev token below.
    }
    return client.devToken(userId).rawValue;
  }

  /// Connect a user to Stream Chat, minting a token from the backend.
  Future<void> connectUser({
    required String userId,
    required String name,
    String? token,
  }) async {
    // Already connected as this user? No-op.
    if (client.state.currentUser?.id == userId) return;

    final authToken = token ?? await _fetchToken(userId: userId, name: name);

    await client.connectUser(
      User(id: userId, name: name),
      authToken,
    );
  }

  /// Disconnect the current user.
  Future<void> disconnectUser() async {
    await client.disconnectUser();
  }

  /// Get or create a group channel with the AI agent auto-added.
  ///
  /// [groupId] must be a valid Stream channel id (see GroupData.generateChannelId).
  /// Only real Stream user ids are added as members (the creator + the agent);
  /// invited contacts are kept as display metadata in [invitedNames] until a
  /// real invite→uid mapping exists.
  Future<Channel> getOrCreateGroup({
    required String groupId,
    required String groupName,
    required String creatorId,
    bool addAgent = true,
    List<String> invitedNames = const [],
  }) async {
    final members = [
      creatorId,
      if (addAgent) 'planmate-agent',
    ];

    // watchChannel creates the channel on first call and passes members correctly.
    await client.watchChannel(
      'messaging',
      channelId: groupId,
      channelData: {
        'name': groupName,
        'created_by_id': creatorId,
        'invited_names': invitedNames,
        'members': members,
      },
    );

    return client.channel('messaging', id: groupId);
  }

  /// Send a text message to a channel.
  Future<void> sendMessage({
    required String channelId,
    required String text,
  }) async {
    final channel = client.channel('messaging', id: channelId);
    final message = Message(text: text);
    await channel.sendMessage(message);
  }

  /// Send an @agent mention.
  Future<void> sendAgentMention({
    required String channelId,
    required String message,
  }) async {
    await sendMessage(
      channelId: channelId,
      text: '@agent $message',
    );
  }

  /// Get the list of channels the current user is a member of (streaming).
  Stream<List<Channel>> getUserChannels() {
    final userId = client.state.currentUser!.id;
    return client.queryChannels(
      filter: Filter.in_('members', [userId]),
      channelStateSort: [SortOption.desc('last_message_at')],
    );
  }

  /// Get channels once (non-streaming).
  Future<List<Channel>> getUserChannelsOnce() async {
    final userId = client.state.currentUser!.id;
    return client.queryChannelsOnline(
      filter: Filter.in_('members', [userId]),
      sort: [SortOption.desc('last_message_at')],
      paginationParams: const PaginationParams(limit: 30),
    );
  }

  /// Mark a channel as read.
  Future<void> markChannelRead(String channelId) async {
    final channel = client.channel('messaging', id: channelId);
    await channel.markRead();
  }

  /// Listen for new messages on a channel.
  Stream<Event> onMessageReceived(String channelId) {
    final channel = client.channel('messaging', id: channelId);
    return channel.on('message.new');
  }

  /// Get unread message count for a channel.
  int getUnreadCount(String channelId) {
    final channel = client.state.channels['messaging:$channelId'];
    return channel?.state?.unreadCount ?? 0;
  }
}
