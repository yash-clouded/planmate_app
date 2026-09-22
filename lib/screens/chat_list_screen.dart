import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';
import '../services/stream_service.dart';

/// Simple persistent group store — uses shared_preferences so groups survive app restarts.
class GroupStore {
  static final GroupStore instance = GroupStore._();
  GroupStore._();

  static const _storageKey = 'planmate_groups';
  final List<GroupData> groups = [];
  bool _loaded = false;

  Future<void> load() async {
    if (_loaded) return;
    // Mark loaded immediately so addGroup() during the async gap can't race
    // with a second load() that would groups.clear() in-memory entries.
    _loaded = true;
    await _mergeFromDisk();
  }

  /// Re-read persisted groups — call when returning to the home screen.
  Future<void> reloadFromDisk() async {
    await _mergeFromDisk(replace: true);
  }

  Future<void> _mergeFromDisk({bool replace = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_storageKey);
    if (jsonString == null) return;
    try {
      final List<dynamic> list = jsonDecode(jsonString);
      final fromDisk = list.map((g) => GroupData(
        channelId: g['channelId'] as String? ?? GroupData.generateChannelId(g['name'] as String? ?? 'group'),
        name: g['name'] as String,
        imagePath: g['imagePath'] as String?,
        memberNames: List<String>.from(g['memberNames'] ?? []),
        autoAddAgent: g['autoAddAgent'] as bool? ?? true,
        creatorName: g['creatorName'] as String? ?? 'You',
      )).toList();

      if (replace || groups.isEmpty) {
        groups
          ..clear()
          ..addAll(fromDisk);
      } else {
        for (final g in fromDisk) {
          if (!hasChannel(g.channelId)) groups.add(g);
        }
      }
    } catch (e) {
      debugPrint('Failed to load groups: $e');
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(groups.map((g) => {
      'channelId': g.channelId,
      'name': g.name,
      'imagePath': g.imagePath,
      'memberNames': g.memberNames,
      'autoAddAgent': g.autoAddAgent,
      'creatorName': g.creatorName,
    }).toList());
    await prefs.setString(_storageKey, jsonString);
  }

  Future<void> addGroup(GroupData group) async {
    if (hasChannel(group.channelId)) return;
    groups.insert(0, group);
    await _save();
  }

  /// True if a group with this channel id is already stored.
  bool hasChannel(String channelId) =>
      groups.any((g) => g.channelId == channelId);
}

class GroupData {
  final String channelId;
  final String name;
  final String? imagePath;
  final List<String> memberNames;
  final bool autoAddAgent;
  final String creatorName;

  const GroupData({
    required this.channelId,
    required this.name,
    this.imagePath,
    required this.memberNames,
    required this.autoAddAgent,
    required this.creatorName,
  });

  /// Build a Stream-safe channel id from a display name.
  ///
  /// Stream channel ids must match `[a-z0-9_-]` and be <= 64 chars, so we
  /// slugify the name and append a short unique suffix to avoid collisions.
  static String generateChannelId(String name) {
    final slug = name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    final base = slug.isEmpty ? 'group' : slug;
    final suffix = DateTime.now().millisecondsSinceEpoch.toRadixString(36);
    final id = '$base-$suffix';
    if (id.length <= 64) return id;
    // Keep the slug prefix + as much of the suffix as fits.
    final maxSuffix = 64 - base.length - 1; // -1 for the dash
    return maxSuffix > 0 ? '$base-${suffix.substring(suffix.length - maxSuffix)}' : id.substring(0, 64);
  }
}

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> with RouteAware {
  bool _isLoadingChannels = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute<void>) {
      appRouteObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    appRouteObserver.unsubscribe(this);
    super.dispose();
  }

  /// Fired when the user pops back to this screen (e.g. from group chat).
  @override
  void didPopNext() {
    _onScreenVisible();
  }

  Future<void> _onScreenVisible() async {
    await GroupStore.instance.reloadFromDisk();
    if (mounted) setState(() {});
  }

  /// Load stored groups, connect to Stream, then sync server channels — in order.
  Future<void> _init() async {
    await GroupStore.instance.load();
    if (mounted) setState(() {});
    await _connectStreamUser();
    await _refreshStreamChannels();
  }

  Future<void> _connectStreamUser() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final user = authService.currentUser;
    if (user == null) return;
    final name = user.displayName ?? user.phoneNumber ?? 'User';
    try {
      await StreamChatService.instance.connectUser(
        userId: user.uid,
        name: name,
      );
    } catch (e) {
      debugPrint('Stream connect failed: $e');
    }
  }

  Future<void> _refreshStreamChannels() async {
    if (_isLoadingChannels) return;
    // Can't query channels until a user is connected.
    if (StreamChatService.instance.client.state.currentUser == null) return;
    setState(() => _isLoadingChannels = true);
    try {
      final channels = await StreamChatService.instance.getUserChannelsOnce();
      for (final channel in channels) {
        final channelId = channel.id;
        if (channelId == null) continue;
        // Skip channels we already track locally (dedupe by channel id).
        if (GroupStore.instance.hasChannel(channelId)) continue;

        final name = channel.extraData['name']?.toString() ?? channelId;
        final invited = (channel.extraData['invited_names'] as List?)?.cast<String>() ?? [];
        final memberIds = channel.state?.members
                .map((m) => m.userId)
                .whereType<String>()
                .toList() ??
            [];

        await GroupStore.instance.addGroup(GroupData(
          channelId: channelId,
          name: name,
          memberNames: invited,
          autoAddAgent: memberIds.contains('planmate-agent'),
          creatorName: 'You',
        ));
      }
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Failed to load Stream channels: $e');
    } finally {
      if (mounted) setState(() => _isLoadingChannels = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.menu_rounded, size: 26),
          onPressed: () {
            Navigator.of(context).pushNamed('/settings');
          },
        ),
        title: const Text('Your Groups'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined, size: 24),
            onPressed: () {},
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshStreamChannels,
        child: _buildBody(),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.of(context).pushNamed('/create-group');
          if (mounted) {
            await GroupStore.instance.reloadFromDisk();
            setState(() {});
            _refreshStreamChannels();
          }
        },
        backgroundColor: AppTheme.primary,
        elevation: 4,
        child: const Icon(Icons.add, color: Colors.white, size: 28),
      ),
    );
  }

  Widget _buildBody() {
    final groups = GroupStore.instance.groups;

    if (_isLoadingChannels && groups.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (groups.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: groups.length,
      separatorBuilder: (_, __) => const Divider(
        height: 1,
        indent: 76,
        endIndent: 0,
        color: AppTheme.borderLight,
      ),
      itemBuilder: (context, index) {
        final g = groups[index];
        return _buildGroupTile(context, g);
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.groups_outlined,
                size: 48,
                color: AppTheme.primary,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'No groups yet',
              style: AppTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Create a group to start planning trips,\ndinners, and outings with friends.',
              textAlign: TextAlign.center,
              style: AppTheme.bodyMedium.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).pushNamed('/create-group');
              },
              icon: const Icon(Icons.add, size: 20),
              label: const Text('Create Your First Group'),
              style: AppTheme.primaryButtonStyle,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupTile(BuildContext context, GroupData group) {
    // Pick icon based on name keywords
    final icon = _iconForGroup(group.name);
    final color = _colorForGroup(group.name);

    return InkWell(
      onTap: () async {
        await Navigator.of(context).pushNamed(
          '/group-chat',
          arguments: group,
        );
        if (context.mounted) {
          await GroupStore.instance.reloadFromDisk();
          setState(() {});
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        color: AppTheme.surface,
        child: Row(
          children: [
            // Group avatar
            Stack(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                if (group.autoAddAgent)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: AppTheme.agentBubbleDark,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppTheme.surface, width: 2),
                      ),
                      child: const Icon(
                        Icons.smart_toy_rounded,
                        size: 10,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            // Group info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    group.name,
                    style: AppTheme.titleMedium.copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${group.memberNames.length + 1} members${group.autoAddAgent ? ' • Agent' : ''}',
                    style: AppTheme.bodySmall.copyWith(fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconForGroup(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('trip') || lower.contains('travel') || lower.contains('beach') || lower.contains('mountain')) {
      return Icons.landscape;
    } else if (lower.contains('movie') || lower.contains('film')) {
      return Icons.movie;
    } else if (lower.contains('dinner') || lower.contains('food') || lower.contains('lunch') || lower.contains('eat')) {
      return Icons.restaurant;
    } else if (lower.contains('reunion') || lower.contains('college') || lower.contains('school')) {
      return Icons.school;
    } else if (lower.contains('party') || lower.contains('birthday')) {
      return Icons.celebration;
    } else if (lower.contains('sports') || lower.contains('cricket') || lower.contains('football')) {
      return Icons.sports_soccer;
    }
    return Icons.group;
  }

  Color _colorForGroup(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('trip') || lower.contains('travel')) return AppTheme.primary;
    if (lower.contains('movie')) return AppTheme.accent;
    if (lower.contains('dinner') || lower.contains('food')) return AppTheme.warning;
    if (lower.contains('reunion')) return AppTheme.error;
    if (lower.contains('party')) return AppTheme.primaryLight;
    return AppTheme.primary;
  }
}
