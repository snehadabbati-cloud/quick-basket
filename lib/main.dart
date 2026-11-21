import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'core/constants/app_strings.dart';
import 'features/home/screens/home_screen.dart';
import 'features/admin/screens/admin_login_screen.dart';
import 'features/rider/screens/rider_login_screen.dart';
import 'services/supabase_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseService().initialize();
  runApp(const QuickBasketApp());
}

/// Quick Basket Main Application Root conforming to PRD specifications
class QuickBasketApp extends StatelessWidget {
  /// Set to false in widget tests to avoid runtime Google Fonts downloads.
  final bool useGoogleFonts;

  const QuickBasketApp({super.key, this.useGoogleFonts = true});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppStrings.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(googleFonts: useGoogleFonts),
      initialRoute: '/',
      routes: {
        '/': (context) => const HomeScreen(),
        '/admin': (context) => const AdminLoginScreen(),
        '/store': (context) => const AdminLoginScreen(),
        '/rider': (context) => const RiderLoginScreen(),
      },
    );
  }
}
