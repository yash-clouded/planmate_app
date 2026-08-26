import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

enum BubbleType { user, otherUser, agent }

class ChatBubble extends StatelessWidget {
  final String text;
  final String senderName;
  final String time;
  final BubbleType type;
  final bool showSenderName;
  final Widget? child;

  const ChatBubble({
    super.key,
    required this.text,
    this.senderName = '',
    required this.time,
    required this.type,
    this.showSenderName = false,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    final isUser = type == BubbleType.user;
    final isAgent = type == BubbleType.agent;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        margin: EdgeInsets.only(
          left: isUser ? 48 : 8,
          right: isUser ? 8 : 48,
          top: 4,
          bottom: 4,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isUser
              ? AppTheme.userBubble
              : isAgent
                  ? AppTheme.agentBubble
                  : AppTheme.otherUserBubble,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showSenderName && !isUser)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  senderName,
                  style: AppTheme.labelMedium.copyWith(
                    color: isAgent ? AppTheme.primary : AppTheme.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            if (isAgent)
              Row(
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: AppTheme.agentBubbleDark,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(
                      Icons.smart_toy_rounded,
                      size: 14,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      text,
                      style: AppTheme.bodyMedium.copyWith(
                        color: AppTheme.primaryDark,
                      ),
                    ),
                  ),
                ],
              )
            else
              Text(
                text,
                style: AppTheme.bodyMedium.copyWith(
                  color: isUser ? AppTheme.userBubbleText : AppTheme.textPrimary,
                ),
              ),
            if (child != null) child!,
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isAgent)
                  const Icon(Icons.push_pin, size: 10, color: AppTheme.primary)
                else
                  const SizedBox.shrink(),
                if (isAgent) const SizedBox(width: 4),
                Text(
                  time,
                  style: AppTheme.bodySmall.copyWith(
                    fontSize: 10,
                    color: isUser
                        ? Colors.white70
                        : isAgent
                            ? AppTheme.primary.withOpacity(0.6)
                            : AppTheme.textHint,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
