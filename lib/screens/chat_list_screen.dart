import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';

/// Simple persistent group store — uses shared_preferences so groups survive app restarts.
class GroupStore {
  static final GroupStore instance = GroupStore._();
  GroupStore._();

  static const _storageKey = 'planmate_groups';
  final List<GroupData> groups = [];
  bool _loaded = false;

  Future<void> load() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_storageKey);
    if (jsonString != null) {
      try {
        final List<dynamic> list = jsonDecode(jsonString);
        groups.clear();
        groups.addAll(list.map((g) => GroupData(
          name: g['name'] as String,
          imagePath: g['imagePath'] as String?,
          memberNames: List<String>.from(g['memberNames'] ?? []),
          autoAddAgent: g['autoAddAgent'] as bool? ?? true,
          creatorName: g['creatorName'] as String? ?? 'You',
        )).toList());
      } catch (e) {
        debugPrint('Failed to load groups: $e');
      }
    }
    _loaded = true;
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(groups.map((g) => {
      'name': g.name,
      'imagePath': g.imagePath,
      'memberNames': g.memberNames,
      'autoAddAgent': g.autoAddAgent,
      'creatorName': g.creatorName,
    }).toList());
    await prefs.setString(_storageKey, jsonString);
  }

  void addGroup(GroupData group) {
    groups.insert(0, group);
    _save();
  }
}

class GroupData {
  final String name;
  final String? imagePath;
  final List<String> memberNames;
  final bool autoAddAgent;
  final String creatorName;

  const GroupData({
    required this.name,
    this.imagePath,
    required this.memberNames,
    required this.autoAddAgent,
    required this.creatorName,
  });
}

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  @override
  void initState() {
    super.initState();
    GroupStore.instance.load();
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
      body: _buildBody(),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.of(context).pushNamed('/create-group');
          if (mounted) setState(() {}); // refresh list after creating group
        },
        backgroundColor: AppTheme.primary,
        elevation: 4,
        child: const Icon(Icons.add, color: Colors.white, size: 28),
      ),
    );
  }

  Widget _buildBody() {
    final groups = GroupStore.instance.groups;

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
      onTap: () {
        Navigator.of(context).pushNamed(
          '/group-chat',
          arguments: group,
        );
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
