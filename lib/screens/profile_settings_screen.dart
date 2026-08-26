import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class ProfileSettingsScreen extends StatelessWidget {
  const ProfileSettingsScreen({super.key});

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
        title: const Text('Profile & Settings'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildProfileHeader(context),
            const SizedBox(height: 24),
            _buildSection(context, 'Account', [
              _SettingItem(
                icon: Icons.person_outline,
                label: 'Account',
                onTap: () => Navigator.of(context).pushNamed('/settings/account'),
              ),
              _SettingItem(
                icon: Icons.emergency_outlined,
                label: 'Emergency Contacts',
                onTap: () => Navigator.of(context).pushNamed('/settings/emergency'),
              ),
              _SettingItem(
                icon: Icons.payment_outlined,
                label: 'Payment Methods',
                onTap: () => Navigator.of(context).pushNamed('/settings/payments'),
              ),
              _SettingItem(
                icon: Icons.notifications_outlined,
                label: 'Notifications',
                onTap: () => Navigator.of(context).pushNamed('/settings/notifications'),
              ),
              _SettingItem(
                icon: Icons.privacy_tip_outlined,
                label: 'Privacy & Data',
                onTap: () => Navigator.of(context).pushNamed('/settings/privacy'),
              ),
              _SettingItem(
                icon: Icons.help_outline,
                label: 'Help & Support',
                onTap: () => Navigator.of(context).pushNamed('/settings/help'),
              ),
              _SettingItem(
                icon: Icons.info_outline,
                label: 'About',
                onTap: () => Navigator.of(context).pushNamed('/settings/about'),
                showDivider: false,
              ),
            ]),
            const SizedBox(height: 24),
            _buildLogoutButton(context),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.cardDecoration,
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.person, color: AppTheme.primary, size: 28),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('You', style: AppTheme.titleLarge),
                SizedBox(height: 2),
                Text(
                  'Tap to edit profile',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pushNamed('/settings/account'),
            child: const Text('Edit Profile'),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(BuildContext context, String title, List<_SettingItem> items) {
    return Container(
      decoration: AppTheme.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
            child: Text(
              title,
              style: AppTheme.labelMedium.copyWith(
                color: AppTheme.textSecondary,
                letterSpacing: 0.3,
              ),
            ),
          ),
          ...items.map((item) => _buildSettingTile(item)),
        ],
      ),
    );
  }

  Widget _buildSettingTile(_SettingItem item) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: item.onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
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
                child: Icon(item.icon, color: AppTheme.primary, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(item.label, style: AppTheme.bodyLarge),
              ),
              const Icon(
                Icons.chevron_right,
                size: 20,
                color: AppTheme.textHint,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogoutButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: () {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text('Log Out?'),
              content: const Text('Are you sure you want to log out?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx); // close dialog
                    // Navigate to login and clear the entire stack
                    Navigator.of(context).pushNamedAndRemoveUntil(
                      '/',
                      (route) => false,
                    );
                  },
                  child: const Text(
                    'Log Out',
                    style: TextStyle(color: AppTheme.sosRed),
                  ),
                ),
              ],
            ),
          );
        },
        style: OutlinedButton.styleFrom(
          foregroundColor: AppTheme.sosRed,
          side: const BorderSide(color: AppTheme.sosRed),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: const Text('Log Out'),
      ),
    );
  }
}

class _SettingItem {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool showDivider;

  const _SettingItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.showDivider = true,
  });
}
