import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import '../services/stream_service.dart';

class BookingConfirmationScreen extends StatelessWidget {
  const BookingConfirmationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    final data = args is Map<String, dynamic> ? args : <String, dynamic>{};

    final hotelName = data['name'] as String? ?? 'Snow Valley Resort';
    final location = data['location'] as String? ?? 'Manali, Himachal Pradesh';
    final dates = data['dates'] as String? ?? 'Aug 30 – Sep 1, 2025';
    final nights = data['nights'] as String? ?? '2 nights';
    final rooms = data['rooms'] as String? ?? '3 rooms';
    final guests = data['guests'] as String? ?? '6 guests';
    final bookingId = data['booking_id'] as String? ?? 'PM-28491';
    final totalPrice = data['total_price'] as String? ?? '₹21,500';
    final channelId = data['channel_id'] as String?;

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
            _buildSummaryCard(
              hotelName: hotelName,
              location: location,
              dates: dates,
              nights: nights,
              rooms: rooms,
              guests: guests,
              bookingId: bookingId,
              totalPrice: totalPrice,
            ),
            const SizedBox(height: 32),
            _buildActionButtons(context, channelId: channelId, hotelName: hotelName, location: location, dates: dates),
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

  Widget _buildSummaryCard({
    required String hotelName,
    required String location,
    required String dates,
    required String nights,
    required String rooms,
    required String guests,
    required String bookingId,
    required String totalPrice,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecoration,
      child: Column(
        children: [
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
          Text(hotelName, style: AppTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            location,
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
                _detailRow(Icons.calendar_today, '$dates', nights),
                const Divider(color: AppTheme.borderLight),
                _detailRow(Icons.person, rooms, guests),
                const Divider(color: AppTheme.borderLight),
                _detailRow(Icons.confirmation_number, 'Booking ID', bookingId),
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
                totalPrice,
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

  Widget _buildActionButtons(BuildContext context, {
    String? channelId,
    required String hotelName,
    required String location,
    required String dates,
  }) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: channelId != null
                ? () async {
                    try {
                      await StreamChatService.instance.sendMessage(
                        channelId: channelId,
                        text: 'Booking confirmed at $hotelName, $location ($dates)',
                      );
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Booking shared to group chat'),
                            backgroundColor: AppTheme.success,
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Failed to share: $e')),
                        );
                      }
                    }
                  }
                : null,
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
            onPressed: () async {
              final now = DateTime.now();
              final end = now.add(const Duration(days: 2));
              final uri = Uri(
                scheme: 'https',
                host: 'calendar.google.com',
                path: '/calendar/render',
                queryParameters: {
                  'action': 'TEMPLATE',
                  'text': 'Trip: $hotelName',
                  'details': 'Booking at $hotelName, $location',
                  'dates': '${now.toUtc().toIso8601String().replaceAll('-', '').replaceAll(':', '').split('.').first}/${end.toUtc().toIso8601String().replaceAll('-', '').replaceAll(':', '').split('.').first}',
                },
              );
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
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
