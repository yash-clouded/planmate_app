import 'package:stream_chat_flutter/stream_chat_flutter.dart';
import 'api_config.dart';

/// Wraps the Stream Chat client lifecycle.
class StreamChatService {
  StreamChatService._();
  static final instance = StreamChatService._();

  late final StreamChatClient client;

  /// Initialize the Stream Chat client.
  void init() {
    client = StreamChatClient(
      ApiConfig.streamApiKey,
      logLevel: Level.INFO,
    );
  }

  /// Connect a user to Stream Chat.
  Future<void> connectUser({
    required String userId,
    required String name,
    String? token,
  }) async {
    final devToken = token ?? client.devToken(userId).rawValue;

    await client.connectUser(
      User(id: userId, name: name),
      devToken,
    );
  }

  /// Disconnect the current user.
  Future<void> disconnectUser() async {
    await client.disconnectUser();
  }

  /// Get or create a group channel with the AI agent auto-added.
  Future<Channel> getOrCreateGroup({
    required String groupId,
    required String groupName,
    required String creatorId,
    List<String> memberIds = const [],
  }) async {
    final allMembers = [
      creatorId,
      'planmate-agent',
      ...memberIds,
    ];

    final channel = client.channel(
      'messaging',
      id: groupId,
      extraData: {
        'name': groupName,
        'created_by_id': creatorId,
        'members': allMembers,
      },
    );

    await channel.create();
    await channel.watch();

    return channel;
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
      channelStateSort: [SortOption('last_message_at')],
    );
  }

  /// Get channels once (non-streaming).
  Future<List<Channel>> getUserChannelsOnce() async {
    final userId = client.state.currentUser!.id;
    return client.queryChannelsOnline(
      filter: Filter.in_('members', [userId]),
      sort: [SortOption('last_message_at')],
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
