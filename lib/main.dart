import 'package:flutter/material.dart';
import 'package:membership_tracker/controllers/club_controller.dart';
import 'package:membership_tracker/screens/dashboard_screen.dart';
import 'package:membership_tracker/screens/login_screen.dart';
import 'package:membership_tracker/services/sheets_service.dart';
import 'package:membership_tracker/theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Services
  final sheetsService = SheetsService();
  await sheetsService.init(); // Try silent sign-in

  final clubController = ClubController(sheetsService);

  runApp(MainApp(controller: clubController));
}

class MainApp extends StatelessWidget {
  final ClubController controller;

  const MainApp({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, child) {
        return MaterialApp(
          title: 'Dojo Manager',
          theme: AppTheme.darkTheme,
          home: controller.isSignedIn
              ? DashboardScreen(controller: controller)
              : LoginScreen(controller: controller),
        );
      },
    );
  }
}
