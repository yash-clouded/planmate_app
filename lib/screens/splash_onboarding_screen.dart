import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class SplashOnboardingScreen extends StatefulWidget {
  const SplashOnboardingScreen({super.key});

  @override
  State<SplashOnboardingScreen> createState() => _SplashOnboardingScreenState();
}

class _SplashOnboardingScreenState extends State<SplashOnboardingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnim;
  late Animation<double> _slideAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _slideAnim = Tween<double>(begin: 30, end: 0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Opacity(
              opacity: _fadeAnim.value,
              child: Transform.translate(
                offset: Offset(0, _slideAnim.value),
                child: child,
              ),
            );
          },
          child: Column(
            children: [
              const Spacer(flex: 2),
              // Logo + Brand
              _buildLogo(),
              const SizedBox(height: 16),
              _buildTagline(),
              const Spacer(flex: 2),
              // Illustration placeholder
              _buildIllustration(),
              const Spacer(flex: 2),
              // Permission list
              _buildPermissions(),
              const Spacer(flex: 2),
              // Continue button
              _buildContinueButton(),
              SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Column(
      children: [
        Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppTheme.primary, AppTheme.primaryLight],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primary.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Icon(
            Icons.smart_toy_rounded,
            size: 48,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'PlanMate',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w700,
            color: AppTheme.primary,
            letterSpacing: -0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildTagline() {
    return Text(
      'Plan together. Decide faster. Travel smarter.',
      textAlign: TextAlign.center,
      style: AppTheme.bodyLarge.copyWith(
        color: AppTheme.textSecondary,
        fontSize: 15,
      ),
    );
  }

  Widget _buildIllustration() {
    return Container(
      width: 220,
      height: 160,
      decoration: BoxDecoration(
        color: AppTheme.agentBubble,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Three people icons
          Positioned(
            left: 40,
            top: 40,
            child: _personIcon(AppTheme.primary, 44),
          ),
          Positioned(
            top: 25,
            child: _personIcon(AppTheme.accent, 50),
          ),
          Positioned(
            right: 40,
            top: 40,
            child: _personIcon(AppTheme.primaryLight, 44),
          ),
          // Chat bubbles
          Positioned(
            bottom: 30,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.smart_toy_rounded, size: 16, color: AppTheme.primary),
                  SizedBox(width: 6),
                  Text('Let\'s plan a trip!', style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primary,
                  )),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _personIcon(Color color, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        shape: BoxShape.circle,
      ),
      child: Icon(Icons.person, size: size * 0.55, color: color),
    );
  }

  Widget _buildPermissions() {
    final permissions = [
      _PermissionItem(
        icon: Icons.contacts_outlined,
        title: 'Access contacts',
        description: 'Find and add friends to your groups',
      ),
      _PermissionItem(
        icon: Icons.location_on_outlined,
        title: 'Access location',
        description: 'Navigate trips and share your location',
      ),
      _PermissionItem(
        icon: Icons.notifications_outlined,
        title: 'Send notifications',
        description: 'Get alerts for group activity and trips',
      ),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: permissions.map((p) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(p.icon, color: AppTheme.primary, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.title,
                      style: AppTheme.labelLarge.copyWith(color: AppTheme.textPrimary),
                    ),
                    Text(
                      p.description,
                      style: AppTheme.bodySmall.copyWith(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        )).toList(),
      ),
    );
  }

  Widget _buildContinueButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton(
          onPressed: () {
            Navigator.of(context).pushReplacementNamed('/auth/phone');
          },
          style: AppTheme.primaryButtonStyle,
          child: const Text('Continue'),
        ),
      ),
    );
  }
}

class _PermissionItem {
  final IconData icon;
  final String title;
  final String description;

  _PermissionItem({
    required this.icon,
    required this.title,
    required this.description,
  });
}
