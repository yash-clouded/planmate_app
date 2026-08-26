import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class BookingConfirmationScreen extends StatelessWidget {
  const BookingConfirmationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, size: 22),
          onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          children: [
            const SizedBox(height: 20),
            _buildSuccessIcon(),
            const SizedBox(height: 20),
            const Text('Booking Confirmed!', style: AppTheme.headlineLarge),
            const SizedBox(height: 8),
            Text(
              'Your hotel reservation has been confirmed.\nA confirmation has been shared in your group chat.',
              textAlign: TextAlign.center,
              style: AppTheme.bodyMedium.copyWith(
                color: AppTheme.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            _buildSummaryCard(),
            const SizedBox(height: 24),
            _buildQrCode(),
            const SizedBox(height: 32),
            _buildActionButtons(context),
            SizedBox(height: MediaQuery.of(context).padding.bottom + 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccessIcon() {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: AppTheme.success.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: const Icon(
        Icons.check_circle,
        size: 56,
        color: AppTheme.success,
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecoration,
      child: Column(
        children: [
          // Hotel image placeholder
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: double.infinity,
              height: 120,
              color: AppTheme.agentBubble,
              child: const Center(
                child: Icon(Icons.hotel, size: 48, color: AppTheme.primary),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Snow Valley Resort',
            style: AppTheme.titleLarge,
          ),
          const SizedBox(height: 4),
          Text(
            'Manali, Himachal Pradesh',
            style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.background,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                _detailRow(Icons.calendar_today, 'Aug 30 – Sep 1, 2025', '2 nights'),
                const Divider(color: AppTheme.borderLight),
                _detailRow(Icons.person, '3 rooms', '6 guests'),
                const Divider(color: AppTheme.borderLight),
                _detailRow(Icons.confirmation_number, 'Booking ID', 'PM-28491'),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Total Paid  ', style: AppTheme.bodyMedium.copyWith(
                color: AppTheme.textSecondary,
              )),
              Text(
                '₹21,500',
                style: AppTheme.headlineMedium.copyWith(color: AppTheme.primary),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppTheme.textSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label, style: AppTheme.bodyMedium),
          ),
          Text(
            value,
            style: AppTheme.labelMedium.copyWith(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQrCode() {
    return Container(
      width: 160,
      height: 160,
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecoration,
      child: CustomPaint(
        painter: _QrPlaceholderPainter(),
        child: const Center(
          child: Text(
            'QR Code',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () {
              // TODO: share to group
            },
            style: AppTheme.outlinedButtonStyle.copyWith(
              padding: WidgetStateProperty.all(
                const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
            icon: const Icon(Icons.share, size: 18),
            label: const Text('Share to group'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () {
              // TODO: add to calendar
            },
            style: AppTheme.outlinedButtonStyle.copyWith(
              padding: WidgetStateProperty.all(
                const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
            icon: const Icon(Icons.calendar_today, size: 18),
            label: const Text('Add to calendar'),
          ),
        ),
      ],
    );
  }
}

class _QrPlaceholderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTheme.textPrimary.withOpacity(0.15)
      ..style = PaintingStyle.fill;

    final cellSize = size.width / 10;
    // Draw a simple QR-like pattern
    final pattern = [
      [0,0,0,1,0,1,0,0,0,0],
      [0,1,1,1,0,1,1,1,0,0],
      [0,1,0,1,0,1,0,1,0,0],
      [0,1,1,1,0,1,1,1,0,0],
      [0,0,0,0,0,0,0,0,0,0],
      [1,0,1,1,0,1,0,1,1,0],
      [0,0,0,0,0,1,0,0,0,0],
      [0,1,1,0,1,0,1,1,0,0],
      [0,0,1,0,0,1,0,1,0,0],
      [0,0,0,0,0,0,0,0,0,0],
    ];

    for (int r = 0; r < 10; r++) {
      for (int c = 0; c < 10; c++) {
        if (pattern[r][c] == 1) {
          canvas.drawRect(
            Rect.fromLTWH(c * cellSize, r * cellSize, cellSize - 1, cellSize - 1),
            paint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
