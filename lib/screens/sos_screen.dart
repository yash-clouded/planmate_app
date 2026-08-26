import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class SosScreen extends StatefulWidget {
  const SosScreen({super.key});

  @override
  State<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends State<SosScreen>
    with SingleTickerProviderStateMixin {
  bool _isHolding = false;
  double _holdProgress = 0;
  late AnimationController _pulseController;

  final _contacts = [
    _EmergencyContact(name: 'Mom', number: '+91 98765 43210'),
    _EmergencyContact(name: 'Dad', number: '+91 87654 32109'),
    _EmergencyContact(name: 'Sister', number: '+91 76543 21098'),
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
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
        title: const Text('SOS'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline, size: 22),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 40),
          // SOS button
          _buildSosButton(),
          const SizedBox(height: 16),
          Text(
            _isHolding ? 'Hold to send SOS...' : 'Tap and hold to send SOS',
            style: AppTheme.bodyMedium.copyWith(
              color: _isHolding ? AppTheme.sosRed : AppTheme.textSecondary,
              fontWeight: _isHolding ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
          const SizedBox(height: 40),
          // Emergency contacts
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text('Emergency Contacts', style: AppTheme.titleMedium),
                      const Spacer(),
                      GestureDetector(
                        onTap: () {},
                        child: Text(
                          'Edit',
                          style: AppTheme.bodyMedium.copyWith(
                            color: AppTheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ..._contacts.map((c) => _buildContactTile(c)),
                  const SizedBox(height: 8),
                  // Add contact
                  InkWell(
                    onTap: () {},
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: AppTheme.border,
                          style: BorderStyle.solid,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.add_circle_outline, color: AppTheme.primary, size: 22),
                          SizedBox(width: 12),
                          Text(
                            'Add emergency contact',
                            style: TextStyle(
                              color: AppTheme.primary,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Status banner
          _buildStatusBanner(),
        ],
      ),
    );
  }

  Widget _buildSosButton() {
    return Center(
      child: GestureDetector(
        onLongPressStart: (_) {
          setState(() => _isHolding = true);
          _startHoldProgress();
        },
        onLongPressEnd: (_) {
          setState(() {
            _isHolding = false;
            _holdProgress = 0;
          });
        },
        child: AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            return Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.sosRed.withOpacity(0.1 + _pulseController.value * 0.05),
                border: Border.all(
                  color: AppTheme.sosRed.withOpacity(0.3 + _pulseController.value * 0.3),
                  width: 3,
                ),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Progress ring
                  SizedBox(
                    width: 150,
                    height: 150,
                    child: CircularProgressIndicator(
                      value: _holdProgress,
                      strokeWidth: 4,
                      backgroundColor: Colors.transparent,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppTheme.sosRed.withOpacity(0.8),
                      ),
                    ),
                  ),
                  // Main button
                  Container(
                    width: 110,
                    height: 110,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.sosRed,
                      boxShadow: [
                        BoxShadow(
                          color: Color(0x40EF4444),
                          blurRadius: 20,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Text(
                        'SOS',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  void _startHoldProgress() async {
    for (int i = 0; i <= 30; i++) {
      await Future.delayed(const Duration(milliseconds: 100));
      if (!_isHolding) return;
      setState(() => _holdProgress = i / 30);
      if (i == 30) {
        _triggerSos();
      }
    }
  }

  void _triggerSos() {
    setState(() {
      _isHolding = false;
      _holdProgress = 0;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('SOS sent! Emergency contacts notified.'),
        backgroundColor: AppTheme.sosRed,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildContactTile(_EmergencyContact contact) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderLight),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.sosRed.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.person,
              color: AppTheme.sosRed,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  contact.name,
                  style: AppTheme.labelLarge.copyWith(color: AppTheme.textPrimary),
                ),
                Text(
                  contact.number,
                  style: AppTheme.bodySmall,
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.phone, color: AppTheme.success, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBanner() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        20,
        14,
        20,
        MediaQuery.of(context).padding.bottom + 14,
      ),
      decoration: BoxDecoration(
        color: AppTheme.success.withOpacity(0.08),
        border: const Border(
          top: BorderSide(color: AppTheme.success, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: AppTheme.success, size: 20),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ready to send SOS',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.success,
                    fontSize: 13,
                  ),
                ),
                Text(
                  'Your location will be shared with contacts',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmergencyContact {
  final String name;
  final String number;
  const _EmergencyContact({required this.name, required this.number});
}
