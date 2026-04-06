import 'package:flutter/material.dart';
import 'package:membership_tracker/controllers/club_controller.dart';
import 'package:membership_tracker/screens/lock_screen.dart';
import 'package:membership_tracker/theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final clubController = ClubController();
  await clubController.init(); 

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
          home: LockScreen(controller: controller),
        );
      },
    );
  }
}
