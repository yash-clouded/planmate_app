import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/agent_response_card.dart';
import '../widgets/poll_card.dart';
import '../services/backend_service.dart';
import '../services/offline_queue.dart';
import 'chat_list_screen.dart';

class GroupChatScreen extends StatefulWidget {
  const GroupChatScreen({super.key});

  @override
  State<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen> {
  final _msgController = TextEditingController();
  final _scrollController = ScrollController();
  bool _showMentionDropdown = false;
  final List<_ChatMessage> _messages = [];
  DateTime? _lastAgentTime;

  GroupData? _group;
  List<_ChatMember> _members = [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is GroupData && _group == null) {
      _group = args;
      _members = [
        if (args.autoAddAgent) _ChatMember(name: 'PlanMate Agent', isAgent: true),
        ...args.memberNames.map((n) => _ChatMember(name: n)),
      ];
      // Start with system messages
      _messages.add(_ChatMessage(
        text: 'Group "${args.name}" created by You',
        type: _MsgType.system,
      ));
      if (args.autoAddAgent) {
        _messages.add(_ChatMessage(
          text: 'PlanMate Agent joined the group',
          type: _MsgType.system,
        ));
      }
      _loadPolls();
      _drainOfflineQueue();
    }
  }

  Future<void> _drainOfflineQueue() async {
    final count = await OfflineMessageQueue.instance.drain((msg) async {
      final channelId = msg['channel_id'] as String?;
      if (channelId == null || _group == null) return true;
      if (channelId != 'messaging:${_group!.name}') return true;
      try {
        await BackendService.instance.sendAgentCommand(
          channelId: channelId,
          command: msg['command'] as String? ?? 'chat',
          text: msg['text'] as String? ?? '',
        );
        return true;
      } catch (_) {
        return false;
      }
    });
    if (count > 0 && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Synced $count offline message${count != 1 ? "s" : ""}')),
      );
    }
  }

  Future<void> _loadPolls() async {
    if (_group == null) return;
    try {
      final channelId = 'messaging:${_group!.name}';
      final result = await BackendService.instance.getPolls(channelId);
      final polls = result['polls'] as List<dynamic>? ?? [];
      for (final poll in polls) {
        final options = (poll['options'] as List<dynamic>?)?.cast<String>() ?? ['Yes', 'No'];
        setState(() {
          _messages.add(_ChatMessage(
            text: '',
            type: _MsgType.agent,
            time: _now(),
            agentSummary: 'Poll: ${poll['question'] ?? ''}',
            agentDescription: 'Vote now!',
            agentActionType: 'poll',
            agentToolResults: [{
              'tool': 'create_poll',
              'params': {
                'question': poll['question'] ?? 'Group poll',
                'options': options,
                'duration_minutes': poll['duration_minutes'] ?? 60,
              }
            }],
            isPoll: true,
            pollId: poll['poll_id']?.toString(),
          ));
        });
      }
    } catch (e) {
      debugPrint('Failed to load polls: $e');
    }
  }

  @override
  void dispose() {
    _msgController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final text = _msgController.text.trim();
    if (text.isEmpty) return;

    final lowerText = text.toLowerCase();
    final now = DateTime.now();

    // Frontend rate limit: prevent rapid agent calls
    if (_lastAgentTime != null && now.difference(_lastAgentTime!) < const Duration(seconds: 5)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please wait a few seconds before mentioning the agent again'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Check for direct commands
    String? command;
    if (lowerText == 'poll' || lowerText.startsWith('poll ') || lowerText.startsWith('create poll')) {
      command = 'poll';
    } else if (lowerText == 'summarize' || lowerText.startsWith('summarize ')) {
      command = 'summarize';
    } else if (lowerText.startsWith('restaurants ') || lowerText.startsWith('restaurant ')) {
      command = 'restaurants';
    }

    // Add user message to chat
    setState(() {
      _messages.add(_ChatMessage(
        text: text,
        type: _MsgType.user,
        time: _now(),
      ));
    });
    _msgController.clear();

    // Handle agent interaction
    final isAgentMention = lowerText.contains('@agent') || lowerText.contains('@planmate');
    if (command != null || isAgentMention) {
      _lastAgentTime = now;
      _handleAgentResponse(text, command: command);
    }

    // Scroll to bottom
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _handleAgentResponse(String userMessage, {String? command}) async {
    // Show processing indicator
    setState(() {
      _messages.add(_ChatMessage(
        text: '',
        type: _MsgType.agent,
        time: _now(),
        agentSummary: 'Processing...',
        agentDescription: 'Let me look into that for the group.',
      ));
    });

    try {
      final channelId = 'messaging:${_group!.name}';
      final result = await BackendService.instance.sendAgentCommand(
        channelId: channelId,
        command: command ?? 'chat',
        text: userMessage,
      );

      // Remove the processing message
      setState(() {
        if (_messages.isNotEmpty && _messages.last.agentSummary == 'Processing...') {
          _messages.removeLast();
        }
      });

      // Add actual response
      final actionType = result['action_type'] ?? 'info_only';
      final isPoll = actionType == 'poll';
      final toolResults = result['tool_results'] as List<dynamic>? ?? [];
      final pollId = result['poll_id'] as String?;

      setState(() {
        _messages.add(_ChatMessage(
          text: '',
          type: _MsgType.agent,
          time: _now(),
          agentSummary: result['summary'] ?? '',
          agentDescription: result['description'] ?? '',
          agentActionType: actionType,
          agentToolResults: toolResults,
          isPoll: isPoll,
          pollId: pollId,
        ));
      });
    } catch (e) {
      setState(() {
        if (_messages.isNotEmpty && _messages.last.agentSummary == 'Processing...') {
          _messages.removeLast();
        }
        _messages.add(_ChatMessage(
          text: '',
          type: _MsgType.agent,
          time: _now(),
          agentSummary: 'Sorry, I had trouble processing that.',
          agentDescription: e.toString().substring(0, 200),
        ));
      });
      // Queue for retry if it looks like a network error
      if (e.toString().contains('SocketException') ||
          e.toString().contains('TimeoutException') ||
          e.toString().contains('ClientException')) {
        await OfflineMessageQueue.instance.enqueue({
          'channel_id': 'messaging:${_group!.name}',
          'command': command ?? 'chat',
          'text': userMessage,
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Offline — will sync when connection returns'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _now() {
    final now = DateTime.now();
    final h = now.hour > 12 ? now.hour - 12 : now.hour;
    final m = now.minute.toString().padLeft(2, '0');
    final ampm = now.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $ampm';
  }

  @override
  Widget build(BuildContext context) {
    final groupName = _group?.name ?? 'Group Chat';
    final memberCount = _members.where((m) => !m.isAgent).length + 1; // +1 for current user

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        elevation: 0,
        leadingWidth: 40,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.group, color: AppTheme.primary, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          groupName,
                          style: AppTheme.titleMedium.copyWith(fontSize: 15),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (_group?.autoAddAgent == true) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.agentBubbleDark,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.smart_toy_rounded, size: 10, color: Colors.white),
                              SizedBox(width: 3),
                              Text('Agent', style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              )),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                  Text(
                    '$memberCount member${memberCount != 1 ? 's' : ''}',
                    style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert, size: 22),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                _buildMessageList(),
                if (_showMentionDropdown) _buildMentionDropdown(),
              ],
            ),
          ),
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    if (_messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 64,
              color: AppTheme.textHint.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'Start a conversation',
              style: AppTheme.bodyLarge.copyWith(color: AppTheme.textHint),
            ),
            const SizedBox(height: 8),
            Text(
              'Type a message or @agent to get suggestions',
              style: AppTheme.bodySmall.copyWith(color: AppTheme.textHint),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(vertical: 12),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final msg = _messages[index];
        if (msg.type == _MsgType.system) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: _buildSystemMessage(msg.text),
          );
        } else if (msg.type == _MsgType.user) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 4, left: 60),
            child: ChatBubble(
              text: msg.text,
              time: msg.time ?? '',
              type: BubbleType.user,
            ),
          );
        } else if (msg.type == _MsgType.otherUser) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 4, right: 60),
            child: ChatBubble(
              text: msg.text,
              senderName: msg.senderName ?? '',
              time: msg.time ?? '',
              type: BubbleType.otherUser,
              showSenderName: true,
            ),
          );
        } else if (msg.type == _MsgType.agent) {
          if (msg.isPoll && msg.agentToolResults != null && msg.agentToolResults!.isNotEmpty) {
            final pollCall = msg.agentToolResults!.firstWhere(
              (tr) => tr['tool'] == 'create_poll',
              orElse: () => {'params': {'question': 'Group poll', 'options': ['Yes', 'No']}},
            );
            final params = pollCall['params'] as Map<String, dynamic>? ?? {};
            final options = (params['options'] as List<dynamic>?)?.cast<String>() ?? ['Yes', 'No'];
            return Padding(
              padding: const EdgeInsets.only(bottom: 4, left: 8, right: 8),
              child: PollCard(
                question: params['question']?.toString() ?? 'Group poll',
                options: options.map((o) => PollOption(label: o)).toList(),
                totalVotes: 0,
                showResult: false,
                onVote: (index) async {
                  try {
                    final channelId = 'messaging:${_group!.name}';
                    await BackendService.instance.castPollVote(
                      channelId: channelId,
                      pollId: msg.pollId ?? '',
                      optionIndex: index,
                    );
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Vote cast!')),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Vote failed: $e')),
                      );
                    }
                  }
                },
              ),
            );
          }
          return Padding(
            padding: const EdgeInsets.only(bottom: 4, left: 8, right: 8),
            child: AgentResponseCard(
              summary: msg.agentSummary ?? '',
              description: msg.agentDescription ?? '',
              timestamp: msg.time ?? '',
              showPinned: false,
            ),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildSystemMessage(String text) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: AppTheme.borderLight,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          text,
          style: AppTheme.bodySmall.copyWith(fontSize: 11),
        ),
      ),
    );
  }

  Widget _buildMentionDropdown() {
    return Positioned(
      bottom: 0,
      left: 12,
      right: 12,
      child: Container(
        margin: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 12,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Agent option
            if (_group?.autoAddAgent == true)
              ListTile(
                dense: true,
                leading: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppTheme.agentBubbleDark,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.smart_toy_rounded, size: 18, color: Colors.white),
                ),
                title: const Text('PlanMate Agent', style: AppTheme.labelLarge),
                subtitle: const Text('AI assistant for this group', style: AppTheme.bodySmall),
                onTap: () {
                  _msgController.text = '@PlanMate Agent ';
                  setState(() => _showMentionDropdown = false);
                },
              ),
            if (_group?.autoAddAgent == true) const Divider(height: 1),
            // Member options
            ..._members.where((m) => !m.isAgent).map((m) => ListTile(
                  dense: true,
                  leading: CircleAvatar(
                    radius: 16,
                    backgroundColor: AppTheme.primary.withOpacity(0.1),
                    child: Text(
                      m.name[0].toUpperCase(),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primary,
                      ),
                    ),
                  ),
                  title: Text(m.name, style: AppTheme.labelLarge),
                  onTap: () {
                    _msgController.text = '@${m.name} ';
                    setState(() => _showMentionDropdown = false);
                  },
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        12,
        8,
        12,
        MediaQuery.of(context).padding.bottom + 8,
      ),
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(top: BorderSide(color: AppTheme.borderLight)),
      ),
      child: Row(
        children: [
          // Text field
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.background,
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: _msgController,
                textCapitalization: TextCapitalization.sentences,
                style: AppTheme.bodyMedium,
                onChanged: (val) {
                  final show = val.isNotEmpty && val.endsWith('@');
                  if (show != _showMentionDropdown) {
                    setState(() => _showMentionDropdown = show);
                  }
                },
                decoration: InputDecoration(
                  hintText: 'Message...',
                  hintStyle: AppTheme.bodyMedium.copyWith(color: AppTheme.textHint),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  prefixIcon: const Icon(
                    Icons.add_circle_outline,
                    color: AppTheme.textHint,
                    size: 22,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Mic
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: AppTheme.background,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.mic_none_rounded,
              color: AppTheme.textSecondary,
              size: 22,
            ),
          ),
          const SizedBox(width: 6),
          // Send
          GestureDetector(
            onTap: _sendMessage,
            child: Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: AppTheme.primary,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.send_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatMember {
  final String name;
  final bool isAgent;
  const _ChatMember({required this.name, this.isAgent = false});
}

enum _MsgType { system, user, otherUser, agent }

class _ChatMessage {
  final String text;
  final _MsgType type;
  final String? time;
  final String? senderName;
  final String? agentSummary;
  final String? agentDescription;
  final String? agentActionType;
  final List<dynamic>? agentToolResults;
  final bool isPoll;
  final String? pollId;

  const _ChatMessage({
    required this.text,
    required this.type,
    this.time,
    this.senderName,
    this.agentSummary,
    this.agentDescription,
    this.agentActionType,
    this.agentToolResults,
    this.isPoll = false,
    this.pollId,
  });
}
