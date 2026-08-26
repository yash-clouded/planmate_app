import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class NotificationPreferencesScreen extends StatefulWidget {
  const NotificationPreferencesScreen({super.key});

  @override
  State<NotificationPreferencesScreen> createState() =>
      _NotificationPreferencesScreenState();
}

class _NotificationPreferencesScreenState
    extends State<NotificationPreferencesScreen> {
  bool _groupMessages = true;
  bool _agentSuggestions = true;
  bool _pollsDecisions = true;
  bool _paymentsBookings = true;
  bool _tripUpdates = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Notifications'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              decoration: AppTheme.cardDecoration,
              child: Column(
                children: [
                  _buildToggle(
                    icon: Icons.chat_bubble_outline,
                    label: 'Group messages',
                    subtitle: 'New messages in your groups',
                    value: _groupMessages,
                    onChanged: (val) => setState(() => _groupMessages = val),
                  ),
                  _buildToggle(
                    icon: Icons.smart_toy_outlined,
                    label: 'Agent suggestions',
                    subtitle: 'When the AI agent has a plan or summary',
                    value: _agentSuggestions,
                    onChanged: (val) => setState(() => _agentSuggestions = val),
                  ),
                  _buildToggle(
                    icon: Icons.how_to_vote_outlined,
                    label: 'Polls & decisions',
                    subtitle: 'New polls and group decision results',
                    value: _pollsDecisions,
                    onChanged: (val) => setState(() => _pollsDecisions = val),
                    showDivider: false,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              decoration: AppTheme.cardDecoration,
              child: Column(
                children: [
                  _buildToggle(
                    icon: Icons.payment_outlined,
                    label: 'Payments & bookings',
                    subtitle: 'Booking confirmations and payment updates',
                    value: _paymentsBookings,
                    onChanged: (val) => setState(() => _paymentsBookings = val),
                  ),
                  _buildToggle(
                    icon: Icons.terrain_outlined,
                    label: 'Trip updates',
                    subtitle: 'Route changes, disruptions, and trip alerts',
                    value: _tripUpdates,
                    onChanged: (val) => setState(() => _tripUpdates = val),
                    showDivider: false,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToggle({
    required IconData icon,
    required String label,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    bool showDivider = true,
  }) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: AppTheme.primary, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: AppTheme.bodyLarge),
                    const SizedBox(height: 2),
                    Text(subtitle, style: AppTheme.bodySmall),
                  ],
                ),
              ),
              Switch(
                value: value,
                onChanged: onChanged,
                activeColor: AppTheme.accent,
              ),
            ],
          ),
        ),
        if (showDivider)
          const Divider(height: 1, indent: 66, color: AppTheme.borderLight),
      ],
    );
  }
}
