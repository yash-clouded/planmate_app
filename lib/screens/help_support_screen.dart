import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

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
        title: const Text('Help & Support'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Frequently Asked Questions', style: AppTheme.titleLarge),
            const SizedBox(height: 16),
            _buildFaqItem(
              question: 'How does the AI agent work?',
              answer: 'The PlanMate Agent reads your group conversation and helps you plan trips, dinners, and outings. Tag it with @agent to get suggestions and options.',
            ),
            _buildFaqItem(
              question: 'How do I create a group?',
              answer: 'Tap the + button on the home screen, enter a group name, add members, and tap Create Group.',
            ),
            _buildFaqItem(
              question: 'Is my data private?',
              answer: 'Yes. Your chat data is encrypted and never shared with third parties. The AI agent only reads messages in groups where it is a member.',
            ),
            _buildFaqItem(
              question: 'How do I add a payment method?',
              answer: 'Go to Settings > Payment Methods > Add Payment Method to link your UPI or card.',
            ),
            const SizedBox(height: 32),
            const Text('Contact Us', style: AppTheme.titleLarge),
            const SizedBox(height: 16),
            _buildContactOption(
              icon: Icons.email_outlined,
              title: 'Email Support',
              subtitle: 'support@planmate.app',
              onTap: () {},
            ),
            _buildContactOption(
              icon: Icons.chat_outlined,
              title: 'Live Chat',
              subtitle: 'Chat with our support team',
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Live chat coming soon')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFaqItem({required String question, required String answer}) {
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(bottom: 16),
      title: Text(question, style: AppTheme.titleMedium.copyWith(fontSize: 15)),
      iconColor: AppTheme.primary,
      children: [
        Text(answer, style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary)),
      ],
    );
  }

  Widget _buildContactOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding: const EdgeInsets.all(14),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppTheme.primary.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: AppTheme.primary, size: 22),
        ),
        title: Text(title, style: AppTheme.labelLarge),
        subtitle: Text(subtitle, style: AppTheme.bodySmall),
        trailing: const Icon(Icons.chevron_right, color: AppTheme.textHint),
        onTap: onTap,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppTheme.borderLight),
        ),
      ),
    );
  }
}
