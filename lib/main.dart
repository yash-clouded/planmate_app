import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart';
import 'firebase_options.dart';
import 'theme/app_theme.dart';
import 'services/auth_service.dart';
import 'services/stream_service.dart';
import 'services/permission_service.dart';

// Screens
import 'screens/splash_onboarding_screen.dart';
import 'screens/auth_phone_screen.dart';
import 'screens/auth_profile_screen.dart';
import 'screens/chat_list_screen.dart';
import 'screens/create_group_screen.dart';
import 'screens/group_chat_screen.dart';
import 'screens/booking_confirmation_screen.dart';
import 'screens/trip_mode_screen.dart';
import 'screens/sos_screen.dart';
import 'screens/profile_settings_screen.dart';
import 'screens/notification_preferences_screen.dart';
import 'screens/privacy_data_screen.dart';
import 'screens/emergency_contacts_screen.dart';
import 'screens/payment_methods_screen.dart';
import 'screens/account_screen.dart';
import 'screens/help_support_screen.dart';
import 'screens/about_screen.dart';

/// Notifies screens when they become visible again after a pop (e.g. back from group chat).
final RouteObserver<ModalRoute<void>> appRouteObserver = RouteObserver<ModalRoute<void>>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Initialize Stream Chat client with offline persistence
  await StreamChatService.instance.init();

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));

  runApp(const PlanMateApp());
}

class PlanMateApp extends StatelessWidget {
  const PlanMateApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => PermissionService()),
      ],
      child: MaterialApp(
        title: 'PlanMate',
        debugShowCheckedModeBanner: false,
        navigatorObservers: [appRouteObserver],
        theme: AppTheme.lightTheme,
        builder: (context, child) => StreamChat(
          client: StreamChatService.instance.client,
          child: child!,
        ),
        home: const _AuthGate(),
        routes: {
          '/auth/phone': (_) => const AuthPhoneScreen(),
          '/auth/profile': (_) => const AuthProfileScreen(),
          '/home': (_) => const ChatListScreen(),
          '/create-group': (_) => const CreateGroupScreen(),
          '/group-chat': (_) => const GroupChatScreen(),
          '/booking-confirmation': (_) => const BookingConfirmationScreen(),
          '/trip-mode': (_) => const TripModeScreen(),
          '/sos': (_) => const SosScreen(),
          '/settings': (_) => const ProfileSettingsScreen(),
          '/settings/notifications': (_) => const NotificationPreferencesScreen(),
          '/settings/privacy': (_) => const PrivacyDataScreen(),
          '/settings/emergency': (_) => const EmergencyContactsScreen(),
          '/settings/payments': (_) => const PaymentMethodsScreen(),
          '/settings/account': (_) => const AccountScreen(),
          '/settings/help': (_) => const HelpSupportScreen(),
          '/settings/about': (_) => const AboutScreen(),
        },
      ),
    );
  }
}

/// Checks Firebase Auth state on launch. If already signed in, goes straight
/// to home. Otherwise shows onboarding. Firebase Auth persists the session
/// automatically across app restarts.
class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<fb.User?>(
      stream: fb.FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Still loading auth state — show a minimal loading screen.
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: AppTheme.background,
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // User is signed in — skip straight to home.
        if (snapshot.hasData) {
          // Use a post-frame callback to navigate so we don't build mid-frame.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.of(context).pushReplacementNamed('/home');
          });
          return const Scaffold(
            backgroundColor: AppTheme.background,
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // Not signed in — show onboarding.
        return const SplashOnboardingScreen();
      },
    );
  }
}
