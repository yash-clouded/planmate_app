import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class PollCard extends StatefulWidget {
  final String question;
  final List<PollOption> options;
  final int totalVotes;
  final Duration? timeRemaining;
  final bool showResult;
  final String? resultText;
  final ValueChanged<int>? onVote;

  const PollCard({
    super.key,
    required this.question,
    required this.options,
    this.totalVotes = 0,
    this.timeRemaining,
    this.showResult = false,
    this.resultText,
    this.onVote,
  });

  @override
  State<PollCard> createState() => _PollCardState();
}

class _PollCardState extends State<PollCard> {
  int? _selectedOption;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.85,
        ),
        margin: const EdgeInsets.only(left: 8, right: 48, top: 4, bottom: 4),
        decoration: AppTheme.cardDecoration.copyWith(
          border: Border.all(color: AppTheme.agentBubble),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            _buildQuestion(),
            if (widget.showResult && widget.resultText != null)
              _buildResult()
            else
              ..._buildOptionRows(),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AppTheme.agentBubbleDark,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.smart_toy_rounded,
              size: 18,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PlanMate Agent',
                  style: AppTheme.labelLarge.copyWith(
                    color: AppTheme.primaryDark,
                  ),
                ),
                const Text(
                  'Now',
                  style: TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppTheme.warning.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.how_to_vote, size: 10, color: AppTheme.warning),
                SizedBox(width: 3),
                Text('Poll', style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.warning,
                )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestion() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: Text(
        widget.question,
        style: AppTheme.titleMedium.copyWith(color: AppTheme.primaryDark),
      ),
    );
  }

  Widget _buildResult() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.success.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.success.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle, color: AppTheme.success, size: 24),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                widget.resultText!,
                style: AppTheme.labelLarge.copyWith(color: AppTheme.success),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildOptionRows() {
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
        child: Column(
          children: List.generate(widget.options.length, (index) {
            final opt = widget.options[index];
            final isSelected = _selectedOption == index;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    setState(() => _selectedOption = index);
                    widget.onVote?.call(index);
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: isSelected
                            ? AppTheme.primary
                            : AppTheme.border,
                        width: isSelected ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      color: isSelected
                          ? AppTheme.primary.withOpacity(0.05)
                          : Colors.transparent,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isSelected
                              ? Icons.radio_button_checked
                              : Icons.radio_button_unchecked,
                          color: isSelected
                              ? AppTheme.primary
                              : AppTheme.textHint,
                          size: 22,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            opt.label,
                            style: AppTheme.bodyMedium.copyWith(
                              color: isSelected
                                  ? AppTheme.primary
                                  : AppTheme.textPrimary,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    ];
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppTheme.borderLight)),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.how_to_vote, size: 14, color: AppTheme.textHint),
          const SizedBox(width: 4),
          Text(
            '${widget.totalVotes} vote${widget.totalVotes != 1 ? 's' : ''} cast',
            style: AppTheme.bodySmall,
          ),
          const Spacer(),
          if (widget.timeRemaining != null) ...[
            Icon(Icons.timer_outlined, size: 14, color: AppTheme.textHint),
            const SizedBox(width: 4),
            Text(
              'Poll closes in ${_formatDuration(widget.timeRemaining!)}',
              style: AppTheme.bodySmall.copyWith(
                color: AppTheme.warning,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}';
    }
    return '00:${minutes.toString().padLeft(2, '0')}';
  }
}

class PollOption {
  final String label;
  const PollOption({required this.label});
}
