import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart' hide PollOption;
import '../theme/app_theme.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/agent_response_card.dart';
import '../widgets/poll_card.dart';
import '../services/backend_service.dart';
import '../services/offline_queue.dart';
import '../services/stream_service.dart';
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
  final Set<String> _seenMessageIds = {};

  GroupData? _group;
  List<_ChatMember> _members = [];
  Channel? _streamChannel;
  StreamSubscription<Event>? _messageSubscription;
  bool _isStreamReady = false;

  /// ID of the "Processing..." placeholder shown while waiting for @agent webhook response.
  String? _agentProcessingId;

  /// The Stream channel cid the backend keys everything by, e.g. "messaging:goa-trip-abc".
  String get _channelCid => 'messaging:${_group!.channelId}';

  /// Remove a placeholder/message by its stable id, wherever it is in the list.
  ///
  /// Placeholders ("Processing…", "Building itinerary…") must be removed by id,
  /// not "if it's the last message" — incoming Stream events can append after
  /// them and otherwise strand them on screen forever.
  void _removeMessageById(String id) {
    _messages.removeWhere((m) => m.id == id);
  }

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
      _setupStreamChannel();
    }
  }

  Future<void> _drainOfflineQueue() async {
    final count = await OfflineMessageQueue.instance.drain((msg) async {
      final channelId = msg['channel_id'] as String?;
      if (channelId == null || _group == null) return true;
      if (channelId != _channelCid) return true;
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
      final channelId = _channelCid;
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

  Future<void> _setupStreamChannel() async {
    if (_group == null) return;
    try {
      final firebaseUser = FirebaseAuth.instance.currentUser;
      if (firebaseUser != null &&
          StreamChatService.instance.client.state.currentUser?.id != firebaseUser.uid) {
        await StreamChatService.instance.connectUser(
          userId: firebaseUser.uid,
          name: firebaseUser.displayName ?? firebaseUser.phoneNumber ?? 'User',
        );
      }

      final currentUserId = StreamChatService.instance.client.state.currentUser?.id;
      if (currentUserId == null) {
        throw StateError('Stream user not connected');
      }

      final invitedNames = _members.where((m) => !m.isAgent).map((m) => m.name).toList();
      _streamChannel = await StreamChatService.instance.getOrCreateGroup(
        groupId: _group!.channelId,
        groupName: _group!.name,
        creatorId: currentUserId,
        addAgent: _group!.autoAddAgent,
        invitedNames: invitedNames,
      );

      // Load existing messages
      final existing = await _streamChannel!.query(
        messagesPagination: const PaginationParams(limit: 50),
      );
      final messages = existing.messages ?? <Message>[];
      final sorted = [...messages]..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      for (final m in sorted) {
        if (_seenMessageIds.contains(m.id)) continue;
        _seenMessageIds.add(m.id);
        final chatMsg = _streamMessageToLocal(m);
        if (chatMsg != null) {
          setState(() => _messages.add(chatMsg));
        }
      }

      // Listen for new messages
      _messageSubscription = _streamChannel!.on('message.new').listen((event) {
        final message = event.message;
        if (message == null) return;

        // Skip our own messages — they are already rendered optimistically.
        final currentUserId = StreamChatService.instance.client.state.currentUser?.id ?? '';
        if (message.user?.id == currentUserId) return;

        if (_seenMessageIds.contains(message.id)) return;
        _seenMessageIds.add(message.id);
        final chatMsg = _streamMessageToLocal(message);
        if (chatMsg != null && mounted) {
          // If this is an agent response and we have a processing placeholder, remove it.
          if (message.user?.id == 'planmate-agent' && _agentProcessingId != null) {
            setState(() {
              _removeMessageById(_agentProcessingId!);
              _agentProcessingId = null;
              _messages.add(chatMsg);
            });
          } else {
            setState(() => _messages.add(chatMsg));
          }
        }
      });

      setState(() => _isStreamReady = true);
    } catch (e) {
      debugPrint('Stream channel setup failed: $e');
      setState(() => _isStreamReady = false);
    }
  }

  _ChatMessage? _streamMessageToLocal(Message message) {
    final text = message.text ?? '';
    final userId = message.user?.id ?? '';
    final currentUserId = StreamChatService.instance.client.state.currentUser?.id ?? '';

    if (text.isEmpty) return null;

    if (userId == 'planmate-agent') {
      // Check for rich card data from the webhook (planmate_card custom field).
      final cardData = message.extraData['planmate_card'] as Map<String, dynamic>?;
      final cardType = cardData?['card_type'] as String?;

      if (cardType == 'poll') {
        final options = (cardData!['options'] as List<dynamic>?)?.cast<String>() ?? ['Yes', 'No'];
        return _ChatMessage(
          text: text,
          type: _MsgType.agent,
          time: _formatStreamTime(message.createdAt),
          agentSummary: cardData['question']?.toString() ?? 'Group poll',
          agentDescription: 'Vote now!',
          agentActionType: 'poll',
          agentToolResults: [{
            'tool': 'create_poll',
            'params': {
              'question': cardData['question'] ?? 'Group poll',
              'options': options,
              'duration_minutes': cardData['duration_minutes'] ?? 60,
            }
          }],
          isPoll: true,
          pollId: cardData['poll_id']?.toString(),
        );
      }

      if (cardType == 'agent_response') {
        return _ChatMessage(
          text: text,
          type: _MsgType.agent,
          time: _formatStreamTime(message.createdAt),
          agentSummary: cardData!['summary']?.toString() ?? text,
          agentDescription: cardData['description']?.toString() ?? '',
          agentActionType: cardData['action_type']?.toString(),
        );
      }

      // Plain agent text message.
      return _ChatMessage(
        text: text,
        type: _MsgType.agent,
        time: _formatStreamTime(message.createdAt),
        agentSummary: text,
        agentDescription: '',
      );
    }

    if (userId == currentUserId) {
      return _ChatMessage(
        text: text,
        type: _MsgType.user,
        time: _formatStreamTime(message.createdAt),
      );
    }

    final senderName = message.user?.name ?? userId;
    return _ChatMessage(
      text: text,
      type: _MsgType.otherUser,
      time: _formatStreamTime(message.createdAt),
      senderName: senderName,
    );
  }

  String _formatStreamTime(DateTime? dt) {
    if (dt == null) return _now();
    // Convert UTC server time to local device time for consistent display.
    final local = dt.isUtc ? dt.toLocal() : dt;
    final h = local.hour == 0 ? 12 : (local.hour > 12 ? local.hour - 12 : local.hour);
    final minute = local.minute.toString().padLeft(2, '0');
    final ampm = local.hour >= 12 ? 'PM' : 'AM';
    return '$h:$minute $ampm';
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    _msgController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _showGroupMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.map_outlined, color: AppTheme.primary),
              title: const Text('Generate Itinerary'),
              subtitle: const Text('Build a day-by-day plan from your chat'),
              onTap: () {
                Navigator.pop(ctx);
                _generateItinerary();
              },
            ),
            ListTile(
              leading: const Icon(Icons.how_to_vote_outlined, color: AppTheme.warning),
              title: const Text('Create Poll'),
              onTap: () {
                Navigator.pop(ctx);
                _msgController.text = 'poll ';
                _msgController.selection =
                    TextSelection.collapsed(offset: _msgController.text.length);
              },
            ),
            ListTile(
              leading: const Icon(Icons.summarize_outlined, color: AppTheme.success),
              title: const Text('Summarize Chat'),
              onTap: () {
                Navigator.pop(ctx);
                _msgController.text = 'summarize';
                _sendMessage();
              },
            ),
            ListTile(
              leading: const Icon(Icons.emergency_outlined, color: AppTheme.sosRed),
              title: const Text('SOS Alert'),
              subtitle: const Text('Send emergency SOS with your location'),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.of(context).pushNamed('/sos', arguments: _group);
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _generateItinerary() async {
    if (_group == null) return;

    final placeholderId = 'itinerary-${DateTime.now().microsecondsSinceEpoch}';
    setState(() {
      _messages.add(_ChatMessage(
        id: placeholderId,
        text: '',
        type: _MsgType.agent,
        time: _now(),
        agentSummary: 'Building your itinerary...',
        agentDescription: 'Putting together a day-by-day plan based on your chat.',
      ));
    });

    final channelId = _channelCid;
    try {
      final result = await BackendService.instance.generateItinerary(
        channelId: channelId,
        days: 3,
      );

      setState(() {
        _removeMessageById(placeholderId);
        _messages.add(_ChatMessage(
          text: result['title']?.toString() ?? 'Trip Plan',
          type: _MsgType.itinerary,
          time: _now(),
          itineraryData: result,
        ));
      });
    } catch (e) {
      setState(() {
        _removeMessageById(placeholderId);
        _messages.add(_ChatMessage(
          text: '',
          type: _MsgType.agent,
          time: _now(),
          agentSummary: 'Could not build itinerary',
          agentDescription: _friendlyError(e),
        ));
      });
      if (_isNetworkError(e)) {
        await OfflineMessageQueue.instance.enqueue({
          'type': 'itinerary',
          'channel_id': channelId,
          'command': 'itinerary',
          'text': 'itinerary',
        });
      }
    }
  }

  Future<void> _sendMessage() async {
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
    } else if (lowerText == 'itinerary' || lowerText.startsWith('itinerary ') ||
        lowerText.startsWith('plan trip') || lowerText.startsWith('plan my trip')) {
      command = 'itinerary';
    }

    // Add user message to chat with a temporary ID for dedup.
    final tempId = 'temp-${DateTime.now().microsecondsSinceEpoch}';
    setState(() {
      _messages.add(_ChatMessage(
        id: tempId,
        text: text,
        type: _MsgType.user,
        time: _now(),
      ));
    });
    _msgController.clear();

    // Send to Stream channel. Record the returned message id BEFORE sending
    // so the 'message.new' listener cannot race and add a duplicate.
    if (_isStreamReady && _streamChannel != null) {
      try {
        final sent = await _streamChannel!.sendMessage(Message(text: text));
        final sentId = sent.message.id;
        // Replace the temp id with the real Stream id for future lookups.
        _seenMessageIds.add(sentId);
        // Update the local message's id so _removeMessageById etc. still work.
        final idx = _messages.indexWhere((m) => m.id == tempId);
        if (idx != -1) {
          final old = _messages[idx];
          _messages[idx] = _ChatMessage(
            id: sentId,
            text: old.text,
            type: old.type,
            time: old.time,
            senderName: old.senderName,
            agentSummary: old.agentSummary,
            agentDescription: old.agentDescription,
            agentActionType: old.agentActionType,
            agentToolResults: old.agentToolResults,
            isPoll: old.isPoll,
            pollId: old.pollId,
            itineraryData: old.itineraryData,
          );
        }
      } catch (e) {
        debugPrint('Stream send failed: $e');
      }
    } else if (!_isStreamReady) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chat is syncing... your message will be delivered shortly')),
      );
    }

    // Handle agent interaction
    final isAgentMention = lowerText.contains('@agent') || lowerText.contains('@planmate');
    if (isAgentMention) {
      // @agent messages go through Stream → webhook → agent → Stream response.
      // Do NOT call the direct command endpoint — it would create a duplicate.
      // Show a local processing indicator until the webhook response arrives.
      _lastAgentTime = now;
      _showAgentProcessing(text);
    } else if (command != null) {
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
    final channelId = _channelCid;

    // Show processing indicator with a stable id so we can remove exactly it.
    final placeholder = _ChatMessage(
      text: '',
      type: _MsgType.agent,
      time: _now(),
      agentSummary: 'Processing...',
      agentDescription: 'Let me look into that for the group.',
    );
    final placeholderId = placeholder.id;
    setState(() => _messages.add(placeholder));

    try {
      final result = await BackendService.instance.sendAgentCommand(
        channelId: channelId,
        command: command ?? 'chat',
        text: userMessage,
      );

      // Remove the processing placeholder.
      setState(() => _removeMessageById(placeholderId));

      // Add actual response
      final actionType = result['action_type'] ?? 'info_only';
      final isPoll = actionType == 'poll';
      final toolResults = result['tool_results'] as List<dynamic>? ?? [];
      final pollId = result['poll_id'] as String?;
      final agentText = result['summary']?.toString() ?? '';

      setState(() {
        _messages.add(_ChatMessage(
          text: agentText,
          type: _MsgType.agent,
          time: _now(),
          agentSummary: agentText,
          agentDescription: result['description']?.toString() ?? '',
          agentActionType: actionType,
          agentToolResults: toolResults,
          isPoll: isPoll,
          pollId: pollId,
        ));
      });

      // Note: we do NOT re-send the agent response to Stream here.
      // The webhook path already sends it as the planmate-agent bot user
      // via stream_service.send_agent_card / send_poll_card. Sending it
      // again from the frontend would duplicate every agent reply.
    } catch (e) {
      setState(() {
        _removeMessageById(placeholderId);
        _messages.add(_ChatMessage(
          text: '',
          type: _MsgType.agent,
          time: _now(),
          agentSummary: 'Sorry, I had trouble processing that.',
          agentDescription: _friendlyError(e),
        ));
      });
      // Queue for retry if it looks like a network error
      if (_isNetworkError(e)) {
        await OfflineMessageQueue.instance.enqueue({
          'channel_id': channelId,
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
    final h = now.hour == 0 ? 12 : (now.hour > 12 ? now.hour - 12 : now.hour);
    final m = now.minute.toString().padLeft(2, '0');
    final ampm = now.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $ampm';
  }

  /// Show a processing indicator for @agent mentions.
  /// The placeholder is removed when the webhook response arrives via Stream.
  void _showAgentProcessing(String userMessage) {
    final placeholder = _ChatMessage(
      text: '',
      type: _MsgType.agent,
      time: _now(),
      agentSummary: 'Processing...',
      agentDescription: 'Let me look into that for the group.',
    );
    _agentProcessingId = placeholder.id;
    setState(() => _messages.add(placeholder));

    // Auto-remove after 20s if webhook response never arrives (timeout safety).
    Future.delayed(const Duration(seconds: 20), () {
      if (_agentProcessingId != null && mounted) {
        setState(() {
          _removeMessageById(_agentProcessingId!);
          _messages.add(_ChatMessage(
            text: '',
            type: _MsgType.agent,
            time: _now(),
            agentSummary: 'Agent couldn\'t respond',
            agentDescription: 'The request timed out. Tap @PlanMate Agent to try again.',
          ));
          _agentProcessingId = null;
        });
      }
    });
  }

  bool _isNetworkError(Object e) {
    final s = e.toString();
    return s.contains('SocketException') ||
        s.contains('TimeoutException') ||
        s.contains('ClientException');
  }

  /// Trim an error to a short, safe message (substring on a short string throws).
  String _friendlyError(Object e) {
    if (_isNetworkError(e)) {
      return 'The server is waking up or offline. Your request will retry automatically.';
    }
    final s = e.toString();
    return s.length > 200 ? s.substring(0, 200) : s;
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
            onPressed: _showGroupMenu,
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
                    await BackendService.instance.castPollVote(
                      channelId: _channelCid,
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
        } else if (msg.type == _MsgType.itinerary && msg.itineraryData != null) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 4, left: 8, right: 8),
            child: _buildItineraryCard(msg.itineraryData!),
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

  Widget _buildItineraryCard(Map<String, dynamic> data) {
    final days = (data['days'] as List<dynamic>?) ?? [];
    final title = data['title']?.toString() ?? 'Trip Plan';

    return Container(
      decoration: AppTheme.cardDecoration.copyWith(
        border: Border.all(color: AppTheme.agentBubble),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: AppTheme.agentBubble,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppTheme.agentBubbleDark,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.map, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: AppTheme.titleMedium.copyWith(color: AppTheme.primaryDark)),
                      Text('${days.length}-day plan', style: AppTheme.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
          ),
          for (final d in days) _buildItineraryDay(d as Map<String, dynamic>),
        ],
      ),
    );
  }

  Widget _buildItineraryDay(Map<String, dynamic> day) {
    final activities = (day['activities'] as List<dynamic>?) ?? [];
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppTheme.borderLight)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppTheme.primary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'D${day['day']?.toString() ?? '?'}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  day['theme']?.toString() ?? 'Day',
                  style: AppTheme.labelLarge.copyWith(color: AppTheme.textPrimary),
                ),
              ),
            ],
          ),
          if (activities.isNotEmpty) const SizedBox(height: 10),
          for (final a in activities)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 56,
                    child: Text(
                      a['time']?.toString() ?? '',
                      style: AppTheme.bodySmall.copyWith(
                        color: AppTheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          a['activity']?.toString() ?? '',
                          style: AppTheme.bodyMedium,
                        ),
                        if (a['location'] != null && a['location'].toString().isNotEmpty)
                          Text(
                            a['location'].toString(),
                            style: AppTheme.bodySmall.copyWith(color: AppTheme.textSecondary),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
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

enum _MsgType { system, user, otherUser, agent, itinerary }

class _ChatMessage {
  final String id;
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
  final Map<String, dynamic>? itineraryData;

  _ChatMessage({
    String? id,
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
    this.itineraryData,
  }) : id = id ?? 'local-${_localSeq++}';

  static int _localSeq = 0;
}
