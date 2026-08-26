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
import 'screens/auth_otp_screen.dart';
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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Initialize Stream Chat client
  StreamChatService.instance.init();

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
        title: 'iternity',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        builder: (context, child) => StreamChat(
          client: StreamChatService.instance.client,
          child: child!,
        ),
        initialRoute: '/',
        routes: {
          '/': (_) => const SplashOnboardingScreen(),
          '/auth/phone': (_) => const AuthPhoneScreen(),
          '/auth/otp': (_) => const AuthOtpScreen(),
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
