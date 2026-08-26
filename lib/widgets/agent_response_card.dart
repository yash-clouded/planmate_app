import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class AgentResponseCard extends StatelessWidget {
  final String title;
  final String summary;
  final String description;
  final List<AgentOption>? options;
  final List<AgentImageOption>? imageOptions;
  final String? confirmButtonText;
  final VoidCallback? onConfirm;
  final bool showPinned;
  final String timestamp;

  const AgentResponseCard({
    super.key,
    this.title = 'PlanMate Agent',
    required this.summary,
    this.description = '',
    this.options,
    this.imageOptions,
    this.confirmButtonText,
    this.onConfirm,
    this.showPinned = true,
    this.timestamp = 'Now',
  });

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
            _buildContent(),
            if (options != null && options!.isNotEmpty) _buildOptions(),
            if (imageOptions != null && imageOptions!.isNotEmpty)
              _buildImageOptions(),
            if (confirmButtonText != null) _buildConfirmButton(),
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
                Text(
                  timestamp,
                  style: AppTheme.bodySmall.copyWith(fontSize: 10),
                ),
              ],
            ),
          ),
          if (showPinned)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.push_pin, size: 10, color: AppTheme.primary),
                  SizedBox(width: 3),
                  Text('Pinned', style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primary,
                  )),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            summary,
            style: AppTheme.titleMedium.copyWith(color: AppTheme.primaryDark),
          ),
          if (description.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              description,
              style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOptions() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Column(
        children: options!.map((option) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: option.onTap,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: option.isSelected
                          ? AppTheme.primary
                          : AppTheme.border,
                      width: option.isSelected ? 2 : 1,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    color: option.isSelected
                        ? AppTheme.primary.withOpacity(0.05)
                        : Colors.transparent,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: (option.iconColor ?? AppTheme.primary)
                              .withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          option.icon ?? Icons.tune,
                          color: option.iconColor ?? AppTheme.primary,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              option.label,
                              style: AppTheme.labelLarge.copyWith(
                                color: AppTheme.primaryDark,
                              ),
                            ),
                            if (option.subtitle != null)
                              Text(
                                option.subtitle!,
                                style: AppTheme.bodySmall.copyWith(
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                          ],
                        ),
                      ),
                      Icon(
                        option.isSelected
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                        color: option.isSelected
                            ? AppTheme.primary
                            : AppTheme.textHint,
                        size: 22,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildImageOptions() {
    return SizedBox(
      height: 160,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
        itemCount: imageOptions!.length,
        itemBuilder: (context, index) {
          final opt = imageOptions![index];
          return GestureDetector(
            onTap: opt.onTap,
            child: Container(
              width: 140,
              margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: opt.isSelected
                      ? AppTheme.primary
                      : AppTheme.border,
                  width: opt.isSelected ? 2 : 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(11),
                      ),
                      child: Container(
                        width: double.infinity,
                        color: AppTheme.borderLight,
                        child: opt.imageUrl != null
                            ? Image.network(
                                opt.imageUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    const Icon(Icons.hotel, size: 40, color: AppTheme.textHint),
                              )
                            : const Icon(Icons.image, size: 40, color: AppTheme.textHint),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          opt.name,
                          style: AppTheme.labelMedium.copyWith(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          opt.price,
                          style: AppTheme.bodySmall.copyWith(
                            color: AppTheme.accent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildConfirmButton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: onConfirm,
          style: AppTheme.primaryButtonStyle,
          child: Text(confirmButtonText!),
        ),
      ),
    );
  }
}

class AgentOption {
  final String label;
  final String? subtitle;
  final IconData? icon;
  final Color? iconColor;
  final bool isSelected;
  final VoidCallback? onTap;

  const AgentOption({
    required this.label,
    this.subtitle,
    this.icon,
    this.iconColor,
    this.isSelected = false,
    this.onTap,
  });
}

class AgentImageOption {
  final String name;
  final String price;
  final String? imageUrl;
  final bool isSelected;
  final VoidCallback? onTap;

  const AgentImageOption({
    required this.name,
    required this.price,
    this.imageUrl,
    this.isSelected = false,
    this.onTap,
  });
}
