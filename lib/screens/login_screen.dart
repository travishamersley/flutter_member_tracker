import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:membership_tracker/controllers/club_controller.dart';
import 'package:google_sign_in_web/web_only.dart'
    if (dart.library.io) 'package:membership_tracker/utils/web_stub.dart'
    as web;

class LoginScreen extends StatelessWidget {
  final ClubController controller;

  const LoginScreen({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.sports_martial_arts,
              size: 80,
              color: Color(0xFFD4AF37),
            ),
            const SizedBox(height: 24),
            Text(
              "DOJO MANAGER",
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                letterSpacing: 2.0,
              ),
            ),
            const SizedBox(height: 48),
            if (kIsWeb)
              // Render Web Button
              web.renderButton(
                configuration: web.GSIButtonConfiguration(
                  theme: web.GSIButtonTheme.filledBlack,
                ),
              )
            else
              ElevatedButton.icon(
                onPressed: controller.signIn,
                icon: const Icon(Icons.login),
                label: const Text("Sign In with Google"),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
