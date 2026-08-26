import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class PrivacyDataScreen extends StatefulWidget {
  const PrivacyDataScreen({super.key});

  @override
  State<PrivacyDataScreen> createState() => _PrivacyDataScreenState();
}

class _PrivacyDataScreenState extends State<PrivacyDataScreen> {
  String _whoCanAdd = 'Everyone';
  bool _showLastSeen = true;

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
        title: const Text('Privacy & Data'),
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
                  _buildOptionRow(
                    icon: Icons.group_add_outlined,
                    label: 'Who can add me to groups',
                    value: _whoCanAdd,
                    onTap: () => _showWhoCanAddPicker(),
                  ),
                  _buildToggleRow(
                    icon: Icons.visibility_outlined,
                    label: 'Last seen & online',
                    subtitle: 'Show when you were last active',
                    value: _showLastSeen,
                    onChanged: (val) => setState(() => _showLastSeen = val),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              decoration: AppTheme.cardDecoration,
              child: Column(
                children: [
                  _buildActionRow(
                    icon: Icons.storage_outlined,
                    label: 'Data usage & storage',
                    subtitle: 'Manage stored data and cache',
                    onTap: () {},
                  ),
                  _buildActionRow(
                    icon: Icons.delete_outline,
                    label: 'Delete my account',
                    subtitle: 'Permanently delete your data',
                    onTap: () => _showDeleteConfirmation(),
                    isDestructive: true,
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

  Widget _buildOptionRow({
    required IconData icon,
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
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
                  Text(
                    value,
                    style: AppTheme.bodySmall.copyWith(color: AppTheme.accent),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 20, color: AppTheme.textHint),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleRow({
    required IconData icon,
    required String label,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
                Text(subtitle, style: AppTheme.bodySmall),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged, activeColor: AppTheme.accent),
        ],
      ),
    );
  }

  Widget _buildActionRow({
    required IconData icon,
    required String label,
    required String subtitle,
    required VoidCallback onTap,
    bool isDestructive = false,
    bool showDivider = true,
  }) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: (isDestructive ? AppTheme.sosRed : AppTheme.primary)
                        .withOpacity(0.06),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    color: isDestructive ? AppTheme.sosRed : AppTheme.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: AppTheme.bodyLarge.copyWith(
                          color: isDestructive ? AppTheme.sosRed : AppTheme.textPrimary,
                        ),
                      ),
                      Text(subtitle, style: AppTheme.bodySmall),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, size: 20, color: AppTheme.textHint),
              ],
            ),
          ),
        ),
        if (showDivider)
          const Divider(height: 1, indent: 66, color: AppTheme.borderLight),
      ],
    );
  }

  void _showWhoCanAddPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppTheme.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Text('Who can add me to groups', style: AppTheme.titleLarge),
            const SizedBox(height: 16),
            ...['Everyone', 'My contacts', 'Nobody'].map((option) {
              final isSelected = _whoCanAdd == option;
              return ListTile(
                title: Text(option, style: AppTheme.bodyLarge),
                trailing: Icon(
                  isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                  color: isSelected ? AppTheme.primary : AppTheme.textHint,
                ),
                onTap: () {
                  setState(() => _whoCanAdd = option);
                  Navigator.pop(context);
                },
              );
            }),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Account?'),
        content: const Text(
          'This will permanently delete your account and all associated data. This action cannot be undone.',
          style: AppTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Delete',
              style: TextStyle(color: AppTheme.sosRed),
            ),
          ),
        ],
      ),
    );
  }
}
