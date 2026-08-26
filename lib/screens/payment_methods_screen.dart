import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class PaymentMethodsScreen extends StatefulWidget {
  const PaymentMethodsScreen({super.key});

  @override
  State<PaymentMethodsScreen> createState() => _PaymentMethodsScreenState();
}

class _PaymentMethodsScreenState extends State<PaymentMethodsScreen> {
  final List<_PaymentMethod> _methods = [];

  void _addMethod() {
    final nameController = TextEditingController();
    String selectedType = 'UPI';
    final types = ['UPI', 'Credit Card', 'Debit Card', 'Net Banking'];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Add Payment Method'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: selectedType,
                decoration: AppTheme.inputDecoration(hintText: 'Type'),
                items: types.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                onChanged: (val) {
                  if (val != null) setDialogState(() => selectedType = val);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nameController,
                decoration: AppTheme.inputDecoration(
                  hintText: selectedType == 'UPI' ? 'UPI ID (e.g., name@upi)' : 'Card number last 4 digits',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final detail = nameController.text.trim();
                if (detail.isNotEmpty) {
                  setState(() {
                    _methods.add(_PaymentMethod(
                      type: selectedType,
                      detail: detail,
                      isDefault: _methods.isEmpty,
                    ));
                  });
                  Navigator.pop(ctx);
                }
              },
              style: AppTheme.primaryButtonStyle,
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  void _removeMethod(int index) {
    setState(() {
      _methods.removeAt(index);
      if (_methods.isNotEmpty && !_methods.any((m) => m.isDefault)) {
        _methods.first.isDefault = true;
      }
    });
  }

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
        title: const Text('Payment Methods'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Manage your linked payment methods for quick checkout.',
              style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: _methods.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      itemCount: _methods.length,
                      itemBuilder: (context, index) {
                        final m = _methods[index];
                        return _buildMethod(
                          name: m.type,
                          subtitle: m.detail,
                          icon: _iconForType(m.type),
                          isDefault: m.isDefault,
                          onDelete: () => _removeMethod(index),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: _addMethod,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: AppTheme.primary.withOpacity(0.3)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add, color: AppTheme.primary, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Add Payment Method',
                      style: TextStyle(
                        color: AppTheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.payment_outlined,
            size: 64,
            color: AppTheme.textHint.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          const Text(
            'No payment methods yet',
            style: AppTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Add a UPI, card, or net banking method\nfor quick checkout.',
            textAlign: TextAlign.center,
            style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'UPI':
        return Icons.account_balance_wallet;
      case 'Credit Card':
        return Icons.credit_card;
      case 'Debit Card':
        return Icons.credit_card;
      case 'Net Banking':
        return Icons.account_balance;
      default:
        return Icons.payment;
    }
  }

  Widget _buildMethod({
    required String name,
    required String subtitle,
    required IconData icon,
    bool isDefault = false,
    required VoidCallback onDelete,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: AppTheme.cardDecoration,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppTheme.primary, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(name, style: AppTheme.labelLarge),
                    if (isDefault) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.accent.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Default',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.accent,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                Text(subtitle, style: AppTheme.bodySmall),
              ],
            ),
          ),
          IconButton(
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline, size: 18, color: AppTheme.textHint),
          ),
        ],
      ),
    );
  }
}

class _PaymentMethod {
  final String type;
  final String detail;
  bool isDefault;
  _PaymentMethod({required this.type, required this.detail, this.isDefault = false});
}
