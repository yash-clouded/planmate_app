import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import '../services/backend_service.dart';
import 'chat_list_screen.dart';

class SosScreen extends StatefulWidget {
  const SosScreen({super.key});

  @override
  State<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends State<SosScreen>
    with SingleTickerProviderStateMixin {
  bool _isHolding = false;
  double _holdProgress = 0;
  bool _isSending = false;
  late AnimationController _pulseController;
  GroupData? _group;

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
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is GroupData) {
      _group = args;
    }
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
      ),
      body: Column(
        children: [
          const SizedBox(height: 40),
          _buildSosButton(),
          const SizedBox(height: 16),
          Text(
            _isSending
                ? 'Sending SOS...'
                : _isHolding
                    ? 'Hold to send SOS...'
                    : 'Tap and hold to send SOS',
            style: AppTheme.bodyMedium.copyWith(
              color: _isSending
                  ? AppTheme.warning
                  : _isHolding
                      ? AppTheme.sosRed
                      : AppTheme.textSecondary,
              fontWeight: _isHolding || _isSending ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
          const SizedBox(height: 40),
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
                        onTap: () => Navigator.of(context).pushNamed('/settings/emergency'),
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
                  InkWell(
                    onTap: () => Navigator.of(context).pushNamed('/settings/emergency'),
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
          _buildStatusBanner(),
        ],
      ),
    );
  }

  Widget _buildSosButton() {
    return Center(
      child: GestureDetector(
        onLongPressStart: _isSending ? null : (_) {
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
                    child: Center(
                      child: _isSending
                          ? const SizedBox(
                              width: 28,
                              height: 28,
                              child: CircularProgressIndicator(
                                strokeWidth: 3,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text(
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

  Future<void> _triggerSos() async {
    setState(() {
      _isHolding = false;
      _holdProgress = 0;
      _isSending = true;
    });

    try {
      // Check and request location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showError('Location permission denied. Cannot send SOS without location.');
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        _showError('Location permission permanently denied. Please enable in settings.');
        return;
      }

      // Get current position
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      final user = FirebaseAuth.instance.currentUser;
      final userName = user?.displayName ?? user?.phoneNumber ?? 'Unknown User';
      final channelId = _group?.channelId;

      if (channelId == null) {
        _showError('No group selected. Open a group chat first to use SOS.');
        return;
      }

      await BackendService.instance.sendSosAlert(
        channelId: channelId,
        userId: user?.uid ?? 'unknown',
        userName: userName,
        latitude: position.latitude,
        longitude: position.longitude,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('SOS sent! Emergency contacts notified with your location.'),
            backgroundColor: AppTheme.sosRed,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      _showError('Failed to send SOS: $e');
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
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
            onPressed: () async {
              final uri = Uri.parse('tel:${contact.number.replaceAll(' ', '')}');
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri);
              }
            },
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
        color: _group != null
            ? AppTheme.success.withOpacity(0.08)
            : AppTheme.warning.withOpacity(0.08),
        border: Border(
          top: BorderSide(
            color: _group != null ? AppTheme.success : AppTheme.warning,
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            _group != null ? Icons.check_circle : Icons.warning_amber,
            color: _group != null ? AppTheme.success : AppTheme.warning,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _group != null ? 'Ready to send SOS' : 'No group selected',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: _group != null ? AppTheme.success : AppTheme.warning,
                    fontSize: 13,
                  ),
                ),
                Text(
                  _group != null
                      ? 'Your location will be shared with ${_group!.name}'
                      : 'Open a group chat to use SOS',
                  style: const TextStyle(
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
