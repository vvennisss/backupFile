import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'theme.dart';
import 'screens/main_navigation.dart';
import 'screens/welcome_screen.dart';
import 'services/auth_service.dart';
import 'services/stamps_service.dart';
import 'services/saved_trip_plans_manager.dart';
import 'services/saved_places_manager.dart';
import 'services/companion_alert_service.dart';
import 'services/completed_trails_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Try initializing Firebase, but fallback gracefully if not configured on the console yet
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    print("Firebase initialization skipped/failed: $e. Running in local mock mode.");
  }
  
  // Load initial session and pre-warm stamps cache
  await AuthService.init();
  await StampsService.initCache();
  await SavedTripPlansManager.init();
  await SavedPlacesManager.init();
  await CompletedTrailsManager.init();
  CompanionAlertService.instance.init();
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kia Kia Penang',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: ValueListenableBuilder<Map<String, dynamic>?>(
        valueListenable: AuthService.currentUserNotifier,
        builder: (context, user, _) {
          if (user == null) {
            return const WelcomeScreen();
          }
          return const MainNavigation();
        },
      ),
    );
  }
}
