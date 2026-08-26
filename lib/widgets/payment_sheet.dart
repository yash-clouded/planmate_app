import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class PaymentSheet extends StatefulWidget {
  final String title;
  final String itemName;
  final String itemDetails;
  final String? itemImageUrl;
  final List<CostLine> costLines;
  final double total;
  final List<PaymentMethod> paymentMethods;
  final VoidCallback? onPay;

  const PaymentSheet({
    super.key,
    this.title = 'Booking Summary',
    required this.itemName,
    required this.itemDetails,
    this.itemImageUrl,
    required this.costLines,
    required this.total,
    required this.paymentMethods,
    this.onPay,
  });

  static void show(
    BuildContext context, {
    String title = 'Booking Summary',
    required String itemName,
    required String itemDetails,
    String? itemImageUrl,
    required List<CostLine> costLines,
    required double total,
    required List<PaymentMethod> paymentMethods,
    VoidCallback? onPay,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PaymentSheet(
        title: title,
        itemName: itemName,
        itemDetails: itemDetails,
        itemImageUrl: itemImageUrl,
        costLines: costLines,
        total: total,
        paymentMethods: paymentMethods,
        onPay: onPay,
      ),
    );
  }

  @override
  State<PaymentSheet> createState() => _PaymentSheetState();
}

class _PaymentSheetState extends State<PaymentSheet> {
  int _selectedMethod = 0;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          _buildHandle(),
          _buildHeader(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildItemSummary(),
                  const SizedBox(height: 16),
                  _buildCostBreakdown(),
                  const SizedBox(height: 24),
                  _buildPaymentMethods(),
                ],
              ),
            ),
          ),
          _buildPayButton(),
        ],
      ),
    );
  }

  Widget _buildHandle() {
    return Center(
      child: Container(
        margin: const EdgeInsets.only(top: 12),
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: AppTheme.border,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Row(
        children: [
          Expanded(
            child: Text(
              widget.title,
              style: AppTheme.headlineMedium,
            ),
          ),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildItemSummary() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: 56,
              height: 56,
              color: AppTheme.borderLight,
              child: widget.itemImageUrl != null
                  ? Image.network(widget.itemImageUrl!, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          const Icon(Icons.image, color: AppTheme.textHint))
                  : const Icon(Icons.receipt_long, color: AppTheme.textHint),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.itemName,
                  style: AppTheme.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  widget.itemDetails,
                  style: AppTheme.bodySmall,
                  maxLines: 2,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCostBreakdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...widget.costLines.map((line) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(line.label, style: AppTheme.bodyMedium),
                  ),
                  Text(
                    '₹${line.amount.toStringAsFixed(0)}',
                    style: AppTheme.bodyMedium.copyWith(
                      color: line.isDiscount
                          ? AppTheme.success
                          : AppTheme.textPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            )),
        const Divider(color: AppTheme.borderLight),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              const Text('Total Payable', style: AppTheme.titleLarge),
              const Spacer(),
              Text(
                '₹${widget.total.toStringAsFixed(0)}',
                style: AppTheme.headlineMedium.copyWith(color: AppTheme.primary),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentMethods() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Choose payment method', style: AppTheme.titleMedium),
        const SizedBox(height: 12),
        ...List.generate(widget.paymentMethods.length, (index) {
          final method = widget.paymentMethods[index];
          final isSelected = _selectedMethod == index;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => setState(() => _selectedMethod = index),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: isSelected ? AppTheme.primary : AppTheme.border,
                      width: isSelected ? 2 : 1,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    color: isSelected
                        ? AppTheme.primary.withOpacity(0.05)
                        : Colors.transparent,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppTheme.background,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          method.icon,
                          color: AppTheme.primary,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          method.name,
                          style: AppTheme.labelLarge.copyWith(
                            color: isSelected
                                ? AppTheme.primary
                                : AppTheme.textPrimary,
                          ),
                        ),
                      ),
                      Icon(
                        isSelected
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                        color: isSelected ? AppTheme.primary : AppTheme.textHint,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildPayButton() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppTheme.borderLight)),
      ),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: widget.onPay,
          style: AppTheme.accentButtonStyle,
          child: Text(
            'Pay ₹${widget.total.toStringAsFixed(0)}',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }
}

class CostLine {
  final String label;
  final double amount;
  final bool isDiscount;

  const CostLine({
    required this.label,
    required this.amount,
    this.isDiscount = false,
  });
}

class PaymentMethod {
  final String name;
  final IconData icon;

  const PaymentMethod({required this.name, required this.icon});
}
